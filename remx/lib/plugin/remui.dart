import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'registers.dart';
import 'remui_page.dart';

typedef PageHandler = void Function(void Function(String action), String url);
typedef WidgetBuilderMap = Map<String, Widget Function(Map<String, dynamic>)>;

class RemUI {
  static String _baseUrl = "";
  static Map<String, dynamic> _config = {};
  static Map<String, PageHandler> _pageHandlers = {};
  static WidgetBuilderMap _customRegisters = {};
  static WidgetBuilderMap _customPages = {};
  static final Map<String, dynamic> variables = {};
  static List<dynamic> callbacks = [];
  static List<dynamic> pendingCallbacks = [];
  static final ValueNotifier<int> variableTick = ValueNotifier<int>(0);
  static final ValueNotifier<int> progressTick = ValueNotifier<int>(0);
  static final ValueNotifier<int> reloadRetainTick = ValueNotifier<int>(0);
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static late BuildContext currentContext;
  static Map<String, dynamic> clientContext = {};
  static int _openDialogCount = 0;
  static int _inFlightOps = 0;

  static String get baseUrl => _baseUrl;
  static void init(
    String baseUrl,
    Map<String, dynamic> config, {
    WidgetBuilderMap? registers,
    WidgetBuilderMap? pages,
    Map<String, PageHandler>? pageFunction,
  }) {
    _baseUrl = baseUrl;
    _config = config;
    if (registers != null) {
      _customRegisters = registers;
    }
    if (pages != null) {
      _customPages = pages;
    }
    if (pageFunction != null) {
      _pageHandlers = pageFunction;
    }
  }

  static void updateContext(BuildContext context) {
    currentContext = context;
    final media = MediaQuery.of(context);
    clientContext = {
      "mediaQuery": {
        "size": {"width": media.size.width, "height": media.size.height},
      },
      "deviceTheme": Theme.of(context).brightness == Brightness.dark
          ? "dark"
          : "light",
    };
  }

  static void setVar(String name, dynamic value) {
    if (variables.containsKey(name) && variables[name] == value) {
      return;
    }
    variables[name] = value;
    variableTick.value = variableTick.value + 1;
  }

  static void beginProgress() {
    _inFlightOps = _inFlightOps + 1;
    _setProgressTickSafely();
  }

  static void endProgress() {
    if (_inFlightOps <= 0) {
      _inFlightOps = 0;
      _setProgressTickSafely();
      return;
    }
    _inFlightOps = _inFlightOps - 1;
    _setProgressTickSafely();
  }

  static void _setProgressTickSafely() {
    final nextValue = _inFlightOps;
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      progressTick.value = nextValue;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      progressTick.value = nextValue;
    });
  }

  static dynamic getVar(String name) {
    return variables[name];
  }

  static void setVars(Map<String, dynamic> values) {
    // Preserve local prefs.* vars not present in the server response — the route may not have
    // re-hydrated all SharedPreferences, but the on-disk values are still authoritative.
    final preserved = <String, dynamic>{};
    for (final entry in variables.entries) {
      if (entry.key.startsWith('prefs.') && !values.containsKey(entry.key)) {
        preserved[entry.key] = entry.value;
      }
    }

    final next = <String, dynamic>{...preserved, ...values};

    final noChange =
        variables.length == next.length &&
        next.entries.every((entry) => variables[entry.key] == entry.value);
    if (noChange) {
      return;
    }

    variables
      ..clear()
      ..addAll(next);
    variableTick.value = variableTick.value + 1;
  }

  static void mergeVars(Map<String, dynamic> values) {
    final changed = values.entries.any(
      (entry) => variables[entry.key] != entry.value,
    );
    if (!changed) {
      return;
    }

    variables.addAll(values);
    variableTick.value = variableTick.value + 1;
  }

  static void setCallbacks(dynamic value) {
    if (value is List) {
      callbacks = List<dynamic>.from(value);
      pendingCallbacks = List<dynamic>.from(value);
      return;
    }

    callbacks = [];
    pendingCallbacks = [];
  }

  static List<dynamic> consumePendingCallbacks() {
    final queued = List<dynamic>.from(pendingCallbacks);
    pendingCallbacks = [];
    return queued;
  }

  static Future<void> runPendingCallbacks() async {
    await runCallbacks(consumePendingCallbacks());
  }

  static Future<void> runCallbacks(List<dynamic> callbacks) async {
    for (final callback in callbacks) {
      if (callback is Map) {
        await _runCallback(
          callback.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    }
  }

  static Future<void> _runCallback(Map<String, dynamic> callback) async {
    if (callback.containsKey("timeout")) {
      final delayMs = _parseTimeoutMs(callback["timeout"]);
      final delayedPayload = callback.containsKey("data")
          ? callback["data"]
          : callback.entries
                .where((entry) => entry.key != "timeout")
                .fold<Map<String, dynamic>>({}, (next, entry) {
                  next[entry.key] = entry.value;
                  return next;
                });

      if (delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }

      await _runTimeoutPayload(delayedPayload);
      return;
    }

    if (callback.containsKey("setSharedPref")) {
      await _setSharedPref(callback["setSharedPref"]);
    }

    if (callback.containsKey("setPrefs")) {
      await _setPrefs(callback["setPrefs"]);
    }

    if (callback.containsKey("remSharedPref") ||
        callback.containsKey("removeSharedPref")) {
      await _remSharedPref(
        callback["remSharedPref"] ?? callback["removeSharedPref"],
      );
    }

    if (callback.containsKey("setVar")) {
      final value = callback["setVar"];
      if (value is Map) {
        final normalized = value.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final name =
            normalized["var"]?.toString() ?? normalized["name"]?.toString();
        if (name != null && name.isNotEmpty) {
          setVar(name, normalized["value"]);
        }
      } else if (value is String) {
        final separator = value.indexOf("=");
        if (separator > 0) {
          final name = value.substring(0, separator).trim();
          final rawValue = value.substring(separator + 1);
          if (name.isNotEmpty) {
            setVar(name, rawValue);
          }
        }
      }
    }

    if (callback.containsKey("snackbar")) {
      _showSnackBar(callback["snackbar"]?.toString() ?? "");
    }

    if (callback.containsKey("pushReplace")) {
      await _handleNavigationCallback(callback["pushReplace"], replace: true);
    } else if (callback.containsKey("push")) {
      await _handleNavigationCallback(callback["push"]);
    }

    if (callback.containsKey("pushPageReplace")) {
      await _handleNavigationCallback(
        callback["pushPageReplace"],
        replace: true,
      );
    } else if (callback.containsKey("pushPage")) {
      await _handleNavigationCallback(callback["pushPage"]);
    }

    if (callback.containsKey("navReplace")) {
      await _handleNavigationCallback(callback["navReplace"], replace: true);
    } else if (callback.containsKey("nav")) {
      await _handleNavigationCallback(callback["nav"]);
    }

    if (callback.containsKey("closeDialog") &&
        callback["closeDialog"] != false) {
      closeDialog();
    }

    if ((callback.containsKey("reloadRetain") ||
            callback.containsKey("loadRetain")) &&
        (callback["reloadRetain"] ?? callback["loadRetain"]) != false) {
      reloadRetain();
    }
  }

  static int _parseTimeoutMs(dynamic value) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }
    if (value is num) {
      final parsed = value.toInt();
      return parsed < 0 ? 0 : parsed;
    }

    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  static Future<void> _runTimeoutPayload(dynamic payload) async {
    if (payload is List) {
      await runCallbacks(payload);
      return;
    }

    if (payload is Map) {
      await _runCallback(
        payload.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
  }

  static Future<void> _setSharedPref(dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is Map) {
      final normalized = value.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final name =
          normalized["name"]?.toString() ?? normalized["key"]?.toString();
      if (name == null || name.isEmpty) return;
      final rawValue = normalized["value"]?.toString();
      if (rawValue != null) {
        await prefs.setString(name, rawValue);
        _syncPrefVar(name, rawValue);
      }
      return;
    }

    final text = value?.toString() ?? "";
    if (text.trim().isEmpty) return;

    final entries = Uri.splitQueryString(text);
    if (entries.isNotEmpty) {
      for (final entry in entries.entries) {
        await prefs.setString(entry.key, entry.value);
        _syncPrefVar(entry.key, entry.value);
      }
      return;
    }

    final separator = text.indexOf("=");
    if (separator <= 0) return;
    final name = text.substring(0, separator).trim();
    final rawValue = text.substring(separator + 1);
    if (name.isEmpty) return;
    await prefs.setString(name, rawValue);
    _syncPrefVar(name, rawValue);
  }

  static Future<void> _setPrefs(dynamic value) async {
    if (value is Map) {
      for (final entry in value.entries) {
        final name = entry.key.toString().trim();
        if (name.isEmpty) continue;
        await _setSharedPref({"name": name, "value": entry.value});
      }
      return;
    }

    if (value is Iterable) {
      for (final entry in value) {
        await _setSharedPref(entry);
      }
      return;
    }

    await _setSharedPref(value);
  }

  static Future<void> _handleNavigationCallback(
    dynamic value, {
    bool replace = false,
  }) async {
    if (value is Map) {
      final normalized = value.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final path = normalized["path"]?.toString() ?? "";
      if (path.isEmpty) return;
      final mode = normalized["mode"]?.toString() ?? "page";
      final wantsReplace =
          replace ||
          normalized["replace"] == true ||
          normalized["history"] == false;
      await changePage(path, dialog: mode == "dialog", history: !wantsReplace);
      return;
    }

    final path = value?.toString() ?? "";
    if (path.isEmpty) return;
    await changePage(path, history: !replace);
  }

  static Future<void> _remSharedPref(dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = <String>{};

    if (value is Map) {
      final normalized = value.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final rawKey = normalized["name"] ?? normalized["key"];
      if (rawKey is Iterable) {
        for (final entry in rawKey) {
          final key = entry?.toString().trim() ?? "";
          if (key.isNotEmpty) keys.add(key);
        }
      } else if (rawKey != null) {
        final key = rawKey.toString().trim();
        if (key.isNotEmpty) keys.add(key);
      }
    } else {
      final text = value?.toString() ?? "";
      if (text.trim().isEmpty) return;

      final entries = Uri.splitQueryString(text);
      if (entries.isNotEmpty) {
        keys.addAll(entries.keys.where((key) => key.trim().isNotEmpty));
      } else {
        final separator = text.indexOf("=");
        final key = separator > 0 ? text.substring(0, separator) : text;
        final trimmed = key.trim();
        if (trimmed.isNotEmpty) keys.add(trimmed);
      }
    }

    for (final key in keys) {
      await prefs.remove(key);
      _syncPrefRemoved(key);
    }
  }

  static void _syncPrefVar(String key, dynamic value) {
    final name = key.trim();
    if (name.isEmpty) {
      return;
    }

    setVar('prefs.$name', value);
    setVar('prefs.$name.isPresent', 'true');
  }

  static void _syncPrefRemoved(String key) {
    final name = key.trim();
    if (name.isEmpty) {
      return;
    }

    setVar('prefs.$name', null);
    setVar('prefs.$name.isPresent', 'false');
  }

  static void _showSnackBar(String message) {
    if (message.isEmpty) return;
    final navContext = navigatorKey.currentContext ?? currentContext;
    final messenger = ScaffoldMessenger.maybeOf(navContext);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<Map<String, dynamic>> fetchUI(String path) async {
    beginProgress();
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefPresence = <String, dynamic>{
        for (final key in prefs.getKeys())
          key: {"isPresent": true, "value": prefs.get(key)},
      };
      final requestContext = {...clientContext, "prefs": prefPresence};

      final res = await http.post(
        Uri.parse("$_baseUrl$path"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "User-Agent": "RemUI-Flutter/1.0",
        },
        body: jsonEncode(requestContext),
      );

      if (res.statusCode != 200) {
        throw Exception('Failed to fetch UI: ${res.statusCode} - ${res.body}');
      }

      return jsonDecode(res.body);
    } catch (e) {
      throw Exception('Error fetching UI from $path: $e');
    } finally {
      endProgress();
    }
  }

  static Widget buildWidget(Map<String, dynamic>? json) {
    if (json == null) return const SizedBox();
    final resolved = _resolveEqlValue(json);
    if (resolved is! Map<String, dynamic>) {
      return const SizedBox();
    }

    if (resolved["type"] == "eql") {
      final evaluated = _evaluateEqlNode(resolved);
      if (evaluated is Map<String, dynamic>) {
        return buildWidget(evaluated);
      }
      return const SizedBox();
    }

    final type = resolved["type"];
    final builder = _customRegisters[type] ?? registry[type];
    if (builder == null) return const SizedBox();
    return builder(resolved);
  }

  static dynamic _resolveEqlValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      if (value["type"] == "eql") {
        return _evaluateEqlNode(value);
      }

      return value.map((key, child) => MapEntry(key, _resolveEqlValue(child)));
    }

    if (value is List) {
      return value.map(_resolveEqlValue).toList();
    }

    return value;
  }

  static dynamic _evaluateEqlNode(Map<String, dynamic> node) {
    final varName = node["var"]?.toString() ?? "";
    final expected = node["eq"]?.toString();
    final actual = getVar(varName)?.toString();
    final matches = actual == expected;

    if (matches) {
      return _resolveEqlValue(node["value"]);
    }

    final elseIf = node["elseIf"];
    if (elseIf is Map<String, dynamic>) {
      final next = _evaluateEqlNode(elseIf);
      if (next != null) return next;
    }

    if (elseIf is List) {
      for (final branch in elseIf) {
        if (branch is Map<String, dynamic>) {
          final next = _evaluateEqlNode(branch);
          if (next != null) return next;
        }
      }
    }

    if (node.containsKey("else")) {
      return _resolveEqlValue(node["else"]);
    }

    return null;
  }

  static Widget? buildCustomPage(String page, Map<String, dynamic> json) {
    final builder = _customPages[page];
    if (builder == null) {
      return null;
    }

    return builder(json);
  }

  static Map<String, dynamic> _coerceStringMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }

    return {};
  }

  static Future<Widget> loadPage(
    String path, {
    bool applyResponseVars = true,
    bool queueCallbacks = true,
  }) async {
    final localPage = _customPages[path];
    if (localPage != null) {
      return localPage(<String, dynamic>{'page': path});
    }

    final json = await fetchUI(path);
    final resolvedVars = _coerceStringMap(json["vars"]);
    if (applyResponseVars && resolvedVars.isNotEmpty) {
      setVars(resolvedVars);
    }

    if (queueCallbacks) {
      setCallbacks(json["callbacks"]);
    }

    final page = json["page"]?.toString();
    if (page != null) {
      final customPage = _customPages[page];
      if (customPage != null) {
        return customPage(json);
      }
    }
    final handler = page == null ? null : _pageHandlers[page];
    void onClick(String action) {
      handler?.call(onClick, action);
    }

    return buildWidget(json);
  }

  static Future<void> changePage(
    String path, {
    bool history = true,
    bool dialog = false,
  }) async {
    if (dialog) {
      final navContext = navigatorKey.currentContext;
      if (navContext == null) return;

      _openDialogCount = _openDialogCount + 1;
      await showDialog<void>(
        context: navContext,
        barrierDismissible: true,
        builder: (_) => RemUIDialogPage(path: path),
      ).whenComplete(() {
        if (_openDialogCount > 0) {
          _openDialogCount = _openDialogCount - 1;
        }
      });
      return;
    }

    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final page = RemUIPage(path: path);
    if (history) {
      nav.push(MaterialPageRoute(builder: (_) => page));
    } else {
      nav.pushReplacement(MaterialPageRoute(builder: (_) => page));
    }
  }

  static Future<Map<String, dynamic>> debugSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "baseUrl": _baseUrl,
      "clientContext": clientContext,
      "variables": Map<String, dynamic>.from(variables),
      "callbacks": List<dynamic>.from(callbacks),
      "pendingCallbacks": List<dynamic>.from(pendingCallbacks),
      "registeredWidgets": registry.keys.toList()..sort(),
      "registeredCustomWidgets": _customRegisters.keys.toList()..sort(),
      "registeredPages": _customPages.keys.toList()..sort(),
      "sharedPreferences": {
        for (final key in prefs.getKeys()) key: prefs.get(key),
      },
    };
  }

  static void openDebugTool() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(builder: (_) => const RemUIDebugPage()));
  }

  static void closeDialog() {
    if (_openDialogCount <= 0) {
      return;
    }

    final nav = navigatorKey.currentState;
    if (nav == null || !nav.canPop()) {
      return;
    }

    nav.pop();
  }

  static void reloadRetain() {
    reloadRetainTick.value = reloadRetainTick.value + 1;
  }
}

class RemUIDebugPage extends StatelessWidget {
  const RemUIDebugPage({super.key});

  String _pretty(dynamic value) {
    return const JsonEncoder.withIndent('  ').convert(value);
  }

  Widget _section(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                _pretty(value),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RemUI Debug Tool')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: RemUI.debugSnapshot(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section('Base URL', data['baseUrl']),
              _section('Client Context', data['clientContext']),
              _section('Variables', data['variables']),
              _section('SharedPreferences', data['sharedPreferences']),
              _section('Callbacks', data['callbacks']),
              _section('Pending Callbacks', data['pendingCallbacks']),
              _section('Registered Widgets', data['registeredWidgets']),
            ],
          );
        },
      ),
    );
  }
}

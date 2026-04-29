import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'remui.dart';

Future<void> handleClick(Map<String, dynamic> json) async {
  final action =
      json["action"] ?? json["open"] ?? json["onClick"] ?? json["onPressed"];

  if (action is String) {
    if (action.startsWith("nav:")) {
      RemUI.changePage(action.replaceFirst("nav:", ""));
      return;
    }

    if (action.startsWith("navReplace:")) {
      RemUI.changePage(action.replaceFirst("navReplace:", ""), history: false);
      return;
    }

    if (action == "submit") {
      await submitVariables(json);
      return;
    }

    if (action.startsWith("setVar:")) {
      _applySetVarString(action.substring("setVar:".length));
      return;
    }
  }

  if (action is Map) {
    final normalized = action.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    if (normalized["type"] == "nav") {
      final path = normalized["path"]?.toString() ?? "";
      if (path.isEmpty) return;
      final mode = normalized["mode"]?.toString() ?? "page";
      final replace =
          normalized["replace"] == true || normalized["history"] == false;
      await RemUI.changePage(path, dialog: mode == "dialog", history: !replace);
      return;
    }

    if (normalized["type"] == "setVar") {
      _applySetVar(normalized);
      if ((normalized["reloadRetain"] ?? normalized["loadRetain"]) == true) {
        RemUI.reloadRetain();
      }
      return;
    }

    if (normalized["type"] == "setPrefs") {
      final entries = normalized["entries"];
      if (entries is Map) {
        await _setPrefs(entries);
      }
      return;
    }

    if (normalized.containsKey("setVar")) {
      _applySetVar(normalized["setVar"]);
      if ((normalized["reloadRetain"] ?? normalized["loadRetain"]) == true) {
        RemUI.reloadRetain();
      }
      return;
    }

    if (normalized["action"] == "submit") {
      await submitVariables(json, actionPayload: normalized);
      return;
    }
  }
}

Future<void> submitVariables(
  Map<String, dynamic> json, {
  Map<String, dynamic>? actionPayload,
}) async {
  final callbackId = _resolveCallbackId(json, actionPayload: actionPayload);
  if (callbackId == null || callbackId.isEmpty) {
    _showSnackBar("Missing callback id. Expected #cb1001");
    return;
  }

  final rawVariables = actionPayload?["variables"] ?? json["variables"];
  final variableNames = rawVariables is List
      ? rawVariables.map((value) => value.toString()).toList()
      : <String>[];

  final payloadVariables = <String, dynamic>{};
  if (variableNames.isEmpty) {
    payloadVariables.addAll(RemUI.variables);
  } else {
    for (final name in variableNames) {
      payloadVariables[name] = RemUI.getVar(name);
    }
  }

  RemUI.beginProgress();
  try {
    final response = await http.post(
      Uri.parse("${RemUI.baseUrl}/ui/callbacks"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "id": callbackId,
        "action": "submit",
        "variables": payloadVariables,
        "callbacks": RemUI.callbacks,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _showSnackBar(
        "Submit failed (${response.statusCode}). Check /ui/callbacks handler.",
      );
      return;
    }

    final decoded = jsonDecode(response.body);
    final callbacks = decoded is Map ? decoded["callbacks"] : null;
    if (callbacks is List) {
      await RemUI.runCallbacks(callbacks);
      return;
    }

    _showSnackBar("Submit completed, but no callbacks were returned.");
  } catch (e) {
    _showSnackBar("Submit error: $e");
  } finally {
    RemUI.endProgress();
  }
}

String? _resolveCallbackId(
  Map<String, dynamic> json, {
  Map<String, dynamic>? actionPayload,
}) {
  final fromAction = actionPayload?["id"]?.toString();
  if (fromAction != null && fromAction.trim().isNotEmpty) {
    return fromAction.trim();
  }

  final fromJson = json["callbackId"]?.toString() ?? json["id"]?.toString();
  if (fromJson == null || fromJson.trim().isEmpty) {
    return null;
  }

  return fromJson.trim();
}

Future<void> executeCallbacks(List<dynamic> callbacks) async {
  for (final callback in callbacks) {
    if (callback is Map) {
      await executeCallback(
        callback.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
  }
}

Future<void> executeCallback(Map<String, dynamic> callback) async {
  if (callback.containsKey("setSharedPref")) {
    await _setSharedPref(callback["setSharedPref"]);
  }

  if (callback.containsKey("setPrefs")) {
    await _setPrefs(callback["setPrefs"]);
  }

  if (callback.containsKey("setVar")) {
    _applySetVar(callback["setVar"]);
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
    await _handleNavigationCallback(callback["pushPageReplace"], replace: true);
  } else if (callback.containsKey("pushPage")) {
    await _handleNavigationCallback(callback["pushPage"]);
  }

  if (callback.containsKey("navReplace")) {
    await _handleNavigationCallback(callback["navReplace"], replace: true);
  } else if (callback.containsKey("nav")) {
    await _handleNavigationCallback(callback["nav"]);
  }
}

void _applySetVar(dynamic value) {
  if (value is Map) {
    final normalized = value.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final name =
        normalized["var"]?.toString() ?? normalized["name"]?.toString();
    if (name == null || name.isEmpty) return;
    RemUI.setVar(name, normalized["value"]);
    return;
  }

  if (value is String) {
    _applySetVarString(value);
  }
}

void _applySetVarString(String value) {
  final separator = value.indexOf("=");
  if (separator <= 0) return;
  final name = value.substring(0, separator).trim();
  final rawValue = value.substring(separator + 1);
  if (name.isEmpty) return;
  RemUI.setVar(name, rawValue);
}

Future<void> _setSharedPref(dynamic value) async {
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
    }
    return;
  }

  final text = value?.toString() ?? "";
  if (text.trim().isEmpty) return;

  final entries = Uri.splitQueryString(text);
  if (entries.isNotEmpty) {
    for (final entry in entries.entries) {
      await prefs.setString(entry.key, entry.value);
    }
    return;
  }

  final separator = text.indexOf("=");
  if (separator <= 0) return;
  final name = text.substring(0, separator).trim();
  final rawValue = text.substring(separator + 1);
  if (name.isEmpty) return;
  await prefs.setString(name, rawValue);
}

Future<void> _setPrefs(dynamic value) async {
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

Future<void> _handleNavigationCallback(
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
    await RemUI.changePage(
      path,
      dialog: mode == "dialog",
      history: !wantsReplace,
    );
    return;
  }

  final path = value?.toString() ?? "";
  if (path.isEmpty) return;
  await RemUI.changePage(path, history: !replace);
}

void _showSnackBar(String message) {
  if (message.isEmpty) return;
  final navContext = RemUI.navigatorKey.currentContext;
  final messenger = navContext != null
      ? ScaffoldMessenger.maybeOf(navContext)
      : ScaffoldMessenger.maybeOf(RemUI.currentContext);
  messenger?.showSnackBar(SnackBar(content: Text(message)));
}

part of '../registers.dart';

bool _isRemoteImageSource(String value) {
  final lower = value.toLowerCase();
  return lower.startsWith('http://') || lower.startsWith('https://');
}

bool _isSvgSource(String value) {
  return value.toLowerCase().endsWith('.svg');
}

Widget _buildRemVisualIcon(
  dynamic iconData, {
  Color? tint,
  double defaultSize = 22,
}) {
  Widget imageIcon(String src, {double? size}) {
    final iconSize = size ?? defaultSize;
    if (_isSvgSource(src)) {
      return SvgPicture.network(
        src,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        colorFilter: tint != null
            ? ColorFilter.mode(tint, BlendMode.srcIn)
            : null,
      );
    }

    return Image.network(
      src,
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
      color: tint,
      colorBlendMode: tint != null ? BlendMode.srcIn : null,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.image_not_supported, size: iconSize, color: tint),
    );
  }

  if (iconData is Map<String, dynamic>) {
    final type = iconData["type"]?.toString().trim();
    final size = (iconData["size"] as num?)?.toDouble() ?? defaultSize;

    if (type == 'Icon') {
      return Icon(
        Resolv.icon(iconData["icon"]),
        size: size,
        color:
            tint ??
            Resolv.color(iconData["color"], context: RemUI.currentContext),
      );
    }

    if (type == 'Image') {
      final src =
          iconData["src"]?.toString() ?? iconData["imageUrl"]?.toString();
      if (src != null && src.isNotEmpty && _isRemoteImageSource(src)) {
        return imageIcon(src, size: size);
      }
    }

    return IconTheme(
      data: IconThemeData(color: tint, size: size),
      child: RemUI.buildWidget(iconData),
    );
  }

  if (iconData is String) {
    final source = iconData.trim();
    if (source.isEmpty) {
      return Icon(Icons.circle_outlined, size: defaultSize, color: tint);
    }

    if (_isRemoteImageSource(source)) {
      return imageIcon(source);
    }

    return Icon(
      Resolv.icon(source, fallback: Icons.circle_outlined),
      size: defaultSize,
      color: tint,
    );
  }

  return Icon(Icons.circle_outlined, size: defaultSize, color: tint);
}

Widget _buildRemBottomNavIcon(
  dynamic iconData, {
  required bool isActive,
  required Color? activeColor,
  required Color? inactiveColor,
  double defaultSize = 22,
}) {
  final tint = isActive ? activeColor : inactiveColor;
  return _buildRemVisualIcon(iconData, tint: tint, defaultSize: defaultSize);
}

List<Map<String, dynamic>> _normalizeDropdownEntries(dynamic raw) {
  if (raw is List) {
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  if (raw is Map<String, dynamic>) {
    final nested = raw["dropdowns"];
    if (nested is List) {
      return nested.whereType<Map<String, dynamic>>().toList();
    }
  }

  return <Map<String, dynamic>>[];
}

class _RemDropdownsMenu extends StatelessWidget {
  final Map<String, dynamic> json;

  const _RemDropdownsMenu({required this.json});

  @override
  Widget build(BuildContext context) {
    final entries = _normalizeDropdownEntries(json["dropdowns"]);
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final compact =
        MediaQuery.of(context).size.width <
        ((json["compactBreakpoint"] as num?)?.toDouble() ?? 760);
    final textColor =
        Resolv.color(json["textColor"], context: RemUI.currentContext) ??
        const Color(0xFF1F2937);
    final hoverColor =
        Resolv.color(json["hoverColor"], context: RemUI.currentContext) ??
        const Color(0xFFEFF6FF);

    final menu = MenuBar(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          Resolv.color(
                json["backgroundColor"],
                context: RemUI.currentContext,
              ) ??
              Colors.transparent,
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: (json["paddingX"] as num?)?.toDouble() ?? 4,
            vertical: (json["paddingY"] as num?)?.toDouble() ?? 4,
          ),
        ),
      ),
      children: [
        for (final entry in entries)
          _buildRecursiveDropdownButton(
            entry,
            textColor: textColor,
            hoverColor: hoverColor,
            compact: compact,
            level: 0,
          ),
      ],
    );

    if (!compact) {
      return menu;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: menu,
    );
  }
}

Widget _buildRecursiveDropdownButton(
  Map<String, dynamic> item, {
  required Color textColor,
  required Color hoverColor,
  required bool compact,
  required int level,
}) {
  final nested = _normalizeDropdownEntries(item["dropdowns"]);
  final iconSize = compact ? 14.0 : 16.0;
  final label = item["name"]?.toString() ?? item["label"]?.toString() ?? 'Item';
  final child = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _buildRemVisualIcon(item["icon"], tint: textColor, defaultSize: iconSize),
      const SizedBox(width: 8),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 124 : 180),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: compact ? 3 : 1,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      if (nested.isNotEmpty) ...[
        const SizedBox(width: 8),
        Icon(
          level == 0 ? Icons.expand_more : Icons.chevron_right,
          size: compact ? 14 : 16,
          color: textColor.withValues(alpha: 0.8),
        ),
      ],
    ],
  );

  final baseStyle = ButtonStyle(
    overlayColor: WidgetStatePropertyAll(hoverColor),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  if (nested.isEmpty) {
    return MenuItemButton(
      style: baseStyle,
      onPressed: () {
        handleClick(item);
      },
      child: child,
    );
  }

  return SubmenuButton(
    style: baseStyle,
    menuStyle: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(
        Resolv.color(item["menuColor"], context: RemUI.currentContext) ??
            Colors.white,
      ),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(8),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          side: BorderSide(
            color:
                Resolv.color(
                  item["borderColor"],
                  context: RemUI.currentContext,
                ) ??
                const Color(0x1A64748B),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      alignment: level == 0 ? Alignment.bottomLeft : Alignment.topRight,
    ),
    menuChildren: [
      for (final nestedItem in nested)
        _buildRecursiveDropdownButton(
          nestedItem,
          textColor: textColor,
          hoverColor: hoverColor,
          compact: compact,
          level: level + 1,
        ),
    ],
    child: child,
  );
}

Widget _buildRemNavbarTitle(dynamic rawTitle, bool compact, Color textColor) {
  if (rawTitle is Map<String, dynamic>) {
    return DefaultTextStyle(
      style: TextStyle(
        fontSize: compact ? 13 : 15,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      child: RemUI.buildWidget(rawTitle),
    );
  }

  return Text(
    rawTitle?.toString() ?? '',
    maxLines: compact ? 3 : 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: compact ? 13 : 15,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
  );
}

Widget _buildNavDrawerItem(
  Map<String, dynamic> item, {
  required BuildContext context,
  required Color textColor,
  required Color hoverColor,
}) {
  final nested = _normalizeDropdownEntries(item["dropdowns"]);
  final label = item["name"]?.toString() ?? item["label"]?.toString() ?? '';

  if (nested.isEmpty) {
    return ListTile(
      leading: _buildRemVisualIcon(
        item["icon"],
        tint: textColor,
        defaultSize: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      hoverColor: hoverColor,
      onTap: () {
        Navigator.of(context).pop();
        handleClick(item);
      },
    );
  }

  return Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      leading: _buildRemVisualIcon(
        item["icon"],
        tint: textColor,
        defaultSize: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      iconColor: textColor,
      collapsedIconColor: textColor.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      children: nested
          .map(
            (n) => Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _buildNavDrawerItem(
                n,
                context: context,
                textColor: textColor,
                hoverColor: hoverColor,
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _RemNavbarDrawerPanel extends StatelessWidget {
  final Map<String, dynamic> json;
  const _RemNavbarDrawerPanel({required this.json});

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        Resolv.color(
          json["backgroundColor"],
          context: RemUI.currentContext,
          fallback: Colors.white,
        ) ??
        Colors.white;
    final borderColor =
        Resolv.color(
          json["borderColor"],
          context: RemUI.currentContext,
          fallback: const Color(0xFFE2E8F0),
        ) ??
        const Color(0xFFE2E8F0);
    final titleColor =
        Resolv.color(
          json["titleColor"],
          context: RemUI.currentContext,
          fallback: const Color(0xFF111827),
        ) ??
        const Color(0xFF111827);

    final logo = json["logo"] is Map<String, dynamic>
        ? RemUI.buildWidget(json["logo"])
        : null;
    final searchWidget = json["searchTextField"] is Map<String, dynamic>
        ? RemUI.buildWidget(json["searchTextField"])
        : null;
    final dropdownEntries = _normalizeDropdownEntries(json["dropdowns"]);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        height: double.infinity,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(left: BorderSide(color: borderColor)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    if (logo != null) ...[
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: FittedBox(fit: BoxFit.contain, child: logo),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: _buildRemNavbarTitle(
                        json["title"],
                        false,
                        titleColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: titleColor.withValues(alpha: 0.55),
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),
              if (searchWidget != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: searchWidget,
                ),
              if (dropdownEntries.isNotEmpty)
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    children: dropdownEntries
                        .map(
                          (e) => _buildNavDrawerItem(
                            e,
                            context: context,
                            textColor: titleColor,
                            hoverColor: const Color(0xFFEFF6FF),
                          ),
                        )
                        .toList(),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemNavbar extends StatelessWidget implements PreferredSizeWidget {
  final Map<String, dynamic> json;
  const _RemNavbar({required this.json});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildLayout);
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final maxWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : MediaQuery.of(context).size.width;
    final compact =
        maxWidth < ((json["compactBreakpoint"] as num?)?.toDouble() ?? 760);

    final backgroundColor =
        Resolv.color(
          json["backgroundColor"],
          context: RemUI.currentContext,
          fallback: Colors.white,
        ) ??
        Colors.white;
    final borderColor =
        Resolv.color(
          json["borderColor"],
          context: RemUI.currentContext,
          fallback: const Color(0xFFE2E8F0),
        ) ??
        const Color(0xFFE2E8F0);
    final titleColor =
        Resolv.color(
          json["titleColor"],
          context: RemUI.currentContext,
          fallback: const Color(0xFF111827),
        ) ??
        const Color(0xFF111827);
    final iconColor =
        Resolv.color(
          json["iconColor"],
          context: RemUI.currentContext,
          fallback: titleColor,
        ) ??
        titleColor;

    final isAppBar = json["isAppBar"] as bool? ?? false;
    final paddingX =
        (json["paddingX"] as num?)?.toDouble() ?? (compact ? 12.0 : 16.0);
    final paddingY =
        (json["paddingY"] as num?)?.toDouble() ??
        (isAppBar ? 0.0 : (compact ? 8.0 : 10.0));

    final BoxDecoration decoration = isAppBar
        ? BoxDecoration(
            color: backgroundColor,
            border: Border(bottom: BorderSide(color: borderColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          )
        : BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(
              (json["radius"] as num?)?.toDouble() ?? 14,
            ),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          );

    final logo = json["logo"] is Map<String, dynamic>
        ? RemUI.buildWidget(json["logo"])
        : null;
    final dropdownEntries = _normalizeDropdownEntries(json["dropdowns"]);
    Widget? dropdownWidget;
    if (json["dropdowns"] is Map<String, dynamic>) {
      dropdownWidget = RemUI.buildWidget(json["dropdowns"]);
    } else if (dropdownEntries.isNotEmpty) {
      dropdownWidget = _RemDropdownsMenu(
        json: {"dropdowns": json["dropdowns"]},
      );
    }

    final hasDrawer =
        dropdownEntries.isNotEmpty ||
        json["dropdowns"] is Map<String, dynamic> ||
        json["searchTextField"] is Map<String, dynamic>;

    final Widget child;
    if (compact) {
      child = Row(
        children: [
          if (logo != null) ...[
            SizedBox(
              width: 32,
              height: 32,
              child: FittedBox(fit: BoxFit.contain, child: logo),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: _buildRemNavbarTitle(json["title"], true, titleColor),
          ),
          if (hasDrawer)
            IconButton(
              icon: Icon(Icons.menu_rounded, color: iconColor, size: 22),
              padding: const EdgeInsets.all(8),
              onPressed: () => _showDrawer(context),
              tooltip: 'Open navigation',
            ),
        ],
      );
    } else {
      final searchWidget = json["searchTextField"] is Map<String, dynamic>
          ? RemUI.buildWidget(json["searchTextField"])
          : null;
      final itemGap = (json["itemGap"] as num?)?.toDouble() ?? 12;
      child = Row(
        children: [
          if (logo != null) ...[
            SizedBox(
              width: 34,
              height: 34,
              child: FittedBox(fit: BoxFit.contain, child: logo),
            ),
            const SizedBox(width: 10),
          ],
          _buildRemNavbarTitle(json["title"], false, titleColor),
          if (dropdownWidget != null) ...[
            SizedBox(width: itemGap),
            dropdownWidget,
          ],
          const Spacer(),
          if (searchWidget != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (json["searchWidth"] as num?)?.toDouble() ?? 260,
              ),
              child: searchWidget,
            ),
        ],
      );
    }

    return Container(
      decoration: decoration,
      padding: EdgeInsets.symmetric(horizontal: paddingX, vertical: paddingY),
      height: isAppBar ? kToolbarHeight : null,
      alignment: isAppBar ? Alignment.center : null,
      child: child,
    );
  }

  void _showDrawer(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close navigation',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, _, _) => Align(
        alignment: Alignment.centerRight,
        child: _RemNavbarDrawerPanel(json: json),
      ),
      transitionBuilder: (ctx, animation, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    );
  }
}

dynamic _valueAtPath(dynamic source, String path) {
  if (path.trim().isEmpty) {
    return source;
  }

  dynamic current = source;
  for (final segment
      in path.split('.').where((part) => part.trim().isNotEmpty)) {
    if (current is Map) {
      current = current[segment];
      continue;
    }

    return null;
  }

  return current;
}

String _resolveForeachTextTemplate(String input, Map<String, dynamic> row) {
  if (!input.contains(r'$')) {
    return input;
  }

  return input.replaceAllMapped(RegExp(r'\$([^$]+)\$'), (match) {
    final token = (match.group(1) ?? '').trim();
    if (token.isEmpty) {
      return match.group(0) ?? '';
    }

    if (token == 'index' || token == '_index') {
      final idx = row['_index'];
      if (idx != null) {
        return idx.toString();
      }
    }

    String rowToken = token;
    if (token.startsWith('row.')) {
      rowToken = token.substring(4);
    } else if (token.startsWith('item.')) {
      rowToken = token.substring(5);
    }

    final rowValue = _valueAtPath(row, rowToken);
    if (rowValue != null) {
      if (rowValue is List || rowValue is Map) {
        return jsonEncode(rowValue);
      }
      return rowValue.toString();
    }

    final nestedValue = row['value'];
    if (nestedValue != null) {
      if (rowToken == 'value') {
        if (nestedValue is List || nestedValue is Map) {
          return jsonEncode(nestedValue);
        }
        return nestedValue.toString();
      }

      final nestedPathValue = _valueAtPath(nestedValue, rowToken);
      if (nestedPathValue != null) {
        if (nestedPathValue is List || nestedPathValue is Map) {
          return jsonEncode(nestedPathValue);
        }
        return nestedPathValue.toString();
      }
    }

    final globalValue = RemUI.getVar(token);
    if (globalValue == null) {
      return match.group(0) ?? '';
    }

    if (globalValue is List || globalValue is Map) {
      return jsonEncode(globalValue);
    }
    return globalValue.toString();
  });
}

dynamic _resolveForeachTemplateValue(dynamic value, Map<String, dynamic> row) {
  if (value is String) {
    return _resolveForeachTextTemplate(value, row);
  }

  if (value is List) {
    return value
        .map((entry) => _resolveForeachTemplateValue(entry, row))
        .toList();
  }

  if (value is Map) {
    return value.map(
      (key, entry) =>
          MapEntry(key.toString(), _resolveForeachTemplateValue(entry, row)),
    );
  }

  return value;
}

List<Map<String, dynamic>> _extractForeachRows(
  dynamic payload,
  String toForeach,
) {
  final dynamic segment = _valueAtPath(payload, toForeach);

  if (segment is List) {
    final rows = <Map<String, dynamic>>[];
    for (final entry in segment) {
      if (entry is Map<String, dynamic>) {
        rows.add(entry);
        continue;
      }

      if (entry is Map) {
        rows.add(entry.map((key, value) => MapEntry(key.toString(), value)));
        continue;
      }

      rows.add({'value': entry});
    }
    return rows;
  }

  return <Map<String, dynamic>>[];
}

class _ForeachWidget extends StatefulWidget {
  final Map<String, dynamic> json;

  const _ForeachWidget({required this.json});

  @override
  State<_ForeachWidget> createState() => _ForeachWidgetState();
}

class _ForeachWidgetState extends State<_ForeachWidget> {
  Future<List<Map<String, dynamic>>>? _futureRows;
  String? _lastFetchKey;

  @override
  void initState() {
    super.initState();
    _lastFetchKey = _computeFetchKey();
    _futureRows = _fetchRows();
  }

  @override
  void didUpdateWidget(covariant _ForeachWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.json != widget.json) {
      _lastFetchKey = _computeFetchKey();
      _futureRows = _fetchRows();
    }
  }

  String _computeFetchKey() {
    // Resolve templates against the current variable state so we re-fetch only when the
    // effective request actually changes — not on every keystroke/var tick.
    final url = _resolveForeachTemplateValue(
      widget.json['url'],
      const <String, dynamic>{},
    );
    final headers = _resolveForeachTemplateValue(
      widget.json['headers'],
      const <String, dynamic>{},
    );
    final body = _resolveForeachTemplateValue(
      widget.json['body'],
      const <String, dynamic>{},
    );
    final toForeach = _resolveForeachTemplateValue(
      widget.json['toForeach'],
      const <String, dynamic>{},
    );
    return jsonEncode([url, headers, body, toForeach]);
  }

  Future<List<Map<String, dynamic>>> _ensureFuture() {
    final key = _computeFetchKey();
    if (_futureRows == null || _lastFetchKey != key) {
      _lastFetchKey = key;
      _futureRows = _fetchRows();
    }
    return _futureRows!;
  }

  Future<List<Map<String, dynamic>>> _fetchRows() async {
    final rawUrl =
        _resolveForeachTemplateValue(
          widget.json['url'],
          const <String, dynamic>{},
        )?.toString().trim() ??
        '';
    if (rawUrl.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    if (RegExp(r'\{[^}]+\}').hasMatch(rawUrl)) {
      return <Map<String, dynamic>>[];
    }

    final inlinePayload = _tryParseJsonPayload(rawUrl);
    if (inlinePayload != null) {
      final path =
          _resolveForeachTemplateValue(
            widget.json['toForeach'],
            const <String, dynamic>{},
          )?.toString().trim() ??
          '.';
      return _extractForeachRows(inlinePayload, path.isEmpty ? '.' : path);
    }

    var method = 'GET';
    var endpoint = rawUrl;

    final methodMatch = RegExp(
      r'^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s*:(.+)$',
      caseSensitive: false,
    ).firstMatch(rawUrl);

    if (methodMatch != null) {
      method = (methodMatch.group(1) ?? 'GET').toUpperCase();
      endpoint = (methodMatch.group(2) ?? '').trim();
    }

    if (endpoint.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final headers = <String, String>{};
    final rawHeaders = _resolveForeachTemplateValue(
      widget.json['headers'],
      const <String, dynamic>{},
    );
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) {
          continue;
        }
        headers[key] = entry.value?.toString() ?? '';
      }
    }

    final body = _resolveForeachTemplateValue(
      widget.json['body'],
      const <String, dynamic>{},
    );
    final requestUri = Uri.parse(endpoint);

    http.Response response;

    switch (method) {
      case 'POST':
      case 'PUT':
      case 'PATCH':
      case 'DELETE':
        headers.putIfAbsent('Content-Type', () => 'application/json');
        final encodedBody = body == null ? null : jsonEncode(body);
        if (method == 'POST') {
          response = await http.post(
            requestUri,
            headers: headers,
            body: encodedBody,
          );
        } else if (method == 'PUT') {
          response = await http.put(
            requestUri,
            headers: headers,
            body: encodedBody,
          );
        } else if (method == 'PATCH') {
          response = await http.patch(
            requestUri,
            headers: headers,
            body: encodedBody,
          );
        } else {
          response = await http.delete(
            requestUri,
            headers: headers,
            body: encodedBody,
          );
        }
        break;
      case 'HEAD':
        response = await http.head(requestUri, headers: headers);
        break;
      case 'OPTIONS':
        final request = http.Request('OPTIONS', requestUri);
        request.headers.addAll(headers);
        final streamed = await request.send();
        response = await http.Response.fromStream(streamed);
        break;
      case 'GET':
      default:
        response = await http.get(requestUri, headers: headers);
        break;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return <Map<String, dynamic>>[];
    }

    dynamic payload;
    try {
      payload = jsonDecode(response.body);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }

    final path =
        _resolveForeachTemplateValue(
          widget.json['toForeach'],
          const <String, dynamic>{},
        )?.toString().trim() ??
        'data';
    return _extractForeachRows(payload, path.isEmpty ? 'data' : path);
  }

  @override
  Widget build(BuildContext context) {
    final templateRaw = widget.json['data'];
    final fallbackWidget = widget.json['fallback'] is Map<String, dynamic>
        ? widget.json['fallback'] as Map<String, dynamic>
        : <String, dynamic>{'type': 'SizedBox', 'height': 0};
    final loadingWidget = widget.json['loading'] is Map<String, dynamic>
        ? widget.json['loading'] as Map<String, dynamic>
        : <String, dynamic>{
            'type': 'Center',
            'child': <String, dynamic>{'type': 'Text', 'text': 'Loading...'},
          };
    final spacing = (widget.json['spacing'] as num?)?.toDouble() ?? 0;

    if (templateRaw is! Map<String, dynamic>) {
      return RemUI.buildWidget(fallbackWidget);
    }

    return ValueListenableBuilder<int>(
      valueListenable: RemUI.variableTick,
      builder: (context, _, __) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _ensureFuture(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return RemUI.buildWidget(loadingWidget);
            }

            if (snapshot.hasError) {
              return RemUI.buildWidget(fallbackWidget);
            }

            final rows = snapshot.data ?? const <Map<String, dynamic>>[];
            if (rows.isEmpty) {
              return RemUI.buildWidget(fallbackWidget);
            }

            final children = <Widget>[];
            for (var index = 0; index < rows.length; index++) {
              final row = <String, dynamic>{...rows[index], '_index': index};
              final resolved = _resolveForeachTemplateValue(templateRaw, row);
              if (resolved is Map<String, dynamic>) {
                children.add(RemUI.buildWidget(resolved));
                if (spacing > 0 && index < rows.length - 1) {
                  children.add(SizedBox(height: spacing));
                }
              }
            }

            final direction = widget.json['direction']
                ?.toString()
                .toLowerCase()
                .trim();
            if (direction == 'row' || direction == 'horizontal') {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: children),
              );
            }

            return Column(
              crossAxisAlignment: Resolv.resolveCrossAxis(
                widget.json['crossAxis'] ?? widget.json['crossAxisAlignment'],
                fallback: CrossAxisAlignment.start,
              ),
              children: children,
            );
          },
        );
      },
    );
  }
}

dynamic _tryParseJsonPayload(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) {
    return null;
  }

  try {
    return jsonDecode(trimmed);
  } catch (_) {
    return null;
  }
}

final Map<String, Widget Function(Map<String, dynamic>)>
_remCompWidgetsRegistry = {
  "RemBottomNavbar": (j) {
    final variableName = j["variable"]?.toString().trim();

    return ValueListenableBuilder<int>(
      valueListenable: RemUI.variableTick,
      builder: (context, _, __) {
        final items = (j["items"] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

        final initialIndex = _resolveNavigationIndex(j["currentIndex"]) ?? 0;
        final fromVar = variableName != null && variableName.isNotEmpty
            ? _resolveNavigationIndex(RemUI.getVar(variableName))
            : null;

        final itemCount = items.length;
        final selectedIndex = itemCount == 0
            ? 0
            : ((fromVar ?? initialIndex).clamp(0, itemCount - 1) as int);

        final activeColor =
            Resolv.color(
              j["activeColor"],
              context: RemUI.currentContext,
              fallback: const Color(0xFF0D47A1),
            ) ??
            const Color(0xFF0D47A1);

        final inactiveColor =
            Resolv.color(
              j["noActiveColor"] ?? j["inactiveColor"],
              context: RemUI.currentContext,
              fallback: const Color(0xFF64748B),
            ) ??
            const Color(0xFF64748B);

        final backgroundColor =
            Resolv.color(
              j["backgroundColor"],
              context: RemUI.currentContext,
              fallback: Colors.white,
            ) ??
            Colors.white;

        final activeBackgroundColor =
            Resolv.color(
              j["activeBackgroundColor"],
              context: RemUI.currentContext,
              fallback: activeColor.withValues(alpha: 0.12),
            ) ??
            activeColor.withValues(alpha: 0.12);

        final borderColor =
            Resolv.color(
              j["borderColor"],
              context: RemUI.currentContext,
              fallback: const Color(0xFFE2E8F0),
            ) ??
            const Color(0xFFE2E8F0);

        final iconSize = (j["iconSize"] as num?)?.toDouble() ?? 22;
        final height = (j["height"] as num?)?.toDouble() ?? 72;
        final horizontalPadding = (j["paddingX"] as num?)?.toDouble() ?? 12;
        final verticalPadding = (j["paddingY"] as num?)?.toDouble() ?? 8;
        final spacing = (j["itemSpacing"] as num?)?.toDouble() ?? 10;

        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: SafeArea(
            top: false,
            minimum: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: SizedBox(
              height: height,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      if (index > 0) SizedBox(width: spacing),
                      Builder(
                        builder: (_) {
                          final item = items[index];
                          final isActive = index == selectedIndex;
                          final hasAction =
                              item["action"] != null ||
                              item["open"] != null ||
                              item["onClick"] != null ||
                              item["onPressed"] != null ||
                              item["setVar"] != null;

                          final label = item["label"]?.toString() ?? '';

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                if (!hasAction &&
                                    variableName != null &&
                                    variableName.isNotEmpty) {
                                  RemUI.setVar(variableName, index.toString());
                                  return;
                                }

                                await handleClick(item);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? activeBackgroundColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildRemBottomNavIcon(
                                      item["icon"],
                                      isActive: isActive,
                                      activeColor: activeColor,
                                      inactiveColor: inactiveColor,
                                      defaultSize: iconSize,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isActive
                                            ? activeColor
                                            : inactiveColor,
                                        fontSize: 12,
                                        fontWeight: isActive
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  },

  "RemDropdowns": (j) {
    return _RemDropdownsMenu(json: j);
  },

  "RemNavbar": (j) => _RemNavbar(json: j),

  "foreach": (j) => _ForeachWidget(json: j),

  "Foreach": (j) => _ForeachWidget(json: j),

  "URLRequest": (j) => _ForeachWidget(json: j),
};

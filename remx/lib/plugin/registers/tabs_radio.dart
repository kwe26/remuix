part of 'package:remx/plugin/registers.dart';

class _TabsShell extends StatefulWidget {
  final Map<String, dynamic> json;

  const _TabsShell({required this.json});

  @override
  State<_TabsShell> createState() => _TabsShellState();
}

class _TabsShellState extends State<_TabsShell>
    with SingleTickerProviderStateMixin {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    final variableName = widget.json["variable"]?.toString().trim();
    final fromVar = variableName != null && variableName.isNotEmpty
        ? _resolveNavigationIndex(RemUI.getVar(variableName))
        : null;
    _selectedIndex =
        _resolveNavigationIndex(
          widget.json["currentIndex"] ?? widget.json["selectedIndex"],
        ) ??
        fromVar ??
        0;
  }

  void _setSelectedIndex(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RemUI.variableTick,
      builder: (context, _, __) {
        final tabs =
            (widget.json["tabs"] as List? ??
                    widget.json["items"] as List? ??
                    [])
                .whereType<Map<String, dynamic>>()
                .toList();
        if (tabs.isEmpty) {
          return const SizedBox.shrink();
        }

        final children =
            (widget.json["children"] as List? ??
                    widget.json["views"] as List? ??
                    [])
                .whereType<Map<String, dynamic>>()
                .map(RemUI.buildWidget)
                .toList();
        final variableName = widget.json["variable"]?.toString().trim();
        final isScrollable = widget.json["isScrollable"] == true;
        final showView = children.isNotEmpty;
        final indicatorColor = Resolv.color(
          widget.json["indicatorColor"],
          context: RemUI.currentContext,
        );
        final labelColor = Resolv.color(
          widget.json["labelColor"],
          context: RemUI.currentContext,
        );
        final unselectedLabelColor = Resolv.color(
          widget.json["unselectedLabelColor"],
          context: RemUI.currentContext,
        );
        final tabBarHeight = (widget.json["tabBarHeight"] as num?)?.toDouble();
        final indicatorWeight =
            (widget.json["indicatorWeight"] as num?)?.toDouble() ?? 2.0;
        final tabPadding = EdgeInsets.symmetric(
          horizontal: (widget.json["tabPaddingX"] as num?)?.toDouble() ?? 12,
          vertical: (widget.json["tabPaddingY"] as num?)?.toDouble() ?? 8,
        );
        final currentSelectedIndex =
            variableName != null &&
                variableName.isNotEmpty &&
                _resolveNavigationIndex(RemUI.getVar(variableName)) != null
            ? _resolveNavigationIndex(RemUI.getVar(variableName))!
            : _selectedIndex;
        final controllerIndex = currentSelectedIndex.clamp(0, tabs.length - 1);

        final renderedTabs = tabs
            .map(
              (tab) => Tab(
                icon: tab["icon"] != null
                    ? RemUI.buildWidget(tab["icon"] as Map<String, dynamic>)
                    : null,
                text: tab["label"]?.toString(),
                child: tab["child"] is Map<String, dynamic>
                    ? RemUI.buildWidget(tab["child"] as Map<String, dynamic>)
                    : null,
              ),
            )
            .toList();

        final pageChildren = showView
            ? List<Widget>.generate(
                tabs.length,
                (index) => index < children.length
                    ? children[index]
                    : const SizedBox.shrink(),
              )
            : const <Widget>[];

        final tabBar = TabBar(
          isScrollable: isScrollable,
          indicatorColor: indicatorColor,
          labelColor: labelColor,
          unselectedLabelColor: unselectedLabelColor,
          indicatorWeight: indicatorWeight,
          tabAlignment: widget.json["tabAlignment"] == "center"
              ? TabAlignment.center
              : widget.json["tabAlignment"] == "start"
              ? TabAlignment.start
              : null,
          tabs: renderedTabs,
          onTap: (index) async {
            if (index < 0 || index >= tabs.length) {
              return;
            }

            final tapped = tabs[index];
            final trackedValue = tapped["value"] ?? index;
            if (variableName != null && variableName.isNotEmpty) {
              RemUI.setVar(variableName, trackedValue);
            }
            _setSelectedIndex(index);

            final hasAction =
                tapped["action"] != null ||
                tapped["onClick"] != null ||
                tapped["onPressed"] != null ||
                tapped["setVar"] != null;
            if (hasAction) {
              await handleClick(tapped);
            }
          },
        );

        final body = showView
            ? Expanded(child: TabBarView(children: pageChildren))
            : const SizedBox.shrink();

        final shell = DefaultTabController(
          key: ValueKey<int>(controllerIndex),
          length: tabs.length,
          initialIndex: controllerIndex,
          child: Column(
            mainAxisSize: widget.json["mainAxisSize"] == "min"
                ? MainAxisSize.min
                : MainAxisSize.max,
            children: widget.json["tabBarOnly"] == true
                ? [tabBar]
                : [
                    Container(
                      height: tabBarHeight,
                      padding: tabPadding,
                      child: tabBar,
                    ),
                    if (showView) body,
                  ],
          ),
        );

        final height = (widget.json["height"] as num?)?.toDouble();
        if (height == null) {
          return shell;
        }

        return SizedBox(height: height, child: shell);
      },
    );
  }
}

final Map<String, Widget Function(Map<String, dynamic>)>
_tabsRadioWidgetsRegistry = {
  "Tabs": (j) => _TabsShell(json: j),
  "Radio": (j) => ValueListenableBuilder<int>(
    valueListenable: RemUI.variableTick,
    builder: (context, _, __) {
      final variableName = j["variable"]?.toString().trim();
      final value = j["value"] ?? j["selectedValue"] ?? j["label"]?.toString();
      final fallbackGroupValue = j["groupValue"];
      final currentGroupValue = variableName != null && variableName.isNotEmpty
          ? RemUI.getVar(variableName)
          : fallbackGroupValue;
      final activeColor = Resolv.color(
        j["activeColor"],
        context: RemUI.currentContext,
      );
      final fillColor = Resolv.color(
        j["fillColor"],
        context: RemUI.currentContext,
      );
      final label = j["label"]?.toString();
      final subtitle = j["subtitle"]?.toString();

      void updateValue(dynamic selected) {
        if (selected != value) {
          return;
        }
        if (variableName != null && variableName.isNotEmpty) {
          RemUI.setVar(variableName, value);
        }
        final action = j["action"] ?? j["onClick"] ?? j["onPressed"];
        if (action != null) {
          handleClick(j);
        }
      }

      final radio = Radio<dynamic>(
        value: value,
        groupValue: currentGroupValue,
        onChanged: updateValue,
        toggleable: j["toggleable"] == true,
        activeColor: activeColor,
        fillColor: fillColor != null
            ? WidgetStatePropertyAll<Color>(fillColor)
            : null,
      );

      final content = subtitle != null && subtitle.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label ?? value.toString()),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Resolv.color(
                      j["subtitleColor"],
                      context: RemUI.currentContext,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
            )
          : Text(label ?? value.toString());

      return j["tile"] == false
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [radio, const SizedBox(width: 8), content],
            )
          : RadioListTile<dynamic>(
              value: value,
              groupValue: currentGroupValue,
              onChanged: updateValue,
              toggleable: j["toggleable"] == true,
              activeColor: activeColor,
              fillColor: fillColor != null
                  ? WidgetStatePropertyAll<Color>(fillColor)
                  : null,
              title: label != null ? Text(label) : null,
              subtitle: subtitle != null ? Text(subtitle) : null,
            );
    },
  ),
};

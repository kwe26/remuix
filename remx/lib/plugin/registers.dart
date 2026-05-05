import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import './resolvers.dart';
import 'dart:convert';
import 'dart:async';
import './clicks.dart';
import './remui.dart';

part 'registers/tabs_radio.dart';
part 'registers/buttons.dart';
part 'registers/controls.dart';
part 'registers/remcomp.dart';

class BoundTextField extends StatefulWidget {
  final Map<String, dynamic> json;

  const BoundTextField({super.key, required this.json});

  @override
  State<BoundTextField> createState() => _BoundTextFieldState();
}

class _BoundTextFieldState extends State<BoundTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _variableName;
  VoidCallback? _varListener;

  @override
  void initState() {
    super.initState();
    _variableName = widget.json["variable"]?.toString();
    final initialValue = _variableName != null
        ? RemUI.getVar(_variableName!)?.toString()
        : null;
    _controller = TextEditingController(
      text: initialValue ?? widget.json["text"]?.toString() ?? "",
    );
    _focusNode = FocusNode();

    if (_variableName != null) {
      final existing = RemUI.getVar(_variableName!);
      final nextValue = _controller.text;
      if ((existing?.toString() ?? '') != nextValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _variableName != null) {
            RemUI.setVar(_variableName!, nextValue);
          }
        });
      }

      _varListener = () {
        if (!mounted || _variableName == null) return;
        // Don't overwrite while the user is typing — would clobber input and reset cursor.
        if (_focusNode.hasFocus) return;
        final next = RemUI.getVar(_variableName!)?.toString() ?? '';
        if (_controller.text != next) {
          _controller.text = next;
        }
      };
      RemUI.variableTick.addListener(_varListener!);
    }
  }

  @override
  void dispose() {
    if (_varListener != null) {
      RemUI.variableTick.removeListener(_varListener!);
    }
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _leadingWidget() {
    final leading = widget.json["leading"];
    if (leading == null) return const SizedBox.shrink();

    if (leading is Map<String, dynamic>) {
      return RemUI.buildWidget(leading);
    }

    final icon = Resolv.icon(leading);
    if (icon != null) {
      return Icon(icon);
    }

    return Text(leading.toString());
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      obscureText: widget.json["obscureText"] == true,
      keyboardType: _keyboardType(widget.json["keyboardType"]),
      textInputAction: _textInputAction(widget.json["textInputAction"]),
      maxLines: widget.json['obscureText'] == true
          ? 1
          : (widget.json["maxLines"] as num?)?.toInt(),
      minLines: (widget.json["minLines"] as num?)?.toInt(),
      enabled: widget.json["enabled"] != false,
      decoration: InputDecoration(
        hintText: widget.json["hintText"]?.toString(),
        labelText: widget.json["labelText"]?.toString(),
        prefixIcon: widget.json["leading"] != null ? _leadingWidget() : null,
      ),
      onChanged: (value) {
        if (_variableName != null) {
          RemUI.setVar(_variableName!, value);
        }
      },
      onSubmitted: (_) => handleClick(widget.json),
    );

    final width = (widget.json["width"] as num?)?.toDouble();
    final height = (widget.json["height"] as num?)?.toDouble();

    if (width == null && height == null) {
      return field;
    }

    return SizedBox(width: width, height: height, child: field);
  }

  TextInputType _keyboardType(dynamic value) {
    final raw = value?.toString().toLowerCase();
    switch (raw) {
      case "email":
        return TextInputType.emailAddress;
      case "number":
        return TextInputType.number;
      case "phone":
        return TextInputType.phone;
      case "multiline":
        return TextInputType.multiline;
      case "url":
        return TextInputType.url;
      case "datetime":
        return TextInputType.datetime;
      default:
        return TextInputType.text;
    }
  }

  TextInputAction _textInputAction(dynamic value) {
    final raw = value?.toString().toLowerCase();
    switch (raw) {
      case "next":
        return TextInputAction.next;
      case "done":
        return TextInputAction.done;
      case "search":
        return TextInputAction.search;
      case "send":
        return TextInputAction.send;
      default:
        return TextInputAction.done;
    }
  }
}

class _CarouselWidget extends StatefulWidget {
  final Map<String, dynamic> json;

  const _CarouselWidget({super.key, required this.json});

  @override
  State<_CarouselWidget> createState() => _CarouselWidgetState();
}

class _CarouselWidgetState extends State<_CarouselWidget>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  late Timer? _autoPlayTimer;
  late AnimationController _dotAnimationController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _dotAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _startAutoPlay();
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _pageController.dispose();
    _dotAnimationController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    final autoPlay = widget.json["autoPlay"] == true;
    if (!autoPlay) return;

    final items = (widget.json["items"] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (items.length <= 1) return;

    final durationMs =
        (widget.json["autoPlayInterval"] as num?)?.toInt() ?? 3000;
    _autoPlayTimer = Timer.periodic(Duration(milliseconds: durationMs), (_) {
      if (mounted && _pageController.hasClients) {
        final nextPage = (_currentIndex + 1) % items.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final items = (widget.json["items"] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (items.isEmpty) {
      return const Center(child: Text('No carousel items'));
    }

    final width = (widget.json["width"] as num?)?.toDouble();
    final height = (widget.json["height"] as num?)?.toDouble() ?? 300;
    final showIndicators = widget.json["showIndicators"] != false;
    final indicatorPosition =
        widget.json["indicatorPosition"]?.toString() ?? 'bottom';

    final carousel = GestureDetector(
      onTap: () {
        if (items[_currentIndex].containsKey("action") ||
            items[_currentIndex].containsKey("onPressed") ||
            items[_currentIndex].containsKey("onClick")) {
          handleClick(items[_currentIndex]);
        }
      },
      child: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          _dotAnimationController.forward(from: 0.0);
        },
        children: items.map((item) {
          return GestureDetector(
            onTap: () => handleClick(item),
            child: RemUI.buildWidget(item),
          );
        }).toList(),
      ),
    );

    if (!showIndicators) {
      return SizedBox(width: width, height: height, child: carousel);
    }

    final indicatorColor =
        Resolv.color(
          widget.json["indicatorColor"],
          context: RemUI.currentContext,
        ) ??
        const Color(0xFF0D47A1);
    final indicatorInactiveColor =
        Resolv.color(
          widget.json["indicatorInactiveColor"],
          context: RemUI.currentContext,
        ) ??
        const Color(0x80BDBDBD);
    final indicatorSize =
        (widget.json["indicatorSize"] as num?)?.toDouble() ?? 8;
    final indicatorSpacing =
        (widget.json["indicatorSpacing"] as num?)?.toDouble() ?? 8;

    final indicators = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(items.length, (index) {
        final isActive = index == _currentIndex;
        return GestureDetector(
          onTap: () => _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.symmetric(horizontal: indicatorSpacing / 2),
            width: isActive ? indicatorSize * 2 : indicatorSize,
            height: indicatorSize,
            decoration: BoxDecoration(
              color: isActive ? indicatorColor : indicatorInactiveColor,
              borderRadius: BorderRadius.circular(indicatorSize),
            ),
          ),
        );
      }),
    );

    final body = SizedBox(width: width, height: height, child: carousel);

    if (indicatorPosition == 'top') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: indicators,
          ),
          body,
        ],
      );
    } else if (indicatorPosition == 'overlay') {
      return Stack(
        children: [
          body,
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(child: indicators),
          ),
        ],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          body,
          Padding(padding: const EdgeInsets.only(top: 12), child: indicators),
        ],
      );
    }
  }
}

class _NavigationRailShell extends StatefulWidget {
  final Map<String, dynamic> json;

  const _NavigationRailShell({required this.json});

  @override
  State<_NavigationRailShell> createState() => _NavigationRailShellState();
}

class _NavigationRailShellState extends State<_NavigationRailShell> {
  late bool _extended;

  @override
  void initState() {
    super.initState();
    _extended = widget.json["extended"] == true;
  }

  void _setExtended(bool value) {
    if (_extended == value) {
      return;
    }

    setState(() {
      _extended = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RemUI.variableTick,
      builder: (context, _, __) {
        final rawDestinations =
            (widget.json["destinations"] as List?) ??
            (widget.json["items"] as List?) ??
            const [];
        final destinations = rawDestinations
            .whereType<Map<String, dynamic>>()
            .toList();

        final trackedVariableName = _resolveSidebarVariableName(
          widget.json,
          destinations,
        );
        final initialIndex =
            _resolveNavigationIndex(
              widget.json["selectedIndex"] ?? widget.json["currentIndex"],
            ) ??
            0;
        final fromVar = _resolveSidebarSelectedIndex(
          destinations,
          trackedVariableName,
        );
        final selectedIndex = destinations.isEmpty
            ? 0
            : ((fromVar ?? initialIndex).clamp(0, destinations.length - 1)
                  as int);

        final railDestinations = <NavigationRailDestination>[
          for (final d in destinations)
            NavigationRailDestination(
              padding: EdgeInsets.symmetric(
                vertical: (d["paddingY"] as num?)?.toDouble() ?? 6,
                horizontal: (d["paddingX"] as num?)?.toDouble() ?? 0,
              ),
              icon: _buildNavigationRailIcon(
                d["icon"],
                fallback: Icons.circle_outlined,
              ),
              selectedIcon: d["selectedIcon"] != null
                  ? _buildNavigationRailIcon(
                      d["selectedIcon"],
                      fallback: Icons.circle,
                    )
                  : null,
              label: d["label"] is Map<String, dynamic>
                  ? RemUI.buildWidget(d["label"])
                  : Text(d["label"]?.toString() ?? ''),
            ),
        ];

        final autoCollapse = widget.json["autoCollapse"] != false;
        final breakpoint =
            (widget.json["autoCollapseBreakpoint"] as num?)?.toDouble() ?? 820;
        final showControls = widget.json["showRailControls"] != false;

        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width;
            final autoCollapsed = autoCollapse && availableWidth < breakpoint;
            final effectiveExtended = autoCollapsed ? false : _extended;
            final compactWidth =
                (widget.json["minWidth"] as num?)?.toDouble() ?? 72;
            final extendedWidth =
                (widget.json["minExtendedWidth"] as num?)?.toDouble() ?? 232;
            final railWidth = effectiveExtended ? extendedWidth : compactWidth;

            final selectedLabelType = effectiveExtended
                ? null
                : _resolveRailLabelType(
                    widget.json["compactLabelType"] ?? widget.json["labelType"],
                  );

            Widget buildControlButton() {
              final tooltip = autoCollapsed
                  ? 'Auto-collapsed on small screens'
                  : (effectiveExtended ? 'Collapse rail' : 'Expand rail');
              final icon = autoCollapsed
                  ? Icons.auto_awesome_mosaic_outlined
                  : (effectiveExtended ? Icons.chevron_left : Icons.menu_open);

              return IconButton(
                tooltip: tooltip,
                onPressed: autoCollapsed
                    ? null
                    : () => _setExtended(!effectiveExtended),
                icon: Icon(icon),
              );
            }

            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: railWidth,
              decoration: BoxDecoration(
                color: Resolv.color(
                  widget.json["backgroundColor"],
                  context: RemUI.currentContext,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showControls)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: Row(
                        children: [if (showControls) buildControlButton()],
                      ),
                    ),
                  Expanded(
                    child: NavigationRail(
                      selectedIndex: selectedIndex,
                      backgroundColor: Resolv.color(
                        widget.json["backgroundColor"],
                        context: RemUI.currentContext,
                      ),
                      elevation: (widget.json["elevation"] as num?)?.toDouble(),
                      minWidth: compactWidth,
                      minExtendedWidth: extendedWidth,
                      extended: effectiveExtended,
                      groupAlignment: (widget.json["groupAlignment"] as num?)
                          ?.toDouble(),
                      useIndicator: widget.json["useIndicator"] as bool?,
                      indicatorColor: Resolv.color(
                        widget.json["indicatorColor"],
                        context: RemUI.currentContext,
                      ),
                      labelType: selectedLabelType,
                      selectedIconTheme: IconThemeData(
                        color: Resolv.color(
                          widget.json["selectedIconColor"],
                          context: RemUI.currentContext,
                        ),
                        size: (widget.json["selectedIconSize"] as num?)
                            ?.toDouble(),
                      ),
                      unselectedIconTheme: IconThemeData(
                        color: Resolv.color(
                          widget.json["unselectedIconColor"],
                          context: RemUI.currentContext,
                        ),
                        size: (widget.json["unselectedIconSize"] as num?)
                            ?.toDouble(),
                      ),
                      selectedLabelTextStyle: TextStyle(
                        color: Resolv.color(
                          widget.json["selectedLabelColor"],
                          context: RemUI.currentContext,
                        ),
                        fontSize: (widget.json["selectedLabelSize"] as num?)
                            ?.toDouble(),
                      ),
                      unselectedLabelTextStyle: TextStyle(
                        color: Resolv.color(
                          widget.json["unselectedLabelColor"],
                          context: RemUI.currentContext,
                        ),
                        fontSize: (widget.json["unselectedLabelSize"] as num?)
                            ?.toDouble(),
                      ),
                      leading: widget.json["leading"] is Map<String, dynamic>
                          ? RemUI.buildWidget(widget.json["leading"])
                          : null,
                      trailing: widget.json["trailing"] is Map<String, dynamic>
                          ? RemUI.buildWidget(widget.json["trailing"])
                          : null,
                      destinations: railDestinations,
                      onDestinationSelected: (index) async {
                        if (index < 0 || index >= destinations.length) {
                          return;
                        }

                        final tappedItem = destinations[index];
                        final hasAction =
                            tappedItem["action"] != null ||
                            tappedItem["onClick"] != null ||
                            tappedItem["onPressed"] != null ||
                            tappedItem["setVar"] != null;

                        if (trackedVariableName != null &&
                            trackedVariableName.isNotEmpty) {
                          RemUI.setVar(trackedVariableName, index.toString());
                        }

                        if (hasAction) {
                          await handleClick(tappedItem);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

final Map<String, Widget Function(Map<String, dynamic>)> registry = {
  "Text": (j) {
    final hasAction =
        j["action"] != null || j["onClick"] != null || j["onPressed"] != null;
    final rawText = j["text"]?.toString() ?? "";
    final isReactiveText = rawText.contains('{');

    Widget buildText() {
      final text = Text(
        _resolveTemplateText(rawText),
        style: TextStyle(
          fontSize: j["fontSize"] != null
              ? (j["fontSize"] as num).toDouble()
              : null,
          overflow: j["overflow"] != null
              ? TextOverflow.values.firstWhere(
                  (e) => e.toString() == 'TextOverflow.${j["overflow"]}',
                )
              : null,
          fontWeight: j["fontWeight"] != null
              ? Resolv.fontWeight(j["fontWeight"])
              : null,
          color: Resolv.color(j["color"], context: RemUI.currentContext),
        ),
      );

      if (!hasAction) {
        return text;
      }

      return GestureDetector(onTap: () => handleClick(j), child: text);
    }

    if (isReactiveText) {
      return ValueListenableBuilder<int>(
        valueListenable: RemUI.variableTick,
        builder: (context, _, __) => buildText(),
      );
    }

    return buildText();
  },

  "AppBar": (j) {
    final rawTitle = j["title"];
    final titleWidget = rawTitle is Map<String, dynamic>
        ? RemUI.buildWidget(rawTitle)
        : Text(rawTitle?.toString() ?? '');

    final rawActions = j["actions"];
    final actionList = rawActions is List
        ? rawActions
        : (rawActions is Map<String, dynamic>
              ? rawActions["children"] as List? ?? []
              : []);

    return AppBar(
      title: titleWidget,
      centerTitle: j["centerTitle"] ?? false,
      iconTheme: IconThemeData(
        color: Resolv.color(j["iconColor"], context: RemUI.currentContext),
      ),
      actions: actionList
          .whereType<Map<String, dynamic>>()
          .map((a) => RemUI.buildWidget(a))
          .toList(),
      backgroundColor: Resolv.color(
        j["backgroundColor"],
        context: RemUI.currentContext,
      ),
    );
  },

  "condition": (j) {
    return ValueListenableBuilder<int>(
      valueListenable: RemUI.variableTick,
      builder: (context, _, __) =>
          _renderConditionNode(j) ?? const SizedBox.shrink(),
    );
  },

  "Center": (j) => Center(child: RemUI.buildWidget(j["child"])),

  "Chip": (j) => GestureDetector(
    onTap: () => handleClick(j),
    child: Chip(
      label: j["label"] is Map<String, dynamic>
          ? RemUI.buildWidget(j["label"])
          : Text(j["label"]?.toString() ?? ''),
      avatar: j["avatar"] is Map<String, dynamic>
          ? RemUI.buildWidget(j["avatar"])
          : null,
      backgroundColor: Resolv.color(
        j["backgroundColor"],
        context: RemUI.currentContext,
      ),
      labelStyle: TextStyle(
        color: Resolv.color(j["labelColor"], context: RemUI.currentContext),
      ),
    ),
  ),

  "Avatar": (j) {
    final radius = (j["radius"] as num?)?.toDouble();
    final size = (j["size"] as num?)?.toDouble();
    final imageUrl = j["imageUrl"]?.toString() ?? j["src"]?.toString();
    final backgroundColor = Resolv.color(
      j["backgroundColor"],
      context: RemUI.currentContext,
    );
    final foregroundColor = Resolv.color(
      j["foregroundColor"],
      context: RemUI.currentContext,
    );
    final child = j["child"] is Map<String, dynamic>
        ? RemUI.buildWidget(j["child"] as Map<String, dynamic>)
        : (j["child"] != null ? Text(j["child"].toString()) : null);

    final avatar = CircleAvatar(
      radius: radius ?? (size != null ? size / 2 : null),
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      backgroundImage: imageUrl != null && imageUrl.isNotEmpty
          ? NetworkImage(imageUrl)
          : null,
      child: imageUrl == null || imageUrl.isEmpty ? child : null,
    );

    if (size == null) {
      return avatar;
    }

    return SizedBox(width: size, height: size, child: avatar);
  },

  "TextField": (j) => BoundTextField(json: j),

  "VerticalScroll": (j) => SingleChildScrollView(
    scrollDirection: Axis.vertical,
    child: RemUI.buildWidget(j["child"]),
  ),

  "HorizontalScroll": (j) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: RemUI.buildWidget(j["child"]),
  ),

  "Icon": (j) => Icon(
    Resolv.icon(j["icon"]),
    size: j["size"] != null ? (j["size"] as num).toDouble() : null,
    color: Resolv.color(j["color"], context: RemUI.currentContext),
  ),

  "Padding": (j) => Padding(
    padding: EdgeInsets.all((j["padding"] as num?)?.toDouble() ?? 0),
    child: RemUI.buildWidget(j["child"]),
  ),

  "Column": (j) => Column(
    mainAxisAlignment: Resolv.resolvMainAxis(
      j["mainAxis"] ?? j["mainAxisAlignment"],
    ),
    crossAxisAlignment: Resolv.resolveCrossAxis(
      j["crossAxis"] ?? j["crossAxisAlignment"],
      fallback: CrossAxisAlignment.start,
    ),
    children: (j["children"] as List? ?? [])
        .map((c) => RemUI.buildWidget(c))
        .toList(),
  ),

  "Row": (j) => Row(
    mainAxisAlignment: Resolv.resolvMainAxis(
      j["mainAxis"] ?? j["mainAxisAlignment"],
    ),
    crossAxisAlignment: Resolv.resolveCrossAxis(
      j["crossAxis"] ?? j["crossAxisAlignment"],
      fallback: CrossAxisAlignment.center,
    ),
    children: (j["children"] as List? ?? [])
        .map((c) => RemUI.buildWidget(c))
        .toList(),
  ),

  "KiwiPlusMinus": (j) => ValueListenableBuilder<int>(
    valueListenable: RemUI.variableTick,
    builder: (context, _, __) {
      final variableName = j["variable"]?.toString().trim();
      final min = (j["min"] as num?)?.toDouble();
      final max = (j["max"] as num?)?.toDouble();
      final step = (j["step"] as num?)?.toDouble() ?? 1.0;
      dynamic fromVar;
      if (variableName != null && variableName.isNotEmpty) {
        if (!variableName.contains('.')) {
          fromVar = RemUI.getVar(variableName);
        } else {
          final parts = variableName
              .split('.')
              .where((part) => part.trim().isNotEmpty)
              .toList();
          if (parts.isNotEmpty) {
            final root = parts.first;
            final path = parts.sublist(1).join('.');
            dynamic rootVal = RemUI.getVar(root);

            if (rootVal is String) {
              try {
                final decoded = jsonDecode(rootVal);
                rootVal = decoded;
              } catch (_) {
                rootVal = null;
              }
            }

            fromVar = path.isEmpty ? rootVal : _valueAtPath(rootVal, path);

            if (fromVar is String) {
              final text = fromVar.trim();
              if (text.startsWith('{') || text.startsWith('[')) {
                try {
                  fromVar = jsonDecode(text);
                } catch (_) {}
              }
            }
          }
        }
      }

      double current;
      if (fromVar is num) {
        current = fromVar.toDouble();
      } else {
        current =
            double.tryParse(fromVar?.toString() ?? '') ??
            (j["value"] is num ? (j["value"] as num).toDouble() : 0.0);
      }

      Color? minusColor = Resolv.color(
        j["colorMinus"] ?? j["minusColor"],
        context: RemUI.currentContext,
      );
      Color? plusColor = Resolv.color(
        j["colorPlus"] ?? j["plusColor"],
        context: RemUI.currentContext,
      );

      void applyNew(double nextVal) {
        var out;
        // prefer integer when inputs are whole numbers
        if (nextVal == nextVal.roundToDouble()) {
          out = nextVal.toInt();
        } else {
          out = nextVal;
        }

        if (variableName != null && variableName.isNotEmpty) {
          // support dotted paths (e.g., "test.var") where the root may be a
          // Map or a JSON-encoded string. In that case, update the nested
          // property and write back the root variable preserving its original
          // string/map shape.
          if (variableName.contains('.')) {
            final parts = variableName.split('.');
            final root = parts.first;
            final path = parts.sublist(1);
            dynamic rootVal = RemUI.getVar(root);
            bool wasString = false;
            Map<String, dynamic> targetMap = {};

            if (rootVal is String) {
              try {
                final decoded = jsonDecode(rootVal);
                if (decoded is Map) {
                  targetMap = Map<String, dynamic>.from(decoded);
                } else {
                  // non-object JSON, fallback to empty map
                  targetMap = {};
                }
              } catch (_) {
                // not JSON, start fresh
                targetMap = {};
              }
              wasString = true;
            } else if (rootVal is Map) {
              targetMap = Map<String, dynamic>.from(rootVal);
            } else if (rootVal == null) {
              targetMap = {};
            } else {
              // unsupported root type, overwrite with map
              targetMap = {};
            }

            // walk path and set value
            Map<String, dynamic> cursor = targetMap;
            for (var i = 0; i < path.length; i++) {
              final key = path[i];
              final isLast = i == path.length - 1;
              if (isLast) {
                cursor[key] = out;
              } else {
                final next = cursor[key];
                if (next is Map) {
                  cursor = next as Map<String, dynamic>;
                } else if (next is String) {
                  try {
                    final decoded = jsonDecode(next);
                    if (decoded is Map) {
                      cursor[key] = Map<String, dynamic>.from(decoded);
                      cursor = cursor[key] as Map<String, dynamic>;
                    } else {
                      final newMap = <String, dynamic>{};
                      cursor[key] = newMap;
                      cursor = newMap;
                    }
                  } catch (_) {
                    final newMap = <String, dynamic>{};
                    cursor[key] = newMap;
                    cursor = newMap;
                  }
                } else {
                  final newMap = <String, dynamic>{};
                  cursor[key] = newMap;
                  cursor = newMap;
                }
              }
            }

            if (wasString) {
              RemUI.setVar(root, jsonEncode(targetMap));
            } else {
              RemUI.setVar(root, targetMap);
            }
          } else {
            RemUI.setVar(variableName, out);
          }
        }

        if (j["onChange"] != null) {
          handleClick({"action": j["onChange"]});
        } else if (j["action"] != null ||
            j["onClick"] != null ||
            j["onPressed"] != null) {
          handleClick(j);
        }
      }

      final canDec = min == null ? true : current - step >= min - 1e-9;
      final canInc = max == null ? true : current + step <= max + 1e-9;

      final minusBtn = InkWell(
        onTap: canDec
            ? () => applyNew(
                (current - step).clamp(
                  min ?? double.negativeInfinity,
                  max ?? double.infinity,
                ),
              )
            : null,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: minusColor ?? Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.remove, color: Colors.white),
        ),
      );

      final plusBtn = InkWell(
        onTap: canInc
            ? () => applyNew(
                (current + step).clamp(
                  min ?? double.negativeInfinity,
                  max ?? double.infinity,
                ),
              )
            : null,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: plusColor ?? Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.add, color: Colors.white),
        ),
      );

      final display = Text(
        (current == current.roundToDouble())
            ? current.toInt().toString()
            : current.toString(),
        style: TextStyle(fontSize: (j["fontSize"] as num?)?.toDouble() ?? 16),
      );

      final spacing = (j["spacing"] as num?)?.toDouble() ?? 12.0;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          minusBtn,
          SizedBox(width: spacing),
          display,
          SizedBox(width: spacing),
          plusBtn,
        ],
      );
    },
  ),

  "SingleChildScrollView": (j) =>
      SingleChildScrollView(child: RemUI.buildWidget(j["child"])),
  "Scaffold": (j) => Scaffold(
    appBar: j["appBar"] != null
        ? RemUI.buildWidget(j["appBar"]) as PreferredSizeWidget?
        : null,
    bottomNavigationBar: j["bottomNavigationBar"] != null
        ? RemUI.buildWidget(j["bottomNavigationBar"])
        : null,
    drawer: j["drawer"] != null ? RemUI.buildWidget(j["drawer"]) : null,
    floatingActionButton: j["floatingActionButton"] != null
        ? RemUI.buildWidget(j["floatingActionButton"])
        : null,
    body: RemUI.buildWidget(j["body"]),
  ),

  "Dialog": (j) {
    final rawActions = j["actions"];
    final actions = rawActions is List
        ? rawActions
              .whereType<Map<String, dynamic>>()
              .map((action) => RemUI.buildWidget(action))
              .toList()
        : <Widget>[];
    final body = j["body"] != null
        ? RemUI.buildWidget(j["body"])
        : (j["child"] != null
              ? RemUI.buildWidget(j["child"])
              : const SizedBox());

    return AlertDialog(
      title: j["title"] is Map<String, dynamic>
          ? RemUI.buildWidget(j["title"])
          : (j["title"] != null ? Text(j["title"].toString()) : null),
      content: body,
      actions: actions,
      backgroundColor: Resolv.color(
        j["backgroundColor"],
        context: RemUI.currentContext,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          (j["borderRadius"] as num?)?.toDouble() ?? 24,
        ),
      ),
    );
  },

  "GridView": (j) => SizedBox(
    width: j["width"] != null ? (j["width"] as num).toDouble() : null,
    height: j["height"] != null ? (j["height"] as num).toDouble() : null,
    child: GridView.count(
      crossAxisCount: j["crossAxisCount"] ?? 2,
      shrinkWrap: j["shrinkWrap"] ?? false,
      scrollDirection: j["scrollDirection"] == "horizontal"
          ? Axis.horizontal
          : Axis.vertical,
      physics: j["physics"] == "neverScrollable"
          ? const NeverScrollableScrollPhysics()
          : null,
      mainAxisSpacing: (j["mainAxisSpacing"] as num?)?.toDouble() ?? 0,
      crossAxisSpacing: (j["crossAxisSpacing"] as num?)?.toDouble() ?? 0,
      childAspectRatio: (j["childAspectRatio"] as num?)?.toDouble() ?? 1,
      children: (j["children"] as List? ?? [])
          .map((c) => RemUI.buildWidget(c))
          .toList(),
    ),
  ),

  "Card": (j) => Card(
    color: Resolv.color(j["color"], context: RemUI.currentContext),
    child: RemUI.buildWidget(j["child"]),
  ),

  "Table": (j) => Table(
    border: j["border"] != null
        ? TableBorder.all(
            color:
                Resolv.color(j["borderColor"], context: RemUI.currentContext) ??
                Colors.black,
          )
        : null,
    children: (j["rows"] as List? ?? [])
        .whereType<List>()
        .map(
          (row) => TableRow(
            children: row.map((cell) => RemUI.buildWidget(cell)).toList(),
          ),
        )
        .toList(),
  ),

  "Expanded": (j) => Expanded(
    flex: j["flex"] as int? ?? 1,
    child: RemUI.buildWidget(j["child"]),
  ),

  "Flex": (j) => Flex(
    direction: j["direction"] == "vertical" ? Axis.vertical : Axis.horizontal,
    mainAxisAlignment: Resolv.resolvMainAxis(
      j["mainAxis"] ?? j["mainAxisAlignment"],
    ),
    crossAxisAlignment: Resolv.resolveCrossAxis(
      j["crossAxis"] ?? j["crossAxisAlignment"],
      fallback: CrossAxisAlignment.start,
    ),
    children: (j["children"] as List? ?? [])
        .map((c) => RemUI.buildWidget(c))
        .toList(),
  ),

  "Carousel": (j) => _CarouselWidget(json: j),

  "GestureDetector": (j) => GestureDetector(
    onTap: () => handleClick(j),
    child: RemUI.buildWidget(j["child"]),
  ),

  "Container": (j) => Container(
    width: (j["width"] as num?)?.toDouble(),
    height: (j["height"] as num?)?.toDouble(),
    decoration: BoxDecoration(
      image: j["backgroundImage"] != null
          ? DecorationImage(
              image: NetworkImage(j["backgroundImage"]),
              fit: BoxFit.cover,
            )
          : null,
      color: Resolv.color(j["color"], context: RemUI.currentContext),
      border: j["borderColor"] != null
          ? Border.all(
              color:
                  Resolv.color(
                    j["borderColor"],
                    context: RemUI.currentContext,
                  ) ??
                  Colors.black,
              width: (j["borderWidth"] as num?)?.toDouble() ?? 1,
            )
          : null,
      borderRadius: j["borderRadius"] != null
          ? BorderRadius.circular((j["borderRadius"] as num).toDouble())
          : null,
    ),
    child: RemUI.buildWidget(j["child"]),
  ),

  "ListTile": (j) => ListTile(
    leading: j["leading"] is Map<String, dynamic>
        ? RemUI.buildWidget(j["leading"])
        : null,
    title: j["title"] is Map<String, dynamic>
        ? RemUI.buildWidget(j["title"])
        : (j["title"] != null ? Text(j["title"].toString()) : null),
    subtitle: j["subtitle"] is Map<String, dynamic>
        ? RemUI.buildWidget(j["subtitle"])
        : (j["subtitle"] != null ? Text(j["subtitle"].toString()) : null),
    trailing: j["trailing"] is Map<String, dynamic>
        ? RemUI.buildWidget(j["trailing"])
        : null,
    onTap: () => handleClick(j),
  ),

  "SizedBox": (j) => SizedBox(
    width: (j["width"] as num?)?.toDouble(),
    height: j['height'] == "mediaQuery"
        ? MediaQuery.of(RemUI.currentContext).size.height
        : (j["height"] as num?)?.toDouble(),
    child: RemUI.buildWidget(j["child"]),
  ),

  "Stack": (j) => Stack(
    alignment: Resolv.resolveAlignment(j["alignment"]) ?? Alignment.topLeft,
    children: (j["children"] as List? ?? [])
        .map((c) => RemUI.buildWidget(c))
        .toList(),
  ),

  "HorizontalScroll": (j) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: RemUI.buildWidget(j["child"]),
  ),

  "InkWell": (j) => InkWell(
    onTap: () => handleClick(j),
    child: RemUI.buildWidget(j["child"]),
  ),

  "Badge": (j) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color:
          Resolv.color(j["color"], context: RemUI.currentContext) ??
          Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      j["label"]?.toString() ?? '',
      style: TextStyle(
        fontSize: (j["fontSize"] as num?)?.toDouble() ?? 11,
        fontWeight: FontWeight.w700,
        color:
            Resolv.color(j["labelColor"], context: RemUI.currentContext) ??
            Colors.black,
      ),
    ),
  ),

  "Divider": (j) => Divider(
    thickness: (j["thickness"] as num?)?.toDouble() ?? 1,
    color: Resolv.color(j["color"], context: RemUI.currentContext),
  ),

  "SidebarWithUI": (j) {
    final sidebar = RemUI.buildWidget(j["sidebar"]);
    final child = RemUI.buildWidget(j["child"]);
    final dividerColor =
        Resolv.color(j["dividerColor"], context: RemUI.currentContext) ??
        const Color(0x1A000000);
    final contentPadding = (j["contentPadding"] as num?)?.toDouble() ?? 0;

    return Container(
      color: Resolv.color(j["backgroundColor"], context: RemUI.currentContext),
      child: Row(
        children: [
          sidebar,
          if (j["showDivider"] != false)
            Container(width: 1, color: dividerColor),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(contentPadding),
              child: child,
            ),
          ),
        ],
      ),
    );
  },

  // Styled sidebar with header, active states, badges, and optional footer.
  "Sidebar": (j) {
    final width = j["width"] != null ? (j["width"] as num).toDouble() : 272.0;

    return ValueListenableBuilder<int>(
      valueListenable: RemUI.variableTick,
      builder: (context, _, __) {
        final items = (j["items"] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final trackedVariableName = _resolveSidebarVariableName(j, items);

        final initialIndex = _resolveNavigationIndex(j["currentIndex"]) ?? 0;
        final fromVar = _resolveSidebarSelectedIndex(
          items,
          trackedVariableName,
        );
        final selectedIndex = items.isEmpty
            ? -1
            : ((fromVar ?? initialIndex).clamp(0, items.length - 1) as int);

        final bgColor =
            Resolv.color(j["color"], context: RemUI.currentContext) ??
            const Color(0xFFF8FAFF);
        final accentColor =
            Resolv.color(j["accentColor"], context: RemUI.currentContext) ??
            const Color(0xFF2454FF);
        final textColor =
            Resolv.color(j["textColor"], context: RemUI.currentContext) ??
            const Color(0xFF1A1F36);
        final subtitleColor =
            Resolv.color(j["subtitleColor"], context: RemUI.currentContext) ??
            const Color(0xFF6B7280);
        final borderColor =
            Resolv.color(j["borderColor"], context: RemUI.currentContext) ??
            subtitleColor.withValues(alpha: 0.18);
        final selectedLabelColor =
            Resolv.color(
              j["selectedLabelColor"],
              context: RemUI.currentContext,
            ) ??
            Colors.white;
        final unselectedItemColor =
            Resolv.color(j["itemColor"], context: RemUI.currentContext) ??
            Colors.white.withValues(alpha: 0.55);
        final selectedGradientStart =
            Resolv.color(
              j["selectedGradientStart"],
              context: RemUI.currentContext,
            ) ??
            accentColor;
        final selectedGradientEnd =
            Resolv.color(
              j["selectedGradientEnd"],
              context: RemUI.currentContext,
            ) ??
            accentColor.withValues(alpha: 0.82);
        final headerTitle = j["title"]?.toString() ?? 'Navigation';
        final headerSubtitle = j["subtitle"]?.toString();
        final showChevron = j["showChevron"] != false;
        final showHeader = j["showHeader"] != false;
        final showDivider = j["showDivider"] != false;
        final headerPadding = (j["headerPadding"] as num?)?.toDouble() ?? 16;
        final itemSpacing = (j["itemSpacing"] as num?)?.toDouble() ?? 8;
        final itemRadius = (j["itemRadius"] as num?)?.toDouble() ?? 14;
        final itemPaddingX = (j["itemPaddingX"] as num?)?.toDouble() ?? 12;
        final itemPaddingY = (j["itemPaddingY"] as num?)?.toDouble() ?? 11;
        final iconBoxSize = (j["iconBoxSize"] as num?)?.toDouble() ?? 34;
        final iconRadius = (j["iconRadius"] as num?)?.toDouble() ?? 10;
        final iconSize = (j["iconSize"] as num?)?.toDouble() ?? 20;
        final headerWidget = j["header"] is Map<String, dynamic>
            ? RemUI.buildWidget(j["header"])
            : null;

        Widget buildIcon(Map<String, dynamic> item, bool selected) {
          final iconValue = item["icon"];
          final iconColor =
              Resolv.color(item["iconColor"], context: RemUI.currentContext) ??
              (selected ? Colors.white : accentColor);

          if (iconValue is Map<String, dynamic>) {
            return RemUI.buildWidget(iconValue);
          }

          final iconData = Resolv.icon(iconValue) ?? Icons.circle_outlined;
          return Icon(iconData, size: iconSize, color: iconColor);
        }

        Widget? buildTrailing(Map<String, dynamic> item, bool selected) {
          if (item["trailing"] is Map<String, dynamic>) {
            return RemUI.buildWidget(item["trailing"]);
          }

          final badge = item["badge"];
          if (badge != null) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.24)
                    : accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : accentColor,
                ),
              ),
            );
          }

          if (showChevron) {
            return Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: selected
                  ? Colors.white.withValues(alpha: 0.92)
                  : subtitleColor,
            );
          }

          return null;
        }

        return Container(
          width: width,
          decoration: BoxDecoration(
            color: bgColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                if (showHeader)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      headerPadding,
                      headerPadding,
                      headerPadding,
                      12,
                    ),
                    child:
                        headerWidget ??
                        Row(
                          children: [
                            CircleAvatar(
                              radius:
                                  (j["headerAvatarRadius"] as num?)
                                      ?.toDouble() ??
                                  20,
                              backgroundColor: accentColor.withValues(
                                alpha: 0.14,
                              ),
                              child: Icon(
                                Resolv.icon(j["headerIcon"]) ??
                                    Icons.dashboard_rounded,
                                color: accentColor,
                                size:
                                    (j["headerIconSize"] as num?)?.toDouble() ??
                                    22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    headerTitle,
                                    style: TextStyle(
                                      fontSize:
                                          (j["titleSize"] as num?)
                                              ?.toDouble() ??
                                          16,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                  if (headerSubtitle != null &&
                                      headerSubtitle.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        headerSubtitle,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: subtitleColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  ),
                if (showHeader && showDivider)
                  Divider(
                    height: 1,
                    color: subtitleColor.withValues(alpha: 0.18),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: (j["listPaddingX"] as num?)?.toDouble() ?? 12,
                      vertical: (j["listPaddingY"] as num?)?.toDouble() ?? 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final selected = index == selectedIndex;
                      final hasAction =
                          item["action"] != null ||
                          item["onClick"] != null ||
                          item["onPressed"] != null ||
                          item["setVar"] != null;

                      final label = item["label"]?.toString() ?? 'Item';
                      final subtitle = item["subtitle"]?.toString();
                      final trailing = buildTrailing(item, selected);
                      final perItemRadius =
                          (item["itemRadius"] as num?)?.toDouble() ??
                          itemRadius;

                      return Padding(
                        padding: EdgeInsets.only(bottom: itemSpacing),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(perItemRadius),
                            onTap: () async {
                              if (trackedVariableName != null &&
                                  trackedVariableName.isNotEmpty) {
                                RemUI.setVar(
                                  trackedVariableName,
                                  index.toString(),
                                );
                              }

                              if (hasAction) {
                                await handleClick(item);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              padding: EdgeInsets.symmetric(
                                horizontal: itemPaddingX,
                                vertical: itemPaddingY,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  perItemRadius,
                                ),
                                gradient: selected
                                    ? LinearGradient(
                                        colors: [
                                          Resolv.color(
                                                item["selectedGradientStart"],
                                                context: RemUI.currentContext,
                                              ) ??
                                              selectedGradientStart,
                                          Resolv.color(
                                                item["selectedGradientEnd"],
                                                context: RemUI.currentContext,
                                              ) ??
                                              selectedGradientEnd,
                                        ],
                                      )
                                    : null,
                                color: selected
                                    ? null
                                    : (Resolv.color(
                                            item["color"],
                                            context: RemUI.currentContext,
                                          ) ??
                                          unselectedItemColor),
                                border: Border.all(
                                  color: selected
                                      ? Colors.transparent
                                      : borderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: iconBoxSize,
                                    height: iconBoxSize,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.white.withValues(alpha: 0.2)
                                          : accentColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(
                                        iconRadius,
                                      ),
                                    ),
                                    child: Center(
                                      child: buildIcon(item, selected),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: selected
                                                ? selectedLabelColor
                                                : (Resolv.color(
                                                        item["labelColor"],
                                                        context: RemUI
                                                            .currentContext,
                                                      ) ??
                                                      textColor),
                                          ),
                                        ),
                                        if (subtitle != null &&
                                            subtitle.trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 1,
                                            ),
                                            child: Text(
                                              subtitle,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: selected
                                                    ? selectedLabelColor
                                                          .withValues(
                                                            alpha: 0.9,
                                                          )
                                                    : (Resolv.color(
                                                            item["subtitleColor"],
                                                            context: RemUI
                                                                .currentContext,
                                                          ) ??
                                                          subtitleColor),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (trailing != null) ...[
                                    const SizedBox(width: 8),
                                    trailing,
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (j["footer"] != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      (j["footerPaddingX"] as num?)?.toDouble() ?? 12,
                      0,
                      (j["footerPaddingX"] as num?)?.toDouble() ?? 12,
                      (j["footerPaddingBottom"] as num?)?.toDouble() ?? 12,
                    ),
                    child: j["footer"] is Map<String, dynamic>
                        ? RemUI.buildWidget(j["footer"])
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: subtitleColor.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              j["footer"].toString(),
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  },

  "NavigationRail": (j) {
    return _NavigationRailShell(json: j);
  },

  "Image": (j) {
    final src = j["src"];
    if (src == null) return const SizedBox();
    final width = (j["width"] as num?)?.toDouble();
    final height = (j["height"] as num?)?.toDouble();
    if (src.startsWith("http")) {
      return Image.network(
        src,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
        ),
        color: Resolv.color(j["color"], context: RemUI.currentContext),
        scale: j["scale"] != null ? (j["scale"] as num).toDouble() : 1.0,
        fit: j["fit"] != null
            ? BoxFit.values.firstWhere(
                (e) => e.toString() == 'BoxFit.${j["fit"]}',
                orElse: () => BoxFit.contain,
              )
            : null,
      );
    } else {
      return Image.asset(
        src,
        width: width,
        height: height,
        color: Resolv.color(j["color"], context: RemUI.currentContext),
        scale: j["scale"] != null ? (j["scale"] as num).toDouble() : 1.0,
        fit: j["fit"] != null
            ? BoxFit.values.firstWhere(
                (e) => e.toString() == 'BoxFit.${j["fit"]}',
                orElse: () => BoxFit.contain,
              )
            : null,
      );
    }
  },

  ..._buttonWidgetsRegistry,

  ..._remCompWidgetsRegistry,

  ..._controlWidgetsRegistry,

  ..._tabsRadioWidgetsRegistry,
};

int? _resolveNavigationIndex(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString().trim());
}

NavigationRailLabelType? _resolveRailLabelType(dynamic value) {
  final raw = value?.toString().toLowerCase().trim();
  switch (raw) {
    case 'none':
      return NavigationRailLabelType.none;
    case 'selected':
      return NavigationRailLabelType.selected;
    case 'all':
      return NavigationRailLabelType.all;
    default:
      return null;
  }
}

Widget _buildNavigationRailIcon(dynamic rawIcon, {required IconData fallback}) {
  if (rawIcon is Map<String, dynamic>) {
    return RemUI.buildWidget(rawIcon);
  }

  return Icon(Resolv.icon(rawIcon) ?? fallback);
}

String? _resolveSidebarVariableName(
  Map<String, dynamic> sidebar,
  List<Map<String, dynamic>> items,
) {
  final explicit = sidebar["variable"]?.toString().trim();
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }

  for (final item in items) {
    final candidate = _resolveSetVarFromItem(item)?.name;
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
  }

  return null;
}

int? _resolveSidebarSelectedIndex(
  List<Map<String, dynamic>> items,
  String? variableName,
) {
  if (variableName == null || variableName.isEmpty) {
    return null;
  }

  final currentValue = RemUI.getVar(variableName);
  final directIndex = _resolveNavigationIndex(currentValue);
  if (directIndex != null) {
    return directIndex;
  }

  if (currentValue == null) {
    return null;
  }

  final currentText = currentValue.toString();
  for (var i = 0; i < items.length; i++) {
    final setVar = _resolveSetVarFromItem(items[i]);
    if (setVar == null || setVar.name != variableName) {
      continue;
    }

    if (setVar.value?.toString() == currentText) {
      return i;
    }
  }

  return null;
}

({String name, dynamic value})? _resolveSetVarFromItem(
  Map<String, dynamic> item,
) {
  final direct = _resolveSetVarPayload(item["setVar"]);
  if (direct != null) {
    return direct;
  }

  final action = item["action"] ?? item["onClick"] ?? item["onPressed"];

  if (action is String && action.startsWith("setVar:")) {
    return _resolveSetVarPayload(action.substring("setVar:".length));
  }

  if (action is Map) {
    final normalized = action.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    if (normalized["type"]?.toString() == "setVar") {
      return _resolveSetVarPayload(normalized);
    }

    if (normalized.containsKey("setVar")) {
      return _resolveSetVarPayload(normalized["setVar"]);
    }
  }

  return null;
}

({String name, dynamic value})? _resolveSetVarPayload(dynamic payload) {
  if (payload is Map) {
    final normalized = payload.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final name =
        normalized["var"]?.toString() ?? normalized["name"]?.toString();
    if (name == null || name.trim().isEmpty) {
      return null;
    }
    return (name: name.trim(), value: normalized["value"]);
  }

  if (payload is String) {
    final separator = payload.indexOf("=");
    if (separator <= 0) {
      return null;
    }
    final name = payload.substring(0, separator).trim();
    if (name.isEmpty) {
      return null;
    }
    final value = payload.substring(separator + 1);
    return (name: name, value: value);
  }

  return null;
}

String _resolveTemplateText(String input) {
  if (!input.contains('{')) {
    return input;
  }

  return input.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (match) {
    final key = (match.group(1) ?? '').trim();
    if (key.isEmpty) {
      return 'unknown';
    }

    final value = RemUI.getVar(key);
    if (value == null) {
      return 'unknown';
    }

    if (value is List) {
      return value.map((item) => item.toString()).join(', ');
    }

    return value.toString();
  });
}

Widget? _renderConditionNode(Map<String, dynamic> node) {
  final varName = node["var"]?.toString() ?? "";
  final expected = node["eq"]?.toString();
  final actual = RemUI.getVar(varName);
  final matches = actual?.toString() == expected;

  if (matches) {
    return RemUI.buildWidget(_conditionChild(node));
  }

  final elseIf = node["elseIf"];
  if (elseIf is Map<String, dynamic>) {
    return _renderConditionNode(elseIf);
  }

  if (elseIf is List) {
    for (final branch in elseIf) {
      if (branch is Map<String, dynamic>) {
        final rendered = _renderConditionNode(branch);
        if (rendered != null) {
          return rendered;
        }
      }
    }
  }

  return const SizedBox.shrink();
}

Map<String, dynamic>? _conditionChild(Map<String, dynamic> node) {
  if (node["child"] is Map<String, dynamic>) {
    return node["child"] as Map<String, dynamic>;
  }

  final children = node["children"];
  if (children is List &&
      children.isNotEmpty &&
      children.first is Map<String, dynamic>) {
    return children.first as Map<String, dynamic>;
  }

  return null;
}

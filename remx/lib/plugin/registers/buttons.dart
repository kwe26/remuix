part of '../registers.dart';

final Map<String, Widget Function(Map<String, dynamic>)>
_buttonWidgetsRegistry = {
  "IconButton": (j) => IconButton(
    icon: RemUI.buildWidget(j["icon"]),
    onPressed: () => handleClick(j),
  ),

  "ElevatedButton": (j) => ElevatedButton(
    onPressed: () => handleClick(j),
    style: ElevatedButton.styleFrom(
      backgroundColor: Resolv.color(j["color"], context: RemUI.currentContext),
    ),
    child: RemUI.buildWidget(j["child"]),
  ),

  "FilledButton": (j) => FilledButton(
    onPressed: () => handleClick(j),
    style: FilledButton.styleFrom(
      backgroundColor: Resolv.color(j["color"], context: RemUI.currentContext),
    ),
    child: RemUI.buildWidget(j["child"]),
  ),

  "TextButton": (j) => TextButton(
    onPressed: () => handleClick(j),
    style: TextButton.styleFrom(
      foregroundColor: Resolv.color(j["color"], context: RemUI.currentContext),
    ),
    child: RemUI.buildWidget(j["child"]),
  ),

  "OutlinedButton": (j) => OutlinedButton(
    onPressed: () => handleClick(j),
    style: OutlinedButton.styleFrom(
      side: BorderSide(
        color:
            Resolv.color(j["color"], context: RemUI.currentContext) ??
            Colors.blue,
      ),
    ),
    child: RemUI.buildWidget(j["child"]),
  ),

  "BottomNavigationBar": (j) {
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
        final resolvedIndex = itemCount == 0
            ? 0
            : ((fromVar ?? initialIndex).clamp(0, itemCount - 1) as int);

        return BottomNavigationBar(
          items: items
              .map(
                (item) => BottomNavigationBarItem(
                  icon: RemUI.buildWidget(item["icon"]),
                  label: item["label"]?.toString() ?? '',
                ),
              )
              .toList(),
          currentIndex: resolvedIndex,
          onTap: (index) async {
            if (index < 0 || index >= items.length) {
              return;
            }

            final tappedItem = items[index];
            final hasAction =
                tappedItem["action"] != null ||
                tappedItem["onClick"] != null ||
                tappedItem["onPressed"] != null ||
                tappedItem["setVar"] != null;

            if (!hasAction && variableName != null && variableName.isNotEmpty) {
              RemUI.setVar(variableName, index.toString());
              return;
            }

            await handleClick(tappedItem);
          },
        );
      },
    );
  },
};

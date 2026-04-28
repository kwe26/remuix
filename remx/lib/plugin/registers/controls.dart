part of '../registers.dart';

class _DatePickerField extends StatefulWidget {
  final Map<String, dynamic> json;

  const _DatePickerField({required this.json});

  @override
  State<_DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<_DatePickerField> {
  String _resolveMode() {
    final raw = widget.json["mode"]?.toString().toLowerCase().trim() ?? "both";
    switch (raw) {
      case "date-only":
      case "date":
        return "date";
      case "time-only":
      case "time":
        return "time";
      default:
        return "both";
    }
  }

  Future<void> _pick() async {
    final variableName = widget.json["variable"]?.toString().trim();
    if (variableName == null || variableName.isEmpty) {
      return;
    }

    final mode = _resolveMode();
    final now = DateTime.now();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    if (mode == "date" || mode == "both") {
      selectedDate = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200),
      );

      if (selectedDate == null) {
        return;
      }
    }

    if (mode == "time" || mode == "both") {
      selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (selectedTime == null) {
        return;
      }
    }

    String value;
    if (mode == "date") {
      value = _formatDate(selectedDate!);
    } else if (mode == "time") {
      value = _formatTime(selectedTime!);
    } else {
      final merged = DateTime(
        selectedDate!.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime!.hour,
        selectedTime.minute,
      );
      value = merged.toIso8601String();
    }

    RemUI.setVar(variableName, value);

    final hasAction =
        widget.json["action"] != null ||
        widget.json["onClick"] != null ||
        widget.json["onPressed"] != null;
    if (hasAction) {
      await handleClick(widget.json);
    }
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _formatTime(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RemUI.variableTick,
      builder: (context, _, __) {
        final variableName = widget.json["variable"]?.toString().trim();
        final value = variableName != null && variableName.isNotEmpty
            ? RemUI.getVar(variableName)
            : null;
        final labelText =
            widget.json["labelText"]?.toString() ??
            widget.json["label"]?.toString() ??
            "Date/Time";
        final hintText =
            widget.json["hintText"]?.toString() ??
            widget.json["hint"]?.toString() ??
            "Select value";

        final text = value?.toString().trim().isNotEmpty == true
            ? value.toString()
            : hintText;

        final content = InkWell(
          onTap: _pick,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: labelText,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_month),
            ),
            child: Text(text),
          ),
        );

        final width = (widget.json["width"] as num?)?.toDouble();
        if (width == null) {
          return content;
        }

        return SizedBox(width: width, child: content);
      },
    );
  }
}

class _TimeoutRunner extends StatefulWidget {
  final Map<String, dynamic> json;

  const _TimeoutRunner({required this.json});

  @override
  State<_TimeoutRunner> createState() => _TimeoutRunnerState();
}

class _TimeoutRunnerState extends State<_TimeoutRunner> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleIfNeeded();
  }

  void _scheduleIfNeeded() {
    if (_scheduled) {
      return;
    }
    _scheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final ms = _parseTimeoutMs(
        widget.json["timeout"] ?? widget.json["duration"] ?? widget.json["ms"],
      );
      if (ms > 0) {
        await Future<void>.delayed(Duration(milliseconds: ms));
      }
      if (!mounted) {
        return;
      }

      final payload = widget.json["data"];
      if (payload is List) {
        await RemUI.runCallbacks(payload);
        return;
      }
      if (payload is Map) {
        await RemUI.runCallbacks([
          payload.map((key, value) => MapEntry(key.toString(), value)),
        ]);
      }
    });
  }

  int _parseTimeoutMs(dynamic value) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }
    if (value is num) {
      final next = value.toInt();
      return next < 0 ? 0 : next;
    }

    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.json["child"] is Map<String, dynamic>) {
      return RemUI.buildWidget(widget.json["child"]);
    }
    return const SizedBox.shrink();
  }
}

final Map<String, Widget Function(Map<String, dynamic>)>
_controlWidgetsRegistry = {
  "Checkbox": (j) => ValueListenableBuilder<int>(
    valueListenable: RemUI.variableTick,
    builder: (context, _, __) {
      final variableName = j["variable"]?.toString().trim();
      final fromVar = variableName != null && variableName.isNotEmpty
          ? RemUI.getVar(variableName)
          : null;
      final checked = fromVar is bool
          ? fromVar
          : (fromVar?.toString().toLowerCase() == 'true');
      final activeColor = Resolv.color(
        j["activeColor"],
        context: RemUI.currentContext,
      );
      final title = j["label"]?.toString();
      final subtitle = j["subtitle"]?.toString();

      Future<void> update(bool? value) async {
        final next = value == true;
        if (variableName != null && variableName.isNotEmpty) {
          RemUI.setVar(variableName, next);
        }

        final hasAction =
            j["action"] != null ||
            j["onClick"] != null ||
            j["onPressed"] != null;
        if (hasAction) {
          await handleClick(j);
        }
      }

      if (j["tile"] == false) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: checked,
              onChanged: update,
              activeColor: activeColor,
              tristate: j["tristate"] == true,
            ),
            if (title != null) Text(title),
          ],
        );
      }

      return CheckboxListTile(
        value: checked,
        onChanged: update,
        activeColor: activeColor,
        tristate: j["tristate"] == true,
        title: title != null ? Text(title) : null,
        subtitle: subtitle != null ? Text(subtitle) : null,
      );
    },
  ),

  "Slider": (j) => ValueListenableBuilder<int>(
    valueListenable: RemUI.variableTick,
    builder: (context, _, __) {
      final variableName = j["variable"]?.toString().trim();
      final min = (j["min"] as num?)?.toDouble() ?? 0;
      final max = (j["max"] as num?)?.toDouble() ?? 100;
      final fromVar = variableName != null && variableName.isNotEmpty
          ? RemUI.getVar(variableName)
          : null;
      var value = (fromVar is num)
          ? fromVar.toDouble()
          : (double.tryParse(fromVar?.toString() ?? "") ??
                (j["value"] as num?)?.toDouble() ??
                min);
      value = value.clamp(min, max);
      final activeColor = Resolv.color(
        j["activeColor"],
        context: RemUI.currentContext,
      );
      final inactiveColor = Resolv.color(
        j["inactiveColor"],
        context: RemUI.currentContext,
      );

      final slider = Slider(
        min: min,
        max: max,
        divisions: (j["divisions"] as num?)?.toInt(),
        label: j["label"]?.toString() ?? value.toStringAsFixed(0),
        value: value,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        onChanged: (next) {
          if (variableName != null && variableName.isNotEmpty) {
            RemUI.setVar(variableName, next);
          }
        },
        onChangeEnd: (_) {
          final hasAction =
              j["action"] != null ||
              j["onClick"] != null ||
              j["onPressed"] != null;
          if (hasAction) {
            handleClick(j);
          }
        },
      );

      if (j["showValue"] == true) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (j["title"] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(j["title"].toString()),
              ),
            slider,
            Text(value.toStringAsFixed((j["precision"] as num?)?.toInt() ?? 0)),
          ],
        );
      }

      return slider;
    },
  ),

  "DatePicker": (j) => _DatePickerField(json: j),

  "Timeout": (j) => _TimeoutRunner(json: j),
};

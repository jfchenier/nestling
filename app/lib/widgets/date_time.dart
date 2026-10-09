import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';

/// Pick a day (not in the future), keeping the time of [initial].
Future<DateTime?> pickDate(BuildContext context, DateTime initial) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial.isAfter(now) ? now : initial,
    firstDate: DateTime(2000),
    lastDate: now,
  );
  if (date == null) return null;
  return DateTime(date.year, date.month, date.day, initial.hour, initial.minute);
}

/// Pick a time on the 24-hour dial (the keyboard icon switches to typing), keeping the day of [initial].
Future<DateTime?> pickTime(BuildContext context, DateTime initial) async {
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    initialEntryMode: TimePickerEntryMode.dial,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
  );
  if (time == null) return null;
  return DateTime(initial.year, initial.month, initial.day, time.hour, time.minute);
}

/// "Today  14:30" as two pills: tap the day to change the date, the time to change the time.
/// Without a [value], shows [placeholder] and starts from now.
class DateTimeValue extends StatelessWidget {
  const DateTimeValue({super.key, required this.value, required this.onChanged, this.placeholder = 'Add', this.enabled = true});
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String placeholder;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    Future<void> pick(Future<DateTime?> Function(BuildContext, DateTime) picker) async {
      final v = await picker(context, value ?? DateTime.now());
      if (v != null) onChanged(v);
    }

    Widget pill(String text, String semantics, VoidCallback onTap) => Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: c.raised,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              text,
              style: TextStyle(fontSize: 17, color: c.ink, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ),
      ),
    );

    final v = value;
    if (v == null) {
      return TextButton(
        onPressed: enabled ? () => pick(pickTime) : null,
        child: Text(placeholder, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill(dayLabel(v), 'Change day, ${dayLabel(v)}', () => pick(pickDate)),
        const SizedBox(width: 8),
        pill(timeOfDay(v), 'Change time, ${timeOfDay(v)}', () => pick(pickTime)),
      ],
    );
  }
}

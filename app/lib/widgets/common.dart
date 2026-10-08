import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../theme.dart';

/// Pastel circle with the activity's icon.
class KindBadge extends StatelessWidget {
  const KindBadge(this.kind, {super.key, this.size = 44});
  final Kind kind;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: kind.color, shape: BoxShape.circle),
    child: Icon(kind.icon, color: kind.deep, size: size * 0.5),
  );
}

/// Rebuilds its child every second (for running timers and "time since").
class Ticking extends StatefulWidget {
  const Ticking({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<Ticking> createState() => _TickingState();
}

class _TickingState extends State<Ticking> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: Palette.muted),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Runs [action], showing API errors as a snackbar. Returns null on failure.
Future<T?> guard<T>(BuildContext context, Future<T> Function() action) async {
  try {
    return await action();
  } on ApiException catch (e) {
    if (context.mounted) showMessage(context, e.message);
  } catch (e) {
    if (context.mounted) showMessage(context, 'Something went wrong: $e');
  }
  return null;
}

/// Max-width wrapper so the app looks like a phone app on wide browser windows.
class Constrained extends StatelessWidget {
  const Constrained({super.key, required this.child, this.maxWidth = 640});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String message, {String action = 'Delete'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          style: TextButton.styleFrom(foregroundColor: Palette.danger),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Row of selectable chips for one value.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({super.key, required this.options, required this.value, required this.onChanged, this.color});
  final Map<T, String> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final Color? color;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final e in options.entries)
        ChoiceChip(
          label: Text(e.value),
          selected: value == e.key,
          selectedColor: color ?? const Color(0xFFE6ECF3),
          showCheckmark: false,
          onSelected: (on) => onChanged(on ? e.key : null),
        ),
    ],
  );
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../theme.dart';

/// An organic pastel blob, seeded so each activity always gets the same shape.
class BlobPainter extends CustomPainter {
  BlobPainter(this.color, this.seed, {this.points = 7, this.wobble = 0.22});
  final Color color;
  final int seed;
  final int points;
  final double wobble;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final pts = [
      for (var i = 0; i < points; i++)
        () {
          final a = i / points * 2 * math.pi + rnd.nextDouble() * 0.4;
          final d = r * (1 - wobble + rnd.nextDouble() * wobble);
          return c + Offset(math.cos(a) * d, math.sin(a) * d);
        }(),
    ];
    final path = Path();
    Offset mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    path.moveTo(mid(pts.last, pts.first).dx, mid(pts.last, pts.first).dy);
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i], n = pts[(i + 1) % pts.length];
      final m = mid(p, n);
      path.quadraticBezierTo(p.dx, p.dy, m.dx, m.dy);
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(BlobPainter old) => old.color != color || old.seed != seed;
}

/// Seed that is the same on every platform and run (String.hashCode isn't guaranteed to be).
int stableSeed(String s) => s.codeUnits.fold(7, (a, c) => (a * 31 + c) & 0x7fffffff);

/// Filled icon on a solid circle in the activity's color.
class BlobIcon extends StatelessWidget {
  const BlobIcon(this.kind, {super.key, this.size = 56, this.icon});
  final Kind kind;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: kind.fill(c), shape: BoxShape.circle),
      child: Icon(icon ?? kind.icon, size: size * 0.5, color: kind.iconOn(c)),
    );
  }
}

/// Compact list badge (kept for small rows).
class KindBadge extends StatelessWidget {
  const KindBadge(this.kind, {super.key, this.size = 44});
  final Kind kind;
  final double size;

  @override
  Widget build(BuildContext context) => BlobIcon(kind, size: size);
}

/// The round blue "+" used on activity cards.
class PlusButton extends StatelessWidget {
  const PlusButton({super.key, required this.onTap, this.size = 46, this.tooltip});
  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? 'Add',
    child: Material(
      color: context.pal.accent,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.add_rounded, color: context.pal.onAccent, size: size * 0.6),
        ),
      ),
    ),
  );
}

/// Colored band at the top of an entry sheet: ✕ · serif title · Save.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, required this.color, this.onClose, this.onSave, this.saveLabel = 'Save'});
  final String title;
  final Color color;
  final VoidCallback? onClose;
  final VoidCallback? onSave;
  final String saveLabel;

  @override
  Widget build(BuildContext context) => Container(
    color: color,
    padding: EdgeInsets.fromLTRB(4, 10 + MediaQuery.paddingOf(context).top, 8, 10),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 28),
          color: context.pal.bandInk,
          tooltip: 'Close',
          onPressed: onClose ?? () => Navigator.maybePop(context),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: serifStyle(32, color: context.pal.bandInk),
          ),
        ),
        SizedBox(
          width: 72,
          child: TextButton(
            onPressed: onSave,
            style: TextButton.styleFrom(
              foregroundColor: context.pal.bandInk,
              disabledForegroundColor: context.pal.bandInk.withValues(alpha: 0.35),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            child: Text(saveLabel),
          ),
        ),
      ],
    ),
  );
}

/// A "Label ······ value" row with a divider underneath, as in Nara's forms.
class FormRow extends StatelessWidget {
  const FormRow({super.key, required this.label, this.value, this.child, this.onTap, this.below});
  final String label;
  final String? value;
  final Widget? child;
  final VoidCallback? onTap;

  /// Full-width content under the label (chips, pickers…).
  final Widget? below;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.pal.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: child ?? Text(value ?? '', style: TextStyle(fontSize: 17, color: context.pal.ink)),
                ),
              ),
            ],
          ),
          if (below != null) ...[const SizedBox(height: 14), below!],
        ],
      ),
    ),
  );
}

/// Right-aligned borderless number input for a [FormRow].
class InlineNumber extends StatelessWidget {
  const InlineNumber({super.key, required this.controller, this.unit, this.hint = '0', this.width = 120});
  final TextEditingController controller;
  final String? unit;
  final String hint;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 18),
      decoration: InputDecoration(
        hintText: hint,
        suffixText: unit,
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    ),
  );
}

/// Big round toggle (wet / dirty / dry).
class CircleToggle extends StatelessWidget {
  const CircleToggle({super.key, required this.label, required this.selected, required this.onTap, this.size = 84});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? context.pal.accent : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: context.pal.accent, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: selected ? context.pal.onAccent : context.pal.accent),
      ),
    ),
  );
}

/// Pill button with an outline (Start Left / Start Right…), filled when [active].
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onTap, this.active = false, this.color});
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pal.ink;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? c : Colors.transparent,
        foregroundColor: active ? context.pal.bandInk : context.pal.ink,
        side: BorderSide(color: active ? c : context.pal.ink, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        minimumSize: const Size(140, 54),
      ),
      child: Text(label),
    );
  }
}

/// Little drawn shapes for diaper textures.
class TexturePainter extends CustomPainter {
  TexturePainter(this.texture, this.color);
  final String texture;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final w = size.width, h = size.height;
    void blob(Offset c, double r, int seed, [double wobble = 0.25]) {
      canvas.save();
      canvas.translate(c.dx - r, c.dy - r);
      BlobPainter(color, seed, wobble: wobble).paint(canvas, Size(r * 2, r * 2));
      canvas.restore();
    }

    switch (texture) {
      case 'runny':
        blob(Offset(w * .45, h * .42), w * .3, 11, .45);
        canvas.drawCircle(Offset(w * .85, h * .62), w * .06, p);
        canvas.drawCircle(Offset(w * .2, h * .82), w * .05, p);
        canvas.drawCircle(Offset(w * .55, h * .86), w * .045, p);
      case 'mucousy':
        blob(Offset(w * .5, h * .35), w * .3, 12, .3);
        for (final (x, len) in [(.38, .45), (.5, .6), (.62, .4)]) {
          final r = RRect.fromLTRBR(w * x - w * .04, h * .4, w * x + w * .04, h * (.4 + len), Radius.circular(w * .04));
          canvas.drawRRect(r, p);
        }
      case 'mushy':
        blob(Offset(w * .5, h * .52), w * .4, 13, .2);
      case 'solid':
        final path = Path()
          ..moveTo(w * .1, h * .85)
          ..quadraticBezierTo(w * .1, h * .55, w * .3, h * .55)
          ..quadraticBezierTo(w * .32, h * .3, w * .5, h * .28)
          ..quadraticBezierTo(w * .55, h * .1, w * .62, h * .12)
          ..quadraticBezierTo(w * .7, h * .3, w * .72, h * .55)
          ..quadraticBezierTo(w * .92, h * .58, w * .9, h * .85)
          ..close();
        canvas.drawPath(path, p);
      default: // pebbles
        for (final (x, y, r) in [(.25, .3, .1), (.55, .35, .17), (.82, .5, .09), (.4, .72, .12), (.75, .8, .07)]) {
          canvas.drawCircle(Offset(w * x, h * y), w * r, p);
        }
    }
  }

  @override
  bool shouldRepaint(TexturePainter old) => old.texture != texture || old.color != color;
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
        Expanded(child: Text(text, style: serifStyle(22))),
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
          style: TextButton.styleFrom(foregroundColor: context.pal.danger),
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
          label: Text(e.value, style: TextStyle(color: value == e.key && color != null ? context.pal.bandInk : context.pal.ink)),
          selected: value == e.key,
          selectedColor: color ?? context.pal.accent,
          showCheckmark: false,
          onSelected: (on) => onChanged(on ? e.key : null),
        ),
    ],
  );
}

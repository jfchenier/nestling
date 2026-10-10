import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/date_time.dart';

/// One of the 20 baby teeth, by its usual letter (`A`–`J` upper, the baby's right to left;
/// `K`–`T` lower, the baby's left to right). [kind]: 1 central incisor … 5 second molar.
class BabyTooth {
  const BabyTooth(this.code, this.upper, this.right, this.kind);
  final String code;
  final bool upper, right;
  final int kind;

  static const _kinds = ['central incisor', 'lateral incisor', 'canine', 'first molar', 'second molar'];

  // When it usually comes in (months), per kind, upper and lower.
  static const _upperWhen = ['8–12', '9–13', '16–22', '13–19', '25–33'];
  static const _lowerWhen = ['6–10', '10–16', '17–23', '14–18', '23–31'];

  String get name => '${upper ? 'Upper' : 'Lower'} ${right ? 'right' : 'left'} ${_kinds[kind - 1]}';
  String get when => '${(upper ? _upperWhen : _lowerWhen)[kind - 1]} months';
}

/// All 20, A to T.
final babyTeeth = [
  for (var i = 0; i < 10; i++) BabyTooth(String.fromCharCode(65 + i), true, i < 5, i < 5 ? 5 - i : i - 4),
  for (var i = 0; i < 10; i++) BabyTooth(String.fromCharCode(75 + i), false, i >= 5, i < 5 ? 5 - i : i - 4),
];

BabyTooth? toothFor(String? code) => babyTeeth.where((t) => t.code == code).firstOrNull;

/// Where each tooth is drawn, as seen facing the baby (their right on the left): the upper arch
/// with the front teeth on top, the lower one under it with the front teeth at the bottom.
/// Centers and sizes in a [size] box.
List<(BabyTooth, Offset, double, double)> _layout(Size size) {
  final w = size.width, h = size.height;
  final rx = w * 0.36, ry = h * 0.25;
  // Half an ellipse sampled finely, so teeth can be spread by arc length (the sides of a wide
  // ellipse are short; equal angles would pile the big molars on top of each other).
  const n = 400;
  final pts = [for (var k = 0; k <= n; k++) math.pi - k * math.pi / n];
  final len = <double>[0];
  for (var k = 1; k <= n; k++) {
    final a0 = pts[k - 1], a1 = pts[k];
    len.add(len.last + Offset(rx * (math.cos(a1) - math.cos(a0)), ry * (math.sin(a1) - math.sin(a0))).distance);
  }
  final row = [for (var i = 0; i < 10; i++) babyTeeth.firstWhere((t) => t.upper && t.code.codeUnitAt(0) - 65 == i)];
  double span(BabyTooth t) => _toothSize(t, w).width;
  final total = row.fold(0.0, (sum, t) => sum + span(t));
  final out = <(BabyTooth, Offset, double, double)>[];
  for (final t in babyTeeth) {
    // Position along the arch, 0 = viewer's left, 9 = viewer's right.
    final i = t.upper ? t.code.codeUnitAt(0) - 65 : 9 - (t.code.codeUnitAt(0) - 75);
    final along = (row.take(i).fold(0.0, (sum, t) => sum + span(t)) + span(row[i]) / 2) / total * len.last;
    var k = 0;
    while (k < n && len[k + 1] < along) {
      k++;
    }
    final a = pts[k];
    final c = t.upper
        ? Offset(w / 2 + rx * math.cos(a), h * 0.44 - ry * math.sin(a))
        : Offset(w / 2 + rx * math.cos(a), h * 0.56 + ry * math.sin(a));
    // Turn each tooth to face the middle of the mouth (the ellipse's normal).
    final normal = math.atan2(ry * math.sin(a) / ry / ry, rx * math.cos(a) / rx / rx);
    final r = _radius(t, w);
    out.add((t, c, r, t.upper ? -normal + math.pi / 2 : normal - math.pi / 2));
  }
  return out;
}

double _radius(BabyTooth t, double w) => w * (0.03 + 0.0045 * t.kind);

/// A tooth's drawn size (incisors narrow and tall, canines and molars wide).
Size _toothSize(BabyTooth t, double w) {
  final r = _radius(t, w);
  return t.kind <= 2 ? Size(r * 1.5, r * 2.1) : Size(r * 2.0, r * 1.9);
}

/// The baby book's teeth chart: tap a tooth when it comes in. Each tooth is a milestone with a
/// `tooth` letter; the first one is the "First tooth" memory.
class TeethChart extends StatelessWidget {
  const TeethChart({super.key, required this.child, required this.milestones});
  final Child child;
  final List<Event> milestones;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final came = <String, Event>{};
    for (final e in milestones) {
      final code = e['tooth'] as String?;
      if (code != null && (came[code] == null || e.start.isBefore(came[code]!.start))) came[code] = e;
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: c.isDark ? null : Border.all(color: c.line),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: LayoutBuilder(
              builder: (context, box) {
                final size = Size(box.maxWidth, box.maxHeight);
                final layout = _layout(size);
                final readOnly = context.select<AppState, bool>((s) => s.bookOnly);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: readOnly
                      ? null
                      : (d) {
                          final hit = layout.where((l) => (l.$2 - d.localPosition).distance < l.$3 * 1.7).toList()
                            ..sort((a, b) => (a.$2 - d.localPosition).distance.compareTo((b.$2 - d.localPosition).distance));
                          if (hit.isNotEmpty) {
                            showToothSheet(context, child: child, tooth: hit.first.$1, milestones: milestones);
                          }
                        },
                  child: Semantics(
                    label: 'Teeth chart: ${came.length} of 20 teeth in.${readOnly ? '' : ' Tap a tooth to log it.'}',
                    child: CustomPaint(
                      size: size,
                      painter: _TeethPainter(layout, came.keys.toSet(), c, ink: c.ink, muted: c.muted),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_legend(context, true, 'In'), const SizedBox(width: 18), _legend(context, false, 'Not yet')],
          ),
          const SizedBox(height: 6),
          if (!context.select<AppState, bool>((s) => s.bookOnly))
          Text(
            came.isEmpty ? 'Tap a tooth when it comes in.' : 'Tap a tooth to log it or change its date.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, bool filled, String label) {
    final c = context.pal;
    final k = Kind.milestone;
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: filled ? k.fill(c) : c.raised,
            shape: BoxShape.circle,
            border: Border.all(color: filled ? k.on(c) : c.line, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: c.muted, fontSize: 13)),
      ],
    );
  }
}

class _TeethPainter extends CustomPainter {
  _TeethPainter(this.layout, this.came, this.c, {required this.ink, required this.muted});
  final List<(BabyTooth, Offset, double, double)> layout;
  final Set<String> came;
  final AppColors c;
  final Color ink, muted;

  @override
  void paint(Canvas canvas, Size size) {
    final k = Kind.milestone;
    // Gums: a soft band under each arch.
    final gum = Paint()
      ..color = k.fill(c).withValues(alpha: c.isDark ? 0.25 : 0.3)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.12;
    final w = size.width, h = size.height, rx = w * 0.36, ry = h * 0.25;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w / 2, h * 0.44), width: rx * 2, height: ry * 2),
      math.pi * 1.03,
      math.pi * 0.94,
      false,
      gum,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w / 2, h * 0.56), width: rx * 2, height: ry * 2),
      math.pi * 0.03,
      math.pi * 0.94,
      false,
      gum,
    );

    for (final (t, center, r, angle) in layout) {
      final inMouth = came.contains(t.code);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      // Incisors narrow, molars wide.
      final rect = Offset.zero - _toothSize(t, size.width).center(Offset.zero) & _toothSize(t, size.width);
      final shape = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.7));
      canvas.drawRRect(shape, Paint()..color = inMouth ? k.fill(c) : c.raised);
      canvas.drawRRect(
        shape,
        Paint()
          ..color = inMouth ? k.on(c) : c.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      canvas.restore();
    }

    void label(String text, Offset at) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    label('UPPER', Offset(w / 2, h * 0.36));
    label('LOWER', Offset(w / 2, h * 0.64));
    label('${came.length} of 20', Offset(w / 2, h * 0.5));
  }

  @override
  bool shouldRepaint(_TeethPainter old) => old.came.length != came.length || !old.came.containsAll(came) || old.c != c;
}

/// Log a tooth (when it came in), change its date, or take it back.
Future<void> showToothSheet(
  BuildContext context, {
  required Child child,
  required BabyTooth tooth,
  required List<Event> milestones,
}) => showModalBottomSheet(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: context.pal.background,
  builder: (_) => _ToothSheet(child: child, tooth: tooth, milestones: milestones),
);

class _ToothSheet extends StatefulWidget {
  const _ToothSheet({required this.child, required this.tooth, required this.milestones});
  final Child child;
  final BabyTooth tooth;
  final List<Event> milestones;

  @override
  State<_ToothSheet> createState() => _ToothSheetState();
}

class _ToothSheetState extends State<_ToothSheet> {
  Event? get e => widget.milestones.where((m) => m['tooth'] == widget.tooth.code).firstOrNull;
  late DateTime _when = e?.start ?? DateTime.now();
  bool _busy = false;

  static String _key(String? s) => (s ?? '').trim().toLowerCase();

  Future<void> _run(Future<void> Function(AppState s) action) async {
    setState(() => _busy = true);
    final s = context.read<AppState>();
    final ok = await guard(context, () => action(s).then((_) => true));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok == true) Navigator.pop(context);
  }

  /// The first tooth becomes the "First tooth" memory (an existing one without a tooth gets this
  /// tooth); the others are logged under their own name.
  Future<void> _save() => _run((s) async {
    final start = formatTime(_when);
    final current = e;
    if (current != null) {
      await s.act((api) => api.patch('/events/${current.id}', {'start': start}));
      return;
    }
    final anyTooth = widget.milestones.any((m) => m['tooth'] != null);
    final firstMemory = widget.milestones
        .where((m) => _key(m['name']) == 'first tooth' && m['tooth'] == null)
        .firstOrNull;
    if (!anyTooth && firstMemory != null) {
      await s.act((api) => api.patch('/events/${firstMemory.id}', {'tooth': widget.tooth.code}));
      return;
    }
    await s.act(
      (api) => api.post('/children/${widget.child.id}/events', {
        'type': 'milestone',
        'name': anyTooth ? widget.tooth.name : 'First tooth',
        'tooth': widget.tooth.code,
        'chapter': 'growing',
        'start': start,
      }),
    );
  });

  /// Not in after all: the "First tooth" memory keeps its photo and story, without the tooth.
  Future<void> _remove() => _run((s) async {
    final current = e!;
    final keep =
        _key(current['name']) == 'first tooth' && (current['photo_version'] != null || (current.note ?? '').isNotEmpty);
    await s.act(
      (api) => keep ? api.patch('/events/${current.id}', {'tooth': null}) : api.delete('/events/${current.id}'),
    );
  });

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final k = Kind.milestone;
    final current = e;
    final age = widget.child.birthDate == null || _when.isBefore(widget.child.birthDate!)
        ? null
        : widget.child.ageAt(_when);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BlobIcon(Kind.milestone, size: 46, icon: Icons.auto_awesome_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.tooth.name, style: serifStyle(21)),
                      Text(
                        'Usually comes in at ${widget.tooth.when}',
                        style: TextStyle(color: c.muted, fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FormRow(
              label: current == null ? 'Came in' : 'Came in on',
              child: DateTimeValue(value: _when, onChanged: (v) => setState(() => _when = v)),
            ),
            if (age != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$age old',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: k.on(c), fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (current != null) ...[
                  OutlinedButton(
                    onPressed: _busy ? null : _remove,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.danger,
                      side: BorderSide(color: c.danger),
                    ),
                    child: const Text('Not in yet'),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.isDark ? k.fill(c) : k.deepTone,
                      foregroundColor: c.onAccent,
                    ),
                    child: Text(current == null ? 'It came in' : 'Save date'),
                  ),
                ),
              ],
            ),
            if (current == null && !widget.milestones.any((m) => m['tooth'] != null))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'The first one goes in the book as "First tooth": add a photo and the story there.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

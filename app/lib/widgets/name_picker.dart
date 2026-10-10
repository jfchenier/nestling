import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';

/// One row of a [showNamePicker] sheet. [value] is what gets saved; [data] rides along (e.g. the
/// last dose of a medicine).
class PickItem {
  const PickItem(this.value, {this.label, this.subtitle, this.data});
  final String value;
  final String? label;
  final String? subtitle;
  final Object? data;

  String get text => label ?? value;
  String get key => value.trim().toLowerCase();
}

/// The child's past entries, newest first (`/children/{id}/events`); empty when offline.
Future<List<Event>> childEvents(AppState s, String type, {int limit = 500}) async {
  try {
    final res = await s.api!.get('/children/${s.childId}/events', {'type': type, 'limit': '$limit'});
    return [for (final j in res['events'] as List) Event(j)];
  } catch (_) {
    // Offline or no access: the common list still works.
    return [];
  }
}

/// A list sheet like the medicine picker: a field to add a custom name, the ones used before
/// ("Recent", newest first, custom ones included), then a [common] list. With [multiple],
/// rows toggle and Done returns them all (in [selected]'s order, then as picked); otherwise
/// a tap returns that one.
Future<List<PickItem>?> showNamePicker(
  BuildContext context, {
  required String title,
  required String addHint,
  required Future<List<PickItem>> Function(AppState s) recent,
  required List<PickItem> common,
  String recentTitle = 'Recent',
  bool multiple = false,
  List<String> selected = const [],
}) => showModalBottomSheet<List<PickItem>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.pal.background,
  builder: (_) => _NamePicker(title, addHint, recent, common, recentTitle, multiple, selected),
);

class _NamePicker extends StatefulWidget {
  const _NamePicker(this.title, this.addHint, this.recent, this.common, this.recentTitle, this.multiple, this.selected);
  final String title, addHint, recentTitle;
  final Future<List<PickItem>> Function(AppState s) recent;
  final List<PickItem> common;
  final bool multiple;
  final List<String> selected;

  @override
  State<_NamePicker> createState() => _NamePickerState();
}

class _NamePickerState extends State<_NamePicker> {
  final _custom = TextEditingController();
  List<PickItem>? _recent;
  // Picked so far (multiple), in order.
  late final List<PickItem> _picked = [
    for (final v in widget.selected)
      if (v.trim().isNotEmpty) PickItem(v.trim()),
  ];

  @override
  void initState() {
    super.initState();
    widget.recent(context.read<AppState>()).then((r) {
      if (mounted) setState(() => _recent = r);
    });
  }

  bool _isPicked(PickItem m) => _picked.any((p) => p.key == m.key);

  void _tap(PickItem m) {
    if (!widget.multiple) return Navigator.pop(context, [m]);
    setState(() => _isPicked(m) ? _picked.removeWhere((p) => p.key == m.key) : _picked.add(m));
  }

  void _add() {
    final v = _custom.text.trim();
    if (v.isEmpty) return;
    final m = PickItem(v);
    if (!widget.multiple) return Navigator.pop(context, [m]);
    setState(() {
      if (!_isPicked(m)) _picked.add(m);
      _custom.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final recent = _recent ?? [];
    final seen = {for (final r in recent) r.key};
    final common = [
      for (final m in widget.common)
        if (!seen.contains(m.key) && !seen.contains(m.text.toLowerCase())) m,
    ];

    Widget header(String text) => Container(
      color: c.raised,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w700, color: c.muted, fontSize: 13),
      ),
    );
    Widget row(PickItem m) {
      final on = widget.multiple && _isPicked(m);
      return ListTile(
        title: Text(m.text, style: const TextStyle(fontSize: 17)),
        subtitle: m.subtitle == null ? null : Text(m.subtitle!),
        trailing: Icon(
          on ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
          color: c.accent,
          semanticLabel: on ? 'Selected' : null,
        ),
        onTap: () => _tap(m),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: serifStyle(24))),
                  if (widget.multiple)
                    TextButton(onPressed: () => Navigator.pop(context, _picked), child: const Text('Done'))
                  else
                    IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            if (widget.multiple && _picked.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in _picked)
                      InputChip(
                        label: Text(p.text),
                        onDeleted: () => setState(() => _picked.removeWhere((x) => x.key == p.key)),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _custom,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  hintText: widget.addHint,
                  prefixIcon: const Icon(Icons.add_rounded),
                  suffixIcon: IconButton(tooltip: 'Use this name', icon: const Icon(Icons.check_rounded), onPressed: _add),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (_recent == null) const LinearProgressIndicator(minHeight: 2),
                  if (recent.isNotEmpty) ...[header(widget.recentTitle), for (final m in recent) row(m)],
                  if (common.isNotEmpty) ...[header('Common'), for (final m in common) row(m)],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


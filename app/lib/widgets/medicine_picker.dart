import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';

/// Common baby medicines and supplements, shown under the ones this child already had.
const commonMedicines = [
  'Vitamin D',
  'Acetaminophen (Tylenol)',
  'Ibuprofen (Advil)',
  'Probiotic (BioGaia)',
  'Gripe water',
  'Simethicone (Ovol)',
  'Saline drops',
  'Iron drops',
  'Amoxicillin',
  'Antihistamine (Benadryl)',
  'Teething gel',
  'Diaper cream',
];

String _n(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

/// A medicine picked from the list, with the dose given last time (for recent ones).
typedef MedicinePick = ({String name, double? dose, String? unit});

/// "Medicine" sheet: add a custom one, recent ones (most recent first, custom included),
/// then the common list.
Future<MedicinePick?> showMedicinePicker(BuildContext context) => showModalBottomSheet<MedicinePick>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.pal.background,
  builder: (_) => const _MedicinePicker(),
);

class _MedicinePicker extends StatefulWidget {
  const _MedicinePicker();

  @override
  State<_MedicinePicker> createState() => _MedicinePickerState();
}

class _MedicinePickerState extends State<_MedicinePicker> {
  final _custom = TextEditingController();
  List<MedicinePick>? _recent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = context.read<AppState>();
    final recent = <String, MedicinePick>{};
    try {
      final res = await s.api!.get('/children/${s.childId}/events', {'type': 'health', 'limit': '500'});
      for (final e in [for (final j in res['events'] as List) Event(j)]) {
        final name = (e['name'] as String?)?.trim();
        if (e['kind'] != 'medicine' || name == null || name.isEmpty) continue;
        recent.putIfAbsent(name.toLowerCase(), () => (name: name, dose: toDouble(e['dose']), unit: e['dose_unit'] as String?));
      }
    } catch (_) {
      // Offline or no access: the common list still works.
    }
    if (mounted) setState(() => _recent = recent.values.toList());
  }

  void _pick(MedicinePick m) => Navigator.pop(context, m);

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final recent = _recent ?? [];
    final seen = {for (final r in recent) r.name.toLowerCase()};
    final common = [
      for (final m in commonMedicines)
        if (!seen.contains(m.toLowerCase())) m,
    ];

    Widget header(String text) => Container(
      color: c.raised,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w700, color: c.muted, fontSize: 13),
      ),
    );
    Widget row(MedicinePick m) => ListTile(
      title: Text(m.name, style: const TextStyle(fontSize: 17)),
      subtitle: m.dose == null ? null : Text('Last dose ${_n(m.dose!)} ${m.unit ?? ''}'.trim()),
      trailing: Icon(Icons.add_circle_outline_rounded, color: c.accent),
      onTap: () => _pick(m),
    );

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
                  Expanded(child: Text('Medicine', style: serifStyle(24))),
                  IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _custom,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => v.trim().isEmpty ? null : _pick((name: v.trim(), dose: null, unit: null)),
                decoration: InputDecoration(
                  hintText: 'Add a medicine',
                  prefixIcon: const Icon(Icons.add_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Use this name',
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () => _custom.text.trim().isEmpty ? null : _pick((name: _custom.text.trim(), dose: null, unit: null)),
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (_recent == null) const LinearProgressIndicator(minHeight: 2),
                  if (recent.isNotEmpty) ...[header('Recent'), for (final m in recent) row(m)],
                  header('Common'),
                  for (final m in common) row((name: m, dose: null, unit: null)),
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

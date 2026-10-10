import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import 'name_picker.dart';

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

/// Built-in activities (saved as these keys, shown as "Tummy time"…), under the ones this
/// child already did; any other name can be added.
const commonActivities = ['tummy_time', 'bath', 'outdoor', 'play', 'read', 'nail_trim', 'vitamin', 'massage', 'skin_to_skin', 'swim', 'music'];

/// Usual first foods, under the ones this child already had.
const commonFoods = [
  'Avocado',
  'Banana',
  'Sweet potato',
  'Carrot',
  'Squash',
  'Peas',
  'Green beans',
  'Broccoli',
  'Apple',
  'Pear',
  'Peach',
  'Mango',
  'Blueberries',
  'Strawberries',
  'Oatmeal',
  'Rice cereal',
  'Pasta',
  'Bread',
  'Yogurt',
  'Cheese',
  'Egg',
  'Peanut butter',
  'Chicken',
  'Beef',
  'Fish',
  'Lentils',
  'Tofu',
];

String _n(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

/// A medicine picked from the list, with the dose given last time (for recent ones).
typedef MedicinePick = ({String name, double? dose, String? unit});

/// "Medicine" sheet: add a custom one, recent ones (most recent first, custom included),
/// then the common list.
Future<MedicinePick?> showMedicinePicker(BuildContext context) async {
  final picked = await showNamePicker(
    context,
    title: 'Medicine',
    addHint: 'Add a medicine',
    common: [for (final m in commonMedicines) PickItem(m)],
    recent: (s) async {
      final recent = <String, PickItem>{};
      for (final e in await childEvents(s, 'health')) {
        final name = (e['name'] as String?)?.trim();
        if (e['kind'] != 'medicine' || name == null || name.isEmpty) continue;
        final dose = toDouble(e['dose']), unit = e['dose_unit'] as String?;
        recent.putIfAbsent(
          name.toLowerCase(),
          () => PickItem(
            name,
            subtitle: dose == null ? null : 'Last dose ${_n(dose)} ${unit ?? ''}'.trim(),
            data: (name: name, dose: dose, unit: unit),
          ),
        );
      }
      return recent.values.toList();
    },
  );
  if (picked == null || picked.isEmpty) return null;
  final m = picked.first;
  return m.data as MedicinePick? ?? (name: m.value, dose: null, unit: null);
}

/// "Activity" sheet: the child's past activities (custom ones included), then the built-in ones.
Future<String?> showActivityPicker(BuildContext context) async {
  final picked = await showNamePicker(
    context,
    title: 'Activity',
    addHint: 'Add an activity',
    common: [for (final a in commonActivities) PickItem(a, label: cap(a))],
    recent: (s) async {
      final done = <String, _Count>{};
      for (final e in await childEvents(s, 'activity')) {
        final kind = (e['kind'] as String?)?.trim();
        if (kind == null || kind.isEmpty || kind == 'activity') continue;
        done.update(kind.toLowerCase(), (t) => t.again(), ifAbsent: () => _Count(kind, e.start));
      }
      return [for (final t in done.values) PickItem(t.name, label: cap(t.name), subtitle: t.subtitle)];
    },
  );
  return picked == null || picked.isEmpty ? null : picked.first.value;
}

/// How often a name was used, folding events newest first.
class _Count {
  _Count(this.name, this.last);
  final String name;
  final DateTime last;
  int times = 1;

  _Count again() => this..times += 1;

  String get subtitle {
    final day = dayLabel(last);
    return '${times == 1 ? 'Once' : '$times times'} · last ${day == 'Today' || day == 'Yesterday' ? day.toLowerCase() : day}';
  }
}

/// The foods of a solids entry ("Avocado, banana" → ["Avocado", "banana"]).
List<String> splitFoods(String? foods) => [
  for (final f in (foods ?? '').split(RegExp(r'[,;\n]')))
    if (f.trim().isNotEmpty) f.trim(),
];

/// "Foods" sheet (several at once): foods this child already had (with how often), then usual
/// first foods; any other food can be added. Returns the full new list, or null if closed.
Future<List<String>?> showFoodPicker(BuildContext context, List<String> selected) async {
  final picked = await showNamePicker(
    context,
    title: 'Foods',
    addHint: 'Add a food',
    recentTitle: 'Already tried',
    multiple: true,
    selected: selected,
    common: [for (final f in commonFoods) PickItem(f)],
    recent: (s) async {
      final tried = <String, _Count>{};
      for (final e in await childEvents(s, 'feed', limit: 1000)) {
        if (e['method'] != 'solids') continue;
        for (final f in splitFoods(e['foods'] as String?)) {
          tried.update(f.toLowerCase(), (t) => t.again(), ifAbsent: () => _Count(f, e.start));
        }
      }
      return [for (final t in tried.values) PickItem(t.name, subtitle: t.subtitle)];
    },
  );
  return picked?.map((p) => p.value).toList();
}

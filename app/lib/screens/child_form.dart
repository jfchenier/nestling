import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/photo.dart';
import 'home.dart' show ChildAvatar;

/// Add or edit a child. Returns the saved child's id.
Future<String?> showChildForm(BuildContext context, {required String familyId, Child? child}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  // Like the entry sheets, so the fields stand out from the sheet.
  backgroundColor: context.pal.background,
  builder: (_) => _ChildForm(familyId: familyId, child: child),
);

class _ChildForm extends StatefulWidget {
  const _ChildForm({required this.familyId, this.child});
  final String familyId;
  final Child? child;

  @override
  State<_ChildForm> createState() => _ChildFormState();
}

class _ChildFormState extends State<_ChildForm> {
  late final _name = TextEditingController(text: widget.child?.name ?? '');
  late DateTime? _birth = widget.child?.birthDate;
  late String? _sex = widget.child?.sex;
  bool _busy = false;
  bool _birthMissing = false;

  // Photo changes, applied on Save.
  Uint8List? _newPhoto;
  bool _removePhoto = false;

  bool get _hasPhoto => _newPhoto != null || (!_removePhoto && widget.child?.photoVersion != null);

  Future<void> _choosePhoto() async {
    final photo = await guard(context, pickSquarePhoto);
    if (photo != null && mounted) setState(() => _newPhoto = photo);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return showMessage(context, 'Enter a name');
    // Required when adding; a baby saved earlier without one can still be edited.
    if (_birth == null && widget.child == null) return setState(() => _birthMissing = true);
    setState(() => _busy = true);
    final body = {'name': _name.text.trim(), 'birth_date': _birth == null ? null : DateFormat('yyyy-MM-dd').format(_birth!), 'sex': _sex};
    final s = context.read<AppState>();
    final res = await guard(
      context,
      () => s.act(
        (api) => widget.child == null
            ? api.post('/families/${widget.familyId}/children', body)
            : api.patch('/children/${widget.child!.id}', body),
        families: true,
      ),
    );
    if (res != null && mounted) {
      final id = res['id'] as String;
      if (_newPhoto != null) {
        await guard(
          context,
          () => s.act((api) => api.putBytes('/children/$id/photo', _newPhoto!, contentType: 'image/png'), families: true),
        );
      } else if (_removePhoto && widget.child?.photoVersion != null) {
        await guard(context, () => s.act((api) => api.delete('/children/$id/photo'), families: true));
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (res != null) Navigator.pop(context, res['id'] as String);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.child == null ? 'Add a baby' : 'Edit ${widget.child!.name}', style: t.titleLarge),
          const SizedBox(height: 16),
          // Profile picture: shown on Home instead of the initial.
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Choose a photo',
                child: GestureDetector(
                  onTap: _busy ? null : _choosePhoto,
                  child: _hasPhoto || widget.child != null
                      ? ChildAvatar(
                          child: widget.child ?? Child({'id': '', 'name': _name.text}),
                          size: 72,
                          photo: _newPhoto,
                          showPhoto: _hasPhoto,
                        )
                      : CircleAvatar(
                          radius: 36,
                          backgroundColor: context.pal.raised,
                          child: Icon(Icons.add_a_photo_outlined, color: context.pal.muted),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: _busy ? null : _choosePhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(_hasPhoto ? 'Change photo' : 'Add a photo'),
                    ),
                    if (_hasPhoto)
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: context.pal.danger),
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _newPhoto = null;
                                _removePhoto = true;
                              }),
                        child: const Text('Remove'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: widget.child == null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _birth ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 300)),
              );
              if (d != null) {
                setState(() {
                  _birth = d;
                  _birthMissing = false;
                });
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: widget.child == null ? 'Birth date (or due date) *' : 'Birth date (or due date)',
                errorText: _birthMissing ? 'Choose a birth date (or due date)' : null,
                suffixIcon: Icon(Icons.calendar_today_rounded, color: context.pal.muted),
              ),
              child: Text(_birth == null ? (widget.child == null ? 'Tap to choose' : 'Not set') : DateFormat.yMMMMd().format(_birth!)),
            ),
          ),
          const SizedBox(height: 16),
          ChoiceChips<String>(
            options: const {'female': 'Girl', 'male': 'Boy', 'other': 'Unknown'},
            value: _sex,
            onChanged: (v) => setState(() => _sex = v),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
          if (widget.child != null) ...[
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: context.pal.danger),
              onPressed: () async {
                if (!await confirmByTyping(
                  context,
                  'Delete ${widget.child!.name}?',
                  'This permanently deletes ${widget.child!.name} and everything logged for them, for every caregiver. '
                      'It can\'t be undone.',
                  expected: widget.child!.name,
                )) {
                  return;
                }
                if (!context.mounted) return;
                final s = context.read<AppState>();
                final ok = await guard(
                  context,
                  () => s.act((api) => api.delete('/children/${widget.child!.id}'), families: true).then((_) => true),
                );
                if (ok == true && context.mounted) Navigator.pop(context);
              },
              child: const Text('Delete baby'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Common IANA zones; the device's offset picks the default.
const timezones = [
  'America/St_Johns',
  'America/Halifax',
  'America/New_York',
  'America/Toronto',
  'America/Chicago',
  'America/Winnipeg',
  'America/Denver',
  'America/Edmonton',
  'America/Phoenix',
  'America/Los_Angeles',
  'America/Vancouver',
  'America/Anchorage',
  'Pacific/Honolulu',
  'America/Mexico_City',
  'America/Bogota',
  'America/Sao_Paulo',
  'America/Argentina/Buenos_Aires',
  'Atlantic/Reykjavik',
  'Europe/London',
  'Europe/Dublin',
  'Europe/Lisbon',
  'Europe/Paris',
  'Europe/Brussels',
  'Europe/Amsterdam',
  'Europe/Berlin',
  'Europe/Madrid',
  'Europe/Rome',
  'Europe/Zurich',
  'Europe/Stockholm',
  'Europe/Warsaw',
  'Europe/Athens',
  'Europe/Helsinki',
  'Europe/Istanbul',
  'Europe/Moscow',
  'Africa/Cairo',
  'Africa/Johannesburg',
  'Africa/Lagos',
  'Africa/Nairobi',
  'Asia/Dubai',
  'Asia/Karachi',
  'Asia/Kolkata',
  'Asia/Dhaka',
  'Asia/Bangkok',
  'Asia/Singapore',
  'Asia/Shanghai',
  'Asia/Hong_Kong',
  'Asia/Manila',
  'Asia/Seoul',
  'Asia/Tokyo',
  'Australia/Perth',
  'Australia/Adelaide',
  'Australia/Brisbane',
  'Australia/Sydney',
  'Pacific/Auckland',
  'UTC',
];

/// Rough guess from the current UTC offset (the server only needs an IANA name for day boundaries).
String guessTimezone() {
  const byOffset = {
    -600: 'Pacific/Honolulu',
    -540: 'America/Anchorage',
    -480: 'America/Los_Angeles',
    -420: 'America/Los_Angeles',
    -360: 'America/Chicago',
    -300: 'America/New_York',
    -240: 'America/New_York',
    -180: 'America/Halifax',
    -150: 'America/St_Johns',
    0: 'Europe/London',
    60: 'Europe/London',
    120: 'Europe/Paris',
    180: 'Europe/Athens',
    240: 'Asia/Dubai',
    330: 'Asia/Kolkata',
    420: 'Asia/Bangkok',
    480: 'Asia/Shanghai',
    540: 'Asia/Tokyo',
    600: 'Australia/Brisbane',
    660: 'Australia/Sydney',
    780: 'Pacific/Auckland',
  };
  final now = DateTime.now();
  final minutes = now.timeZoneOffset.inMinutes;
  // Northern-hemisphere summer offsets in the table assume DST; good enough as a default.
  return byOffset[minutes] ?? 'UTC';
}

class TimezoneField extends StatelessWidget {
  const TimezoneField({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Time zone', helperText: 'Sets where each day starts for daily totals'),
    items: [
      for (final z in {...timezones, value}) DropdownMenuItem(value: z, child: Text(z.replaceAll('_', ' '))),
    ],
    onChanged: (v) => v == null ? null : onChanged(v),
    dropdownColor: context.pal.surface,
  );
}

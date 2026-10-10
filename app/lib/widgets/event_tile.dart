import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../screens/event_form.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// One timeline row: badge, title, detail, time. Tap to edit.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, this.onChanged});
  final Event event;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final u = context.select<AppState, Units>((s) => s.units);
    final (title, detail) = describe(event, u);
    final k = Kind.of(event.type, event.look);
    final sub = [if (detail.isNotEmpty) detail, if (event.note != null && event.note!.isNotEmpty) l10n.timelineNote(event.note!)].join('\n');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: BlobIcon(k, size: 46),
      title: Text(title, style: serifStyle(19)),
      subtitle: sub.isEmpty ? null : Text(sub, style: TextStyle(color: context.pal.muted)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(timeOfDay(event.start), style: const TextStyle(fontWeight: FontWeight.w600)),
          if (event.end != null && event.type != 'feed')
            Text('→ ${timeOfDay(event.end!)}', style: TextStyle(color: context.pal.muted, fontSize: 12)),
        ],
      ),
      onTap: () => showEventForm(context, event: event).then((_) => onChanged?.call()),
    );
  }
}

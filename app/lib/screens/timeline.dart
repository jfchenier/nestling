import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/event_tile.dart';
import 'summary.dart';

/// Everything logged for the child, newest first, grouped by day.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, this.initialFilter});

  /// Type filter to open with (e.g. `feed`), when opened from a home card.
  final String? initialFilter;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  // Keys are the API's type filters; values are labels.
  static Map<String, String> get _filters => {
    'feed': l10n.timelineFeeds,
    'sleep': l10n.kindSleep,
    'diaper': l10n.timelineDiapers,
    'pump': l10n.kindPump,
    'growth': l10n.kindGrowth,
    'health': l10n.kindHealth,
    'activity,milestone,note': l10n.timelineOther,
  };

  final _scroll = ScrollController();
  List<Event> _events = [];
  String? _nextTo;
  bool _loading = false;
  late String? _filter = widget.initialFilter;
  (String?, int)? _loadedFor; // child id + revision

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _more();
    });
  }

  Future<void> _reload() async {
    _nextTo = null;
    await _fetch(reset: true);
  }

  Future<void> _more() async {
    if (_nextTo != null && !_loading) await _fetch();
  }

  Future<void> _fetch({bool reset = false}) async {
    final s = context.read<AppState>();
    if (s.childId == null) return;
    setState(() => _loading = true);
    final res = await guard(
      context,
      () => s.api!.get('/children/${s.childId}/events', {'limit': '60', 'type': ?_filter, if (!reset && _nextTo != null) 'to': _nextTo!}),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res == null) return;
      final page = [for (final e in res['events'] as List) Event(e)];
      _events = reset ? page : [..._events, ...page];
      _nextTo = res['next_to'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final key = (s.childId, s.revision);
    if (_loadedFor != key) {
      _loadedFor = key;
      WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
    }

    final rows = <Widget>[];
    String? day;
    for (final e in _events) {
      final d = dayLabel(e.start);
      if (d != day) {
        day = d;
        rows.add(SectionTitle(d));
      }
      rows.add(Card(child: EventTile(event: e)));
      rows.add(const SizedBox(height: 8));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.timelineTitle(s.child?.name ?? '')),
        actions: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: context.pal.accent,
              foregroundColor: context.pal.onAccent,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // Smaller than the big Save buttons, so it sits centered in the top bar.
              minimumSize: const Size(0, 42),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => showSummary(context),
            icon: const Icon(Icons.bar_chart_rounded, size: 20),
            label: Text(l10n.timelineSummary),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Constrained(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in [null, ..._filters.keys])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f == null ? l10n.timelineAll : _filters[f]!),
                        selected: _filter == f,
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() => _filter = f);
                          _reload();
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    ...rows,
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_events.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(48),
                        child: Text(
                          l10n.timelineEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.pal.muted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

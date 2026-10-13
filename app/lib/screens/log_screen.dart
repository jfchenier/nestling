import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../state.dart';
import '../theme.dart';
import 'event_form.dart';
import 'timer_screen.dart';

/// The Feed and Pump cards' page: a switch on top picks the kind of entry (Breast · Bottle ·
/// Solids · Combo, or Timer · Amount) and the page turns into its timer or form. It opens on the
/// kind last picked on this phone.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key, required this.group, this.pastBreast = false});

  /// `feed` or `pump`.
  final String group;

  /// Log past on a running nursing timer: Breast opens the form instead of the timer.
  final bool pastBreast;

  static Future<void> open(BuildContext context, String group, {bool pastBreast = false}) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LogScreen(group: group, pastBreast: pastBreast),
    ),
  );

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  bool get _feed => widget.group == 'feed';

  Map<String, String> get _options => _feed
      ? {'breast': l10n.logBreast, 'bottle': l10n.kindBottle, 'solids': l10n.kindSolids, 'combo': l10n.kindCombo}
      : {'timer': l10n.homePumpTimer, 'amount': l10n.logAmount};

  // Before anything was picked on this phone: the last feed's kind, or the pump timer.
  late String _choice = () {
    final s = context.read<AppState>();
    final saved = s.logChoice(widget.group);
    if (_options.containsKey(saved)) return saved!;
    final last = _feed ? (s.summary?['last']?['feed']?['method']) : null;
    return _options.containsKey(last) ? last as String : _options.keys.first;
  }();

  bool get _timer => _choice == 'timer' || (_choice == 'breast' && !widget.pastBreast);
  Kind get _kind => Kind.of(widget.group, _choice);
  String get _title => _feed ? l10n.homeCardFeed : l10n.kindPump;

  void _pick(String choice) {
    setState(() => _choice = choice);
    context.read<AppState>().setLogChoice(widget.group, choice);
  }

  Widget _switcher(BuildContext context) {
    final c = context.pal;
    return SegmentedButton<String>(
      segments: [
        for (final MapEntry(:key, :value) in _options.entries)
          ButtonSegment(
            value: key,
            label: FittedBox(fit: BoxFit.scaleDown, child: Text(value, maxLines: 1)),
          ),
      ],
      selected: {_choice},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: c.surface,
        selectedBackgroundColor: _kind.fill(c),
        selectedForegroundColor: c.bandInk,
        side: BorderSide(color: c.line),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      onSelectionChanged: (v) => _pick(v.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_timer) {
      return TimerScreen(key: ValueKey(_choice), kind: _feed ? 'breastfeed' : 'pump', switcher: _switcher(context), title: _title);
    }
    final c = context.pal;
    return Scaffold(
      backgroundColor: Color.lerp(c.background, _kind.fill(c), c.isDark ? 0.25 : 0.3),
      // The form keeps itself above the keyboard.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: l10n.close, onPressed: () => Navigator.pop(context)),
        title: Text(_title),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: _switcher(context)),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: EventForm(key: ValueKey(_choice), type: widget.group, method: _feed ? _choice : null, embedded: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

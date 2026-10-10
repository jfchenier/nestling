import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// The app's texts in the current language (English, French or Spanish; strings are in
/// `lib/l10n/app_*.arb`). A global so plain helpers (formatting, labels) can use it too;
/// [LocaleWatcher] keeps it in step with the app's locale and rebuilds every screen when it changes.
AppLocalizations get l10n => _current;
AppLocalizations _current = lookupAppLocalizations(const Locale('en'));

/// Switches [l10n] without a widget tree (tests, background work).
void useLanguage(String code) => _current = lookupAppLocalizations(Locale(code));

/// Languages offered in Settings, by their own names (null = follow the phone).
const languages = {'en': 'English', 'fr': 'Français', 'es': 'Español'};

/// Sits under the app's `Localizations`: picks up the resolved language, sets [l10n] and
/// intl's default locale (dates), and repaints the whole app when the language changes.
class LocaleWatcher extends StatelessWidget {
  const LocaleWatcher({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final next = AppLocalizations.of(context);
    if (next.localeName != _current.localeName) {
      final first = Intl.defaultLocale == null;
      _current = next;
      Intl.defaultLocale = next.localeName;
      if (!first) WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll(context));
    } else {
      Intl.defaultLocale ??= next.localeName;
    }
    return child;
  }

  static void _rebuildAll(BuildContext context) {
    if (!context.mounted) return;
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }
}

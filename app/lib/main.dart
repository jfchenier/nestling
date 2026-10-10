import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/l10n.dart';
import 'local/store.dart';
import 'screens/baby_book.dart';
import 'screens/calendar.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'screens/onboarding.dart';
import 'screens/timeline.dart';
import 'screens/trends.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(await SharedPreferences.getInstance(), await LocalStore.open());
  if (state.signedIn) state.load();
  runApp(ChangeNotifierProvider.value(value: state, child: const NestlingApp()));
}

class NestlingApp extends StatelessWidget {
  const NestlingApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nestling',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(AppColors.light),
    darkTheme: buildTheme(AppColors.dark),
    themeMode: context.select<AppState, ThemeMode>((s) => s.themeMode),
    locale: switch (context.select<AppState, String?>((s) => s.language)) {
      final code? => Locale(code),
      null => null,
    },
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    builder: (context, child) => LocaleWatcher(child: child!),
    home: const Root(),
  );
}

/// Picks sign-in, onboarding or the main app.
class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.signedIn) return const LoginScreen();
    if (s.me == null) {
      return Scaffold(
        body: Center(
          child: s.error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: s.load, child: Text(l10n.tryAgain)),
                    TextButton(onPressed: s.signOut, child: Text(l10n.signOut)),
                  ],
                ),
        ),
      );
    }
    if (s.child == null) return s.bookOnly ? const _NoBabyYet() : const OnboardingScreen();
    // Book viewers (e.g. grandparents) see the baby book alone.
    if (s.bookOnly) return const BabyBookScreen(asTab: true);
    return const Shell();
  }
}

/// A book viewer's family has no baby yet.
class _NoBabyYet extends StatelessWidget {
  const _NoBabyYet();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(actions: const [BookViewerActions()]),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          l10n.bookNoBabyYet(context.read<AppState>().family?.name ?? l10n.bookTheFamily),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.pal.muted, fontSize: 16),
        ),
      ),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  /// The book is built once first opened (it loads all memories and measurements).
  bool _bookOpened = false;

  @override
  Widget build(BuildContext context) {
    final notice = context.select<AppState, String?>((s) => s.notice);
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AppState>().notice = null;
        showMessage(context, notice);
      });
    }
    return _scaffold();
  }

  Widget _scaffold() => Scaffold(
    body: IndexedStack(
      index: _tab,
      children: [
        const HomeScreen(),
        const TimelineScreen(),
        const CalendarScreen(),
        const TrendsScreen(),
        if (_bookOpened) const BabyBookScreen(asTab: true) else const SizedBox(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() {
        _tab = i;
        _bookOpened |= i == 4;
      }),
      destinations: [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: l10n.homeNavHome),
        NavigationDestination(icon: Icon(Icons.view_agenda_outlined), selectedIcon: Icon(Icons.view_agenda_rounded), label: l10n.homeNavTimeline),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: l10n.homeNavCalendar,
        ),
        NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: l10n.homeNavTrends),
        NavigationDestination(icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories_rounded), label: l10n.homeNavBook),
      ],
    ),
  );
}

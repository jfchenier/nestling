import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local/store.dart';
import 'screens/calendar.dart';
import 'screens/family.dart';
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
                    FilledButton(onPressed: s.load, child: const Text('Try again')),
                    TextButton(onPressed: s.signOut, child: const Text('Sign out')),
                  ],
                ),
        ),
      );
    }
    if (s.child == null) return const OnboardingScreen();
    return const Shell();
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

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
    body: IndexedStack(index: _tab, children: const [HomeScreen(), TimelineScreen(), CalendarScreen(), TrendsScreen(), FamilyScreen()]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.view_agenda_outlined), selectedIcon: Icon(Icons.view_agenda_rounded), label: 'Timeline'),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: 'Calendar',
        ),
        NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Trends'),
        NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'Family'),
      ],
    ),
  );
}

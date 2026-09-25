import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/more_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/prayers_screen.dart';
import 'screens/qibla_screen.dart';
import 'screens/quran_screen.dart';
import 'screens/tasbih_screen.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  await NotificationService.init();
  state.reschedule();
  runApp(const BossMuslimApp());
}

class BossMuslimApp extends StatelessWidget {
  const BossMuslimApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        title: 'Boss Muslim',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: state.themeMode,
        home: state.onboarded ? const RootShell() : const OnboardingScreen(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  static void goTo(BuildContext context, int tab) =>
      context.findAncestorStateOfType<_RootShellState>()?._select(tab);

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  final _visited = <int>{0};

  static const _pages = [
    PrayersScreen(),
    QuranScreen(),
    QiblaScreen(),
    TasbihScreen(),
    MoreScreen(),
  ];

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          for (var i = 0; i < _pages.length; i++)
            // Tabs are built lazily on first visit and kept alive after.
            if (_visited.contains(i))
              IgnorePointer(
                ignoring: i != _index,
                child: AnimatedOpacity(
                  opacity: i == _index ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: TickerMode(enabled: i == _index, child: _pages[i]),
                ),
              ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.tokens.border))),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.mosque_outlined), selectedIcon: Icon(Icons.mosque_rounded), label: 'Prayers'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Quran'),
            NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'Qibla'),
            NavigationDestination(icon: Icon(Icons.radio_button_unchecked_rounded), selectedIcon: Icon(Icons.radio_button_checked_rounded), label: 'Tasbih'),
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'More'),
          ],
        ),
      ),
    );
  }
}

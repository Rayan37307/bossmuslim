import 'dart:ui';

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
        theme: buildTheme(),
        themeMode: ThemeMode.dark,
        home: state.onboarded ? const RootShell() : const OnboardingScreen(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  static void goTo(BuildContext context, int tab) => context.findAncestorStateOfType<_RootShellState>()?._select(tab);

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  final _visited = <int>{0};

  static const _pages = [PrayersScreen(), QuranScreen(), QiblaScreen(), TasbihScreen(), MoreScreen()];

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  static const _tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Quran'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Qibla'),
    (Icons.radio_button_unchecked_rounded, Icons.radio_button_checked_rounded, 'Tasbih'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    // Pages stop above the floating tab bar.
    final navSpace = 84 + MediaQuery.paddingOf(context).bottom;
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
                  child: Padding(
                    padding: EdgeInsets.only(bottom: navSpace),
                    child: MediaQuery.removePadding(
                      context: context,
                      removeBottom: true,
                      child: TickerMode(enabled: i == _index, child: _pages[i]),
                    ),
                  ),
                ),
              ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
            child: Center(
              child: _PillNav(tabs: _tabs, index: _index, onSelect: _select),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating white pill; the selected tab sits in a dark circle.
class _PillNav extends StatelessWidget {
  const _PillNav({required this.tabs, required this.index, required this.onSelect});
  final List<(IconData, IconData, String)> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 64,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              // Frosted glass: a light sheen over the blurred sky.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.07)],
              ),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Tooltip(
                    message: tabs[i].$3,
                    child: Semantics(
                      selected: i == index,
                      button: true,
                      label: tabs[i].$3,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: 56,
                          height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: i == index ? Colors.white : Colors.transparent,
                            shape: BoxShape.circle,
                            boxShadow: i == index ? [BoxShadow(color: Colors.white.withValues(alpha: 0.25), blurRadius: 14)] : null,
                          ),
                          child: Icon(
                            i == index ? tabs[i].$2 : tabs[i].$1,
                            color: i == index ? const Color(0xFF0A1826) : Colors.white.withValues(alpha: 0.78),
                            size: 24,
                          ),
                        ),
                      ),
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

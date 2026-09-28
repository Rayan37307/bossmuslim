import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/night.dart';
import 'location_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final loc = await LocationService.current();
      await AppState.instance.setLocation(loc);
      await _finish();
    } catch (e) {
      setState(() => _error = e is LocationException ? e.message : 'Could not get your location. Try searching instead.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _search() async {
    if (await pickLocation(context)) await _finish();
  }

  Future<void> _finish() async {
    await NotificationService.requestPermissions();
    await AppState.instance.completeOnboarding();
    AppState.instance.reschedule();
  }

  final _pages = PageController();
  int _page = 0;

  static const _slides = [
    ('Connect with\nthe Quran', 'Build a deeper connection with the Quran through daily recitation and reflection.', Icons.menu_book_rounded),
    ('Never miss\na prayer', 'Accurate prayer times and gentle alarms for wherever you are.', Icons.notifications_active_rounded),
    ('Remember Allah\nevery day', 'Tasbih, duas, Qibla and answers from the Quran and Sunnah, all in one place.', Icons.auto_awesome_rounded),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() => _pages.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: NightBackground()),
          // Warm lantern light pooling near the bottom, as in the artwork.
          Positioned(
            right: -80,
            bottom: 60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFFE3A34A).withValues(alpha: 0.22), Colors.transparent]),
              ),
            ),
          ),
          const Positioned(left: 0, top: 0, width: 300, height: 320, child: LanternArt()),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 250),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) {
                      final s = _slides[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (i == 0)
                              const QuranStandArt(size: 110)
                            else
                              Icon(s.$3, size: 72, color: AppColors.gold, shadows: [Shadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 30)]),
                            const SizedBox(height: 28),
                            Text(s.$1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 36, height: 1.15, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 14),
                            Text(s.$2, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFC9D4DE), fontSize: 15, height: 1.5)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),
                PageDots(count: _slides.length, index: _page),
                const SizedBox(height: 26),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: last
                      ? Padding(
                          key: const ValueKey('start'),
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                          child: Column(
                            children: [
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                                ),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _busy ? null : _start,
                                  icon: _busy
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.my_location_rounded, size: 20),
                                  label: const Text('Use my location'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(onPressed: _busy ? null : _search, child: const Text('Choose city manually')),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          key: const ValueKey('next'),
                          padding: const EdgeInsets.only(bottom: 44),
                          child: Material(
                            color: AppColors.accent,
                            shape: const CircleBorder(),
                            elevation: 8,
                            shadowColor: AppColors.accent.withValues(alpha: 0.5),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _next,
                              child: const SizedBox(width: 70, height: 70, child: Icon(Icons.arrow_right_alt_rounded, size: 32, color: Colors.white)),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

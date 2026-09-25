import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
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

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.alarm_rounded, 'Prayer alarms', 'Accurate times for your location'),
      (Icons.menu_book_rounded, 'Qur\'an', 'Translation, audio and bookmarks'),
      (Icons.explore_outlined, 'Qibla & mosques', 'Find direction and places to pray'),
      (Icons.volunteer_activism_outlined, 'Duas & tasbih', 'Authentic supplications, daily dhikr'),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeIn(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.nightlight_round, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(height: 28),
              FadeIn(
                index: 1,
                child: Text('Never miss a\nprayer again.', style: context.text.headlineMedium?.copyWith(height: 1.15, fontSize: 32)),
              ),
              const SizedBox(height: 12),
              FadeIn(
                index: 2,
                child: Text(
                  'Prayer times, Qur\'an, duas and Qibla — everything in one calm, focused app.',
                  style: TextStyle(color: context.tokens.muted, fontSize: 15, height: 1.5),
                ),
              ),
              const SizedBox(height: 32),
              for (var i = 0; i < features.length; i++)
                FadeIn(
                  index: 3 + i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        IconTile(features[i].$1),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(features[i].$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(features[i].$3, style: context.text.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
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
        ),
      ),
    );
  }
}

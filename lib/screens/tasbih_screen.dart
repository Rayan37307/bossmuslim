import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

typedef TasbihPreset = (String name, String arabic, String meaning, int target);

const tasbihPresets = <TasbihPreset>[
  ('SubhanAllah', 'سُبْحَانَ اللَّهِ', 'Glory be to Allah', 33),
  ('Alhamdulillah', 'الْحَمْدُ لِلَّهِ', 'All praise is for Allah', 33),
  ('Allahu Akbar', 'اللَّهُ أَكْبَرُ', 'Allah is the Greatest', 34),
  ('La ilaha illallah', 'لَا إِلَٰهَ إِلَّا اللَّهُ', 'There is no god but Allah', 100),
  ('Astaghfirullah', 'أَسْتَغْفِرُ اللَّهَ', 'I seek Allah\'s forgiveness', 100),
  ('Durood', 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ', 'O Allah, send blessings upon Muhammad', 100),
];

TasbihPreset get currentTasbihPreset =>
    tasbihPresets.firstWhere((p) => p.$1 == AppState.instance.tasbihPhrase, orElse: () => tasbihPresets.first);

/// Counts one dhikr with feedback; a stronger buzz marks a completed round.
void countTasbih() {
  final s = AppState.instance;
  s.tasbihTap();
  if (s.tasbihSound) SystemSound.play(SystemSoundType.click);
  if (!s.tasbihVibrate) return;
  if (s.tasbihTarget > 0 && s.tasbihCount % s.tasbihTarget == 0) {
    HapticFeedback.heavyImpact();
  } else {
    HapticFeedback.lightImpact();
  }
}

/// Count within the current round, and how far through the round we are.
(int, double) tasbihRoundProgress() {
  final s = AppState.instance;
  if (s.tasbihTarget == 0) return (s.tasbihCount, 0);
  final inRound = s.tasbihCount % s.tasbihTarget;
  return (inRound, inRound / s.tasbihTarget);
}

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> with SingleTickerProviderStateMixin {
  late final _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 90), reverseDuration: const Duration(milliseconds: 220));

  static const _goals = [33, 66, 99, 0];

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _pickPhrase() async {
    final s = AppState.instance;
    final v = await showSheet<String>(
      context,
      (_) => OptionSheet(
        title: 'Dhikr',
        options: {for (final p in tasbihPresets) p.$1: '${p.$1} · ${p.$3}'},
        selected: s.tasbihPhrase,
      ),
    );
    if (v != null) {
      final preset = tasbihPresets.firstWhere((p) => p.$1 == v);
      s.setTasbihPreset(preset.$1, s.tasbihTarget);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final accent = context.colors.primary;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final p = currentTasbihPreset;
        final target = s.tasbihTarget;
        final loop = target == 0 ? 1 : s.tasbihCount ~/ target + 1;
        final (inRound, progress) = tasbihRoundProgress();
        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(child: Text('Tasbih Counter', style: context.text.headlineMedium?.copyWith(fontSize: 26))),
                    IconButton(
                      tooltip: 'History',
                      onPressed: () => showSheet(context, (_) => const TasbihHistorySheet()),
                      icon: const Icon(Icons.bar_chart_rounded),
                    ),
                    IconButton(
                      tooltip: 'Full screen',
                      onPressed: () => Navigator.of(context).push(PageRouteBuilder(
                        pageBuilder: (_, _, _) => const TasbihFullscreen(),
                        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
                      )),
                      icon: const Icon(Icons.fullscreen_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Text('Goal', style: TextStyle(color: context.tokens.muted, fontWeight: FontWeight.w500)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (final g in _goals) ...[
                      Expanded(
                        child: Pressable(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            s.setTasbihTarget(g);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: target == g ? accent : context.colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              g == 0 ? '∞' : '$g',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: g == 0 ? 18 : 14.5,
                                color: target == g ? Colors.white : context.tokens.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (g != _goals.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Pressable(
                  onTap: _pickPhrase,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: context.tokens.border),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Row(
                        key: ValueKey(p.$1),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.$2, textDirection: TextDirection.rtl, style: arabicStyle(size: 20, height: 1.7)),
                          const SizedBox(width: 10),
                          Text(p.$1, style: TextStyle(color: context.tokens.muted, fontSize: 13)),
                          Icon(Icons.arrow_drop_down_rounded, color: context.tokens.muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: RollingText(
                  '$inRound',
                  style: TextStyle(
                    fontSize: 68,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: -2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Center(
                child: Text(
                  target == 0 ? 'No goal' : 'Goal: $target',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Loop $loop      Total: ${s.tasbihCount}      Today: ${s.tasbihOn(DateTime.now())}',
                  style: TextStyle(color: context.tokens.muted, fontSize: 13.5),
                ),
              ),
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final size = math.min(c.maxHeight - 16, 240.0).clamp(140.0, 240.0);
                      return GestureDetector(
                        onTapDown: (_) => _press.forward(),
                        onTapUp: (_) => _press.reverse(),
                        onTapCancel: () => _press.reverse(),
                        onTap: countTasbih,
                        child: AnimatedBuilder(
                          animation: _press,
                          builder: (context, child) => Transform.scale(scale: 1 - _press.value * 0.05, child: child),
                          child: SizedBox(
                            width: size + 20,
                            height: size + 20,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox.expand(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(end: progress),
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                    builder: (_, v, _) => CircularProgressIndicator(
                                      value: v,
                                      strokeWidth: 6,
                                      strokeCap: StrokeCap.round,
                                      backgroundColor: context.tokens.accentSoft,
                                      color: accent,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 12)),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text('Tap to count', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    _RoundToggle(
                      icon: s.tasbihVibrate ? Icons.vibration_rounded : Icons.mobile_off_rounded,
                      on: s.tasbihVibrate,
                      tooltip: 'Vibration',
                      onTap: () => s.setTasbihFeedback(vibrate: !s.tasbihVibrate),
                    ),
                    Expanded(
                      child: Center(
                        child: TextButton.icon(
                          onPressed: s.tasbihCount == 0
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact();
                                  s.tasbihReset();
                                },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          style: TextButton.styleFrom(foregroundColor: context.colors.onSurface),
                        ),
                      ),
                    ),
                    _RoundToggle(
                      icon: s.tasbihSound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      on: s.tasbihSound,
                      tooltip: 'Sound',
                      onTap: () => s.setTasbihFeedback(sound: !s.tasbihSound),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundToggle extends StatelessWidget {
  const _RoundToggle({required this.icon, required this.on, required this.tooltip, required this.onTap});
  final IconData icon;
  final bool on;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        scale: 0.88,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? context.tokens.accentSoft : Colors.transparent,
            border: Border.all(color: on ? accent : context.tokens.border, width: 1.4),
          ),
          child: Icon(icon, size: 20, color: on ? accent : context.tokens.muted),
        ),
      ),
    );
  }
}

/// Distraction-free counter: the whole screen is the tap target.
class TasbihFullscreen extends StatefulWidget {
  const TasbihFullscreen({super.key});

  @override
  State<TasbihFullscreen> createState() => _TasbihFullscreenState();
}

class _TasbihFullscreenState extends State<TasbihFullscreen> with SingleTickerProviderStateMixin {
  late final _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _ripple.dispose();
    super.dispose();
  }

  void _tap() {
    countTasbih();
    _ripple.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1B3F),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final p = currentTasbihPreset;
          final (inRound, progress) = tasbihRoundProgress();
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            child: Stack(
              children: [
                // Soft expanding glow on each tap.
                Center(
                  child: AnimatedBuilder(
                    animation: _ripple,
                    builder: (_, _) => Container(
                      width: 200 + _ripple.value * 260,
                      height: 200 + _ripple.value * 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentLight.withValues(alpha: (1 - _ripple.value) * 0.18),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.$2, textDirection: TextDirection.rtl, style: arabicStyle(size: 34, color: Colors.white, height: 1.6)),
                      const SizedBox(height: 12),
                      Text(
                        '$inRound',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 120,
                          fontWeight: FontWeight.w200,
                          letterSpacing: -4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (s.tasbihTarget > 0) ...[
                        SizedBox(
                          width: 180,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: progress),
                              duration: const Duration(milliseconds: 250),
                              builder: (_, v, _) => LinearProgressIndicator(
                                value: v,
                                minHeight: 4,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Round ${s.tasbihCount ~/ s.tasbihTarget + 1} · target ${s.tasbihTarget}',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 32,
                  child: SafeArea(
                    child: Text('Tap anywhere', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TasbihHistorySheet extends StatelessWidget {
  const TasbihHistorySheet({super.key});

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final counts = [for (final d in days) s.tasbihOn(d)];
    final max = counts.fold<int>(0, math.max);
    final week = counts.fold<int>(0, (a, b) => a + b);
    var streak = 0;
    for (var d = today; s.tasbihOn(d) > 0; d = d.subtract(const Duration(days: 1))) {
      streak++;
    }
    final accent = context.colors.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 7 days', style: context.text.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: 20),
            SizedBox(
              height: 170,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              counts[i] == 0 ? '' : '${counts[i]}',
                              style: TextStyle(fontSize: 11, color: context.tokens.muted, fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                            const SizedBox(height: 4),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: max == 0 ? 0 : counts[i] / max),
                              duration: Duration(milliseconds: 400 + i * 60),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) => Container(
                                height: 4 + v * 116,
                                decoration: BoxDecoration(
                                  color: i == days.length - 1 ? accent : accent.withValues(alpha: counts[i] == 0 ? 0.12 : 0.45),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              i == days.length - 1 ? 'Today' : _weekdays[days[i].weekday - 1],
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: i == days.length - 1 ? FontWeight.w700 : FontWeight.w500,
                                color: i == days.length - 1 ? accent : context.tokens.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _stat(context, 'Today', '${counts.last}'),
                const SizedBox(width: 12),
                _stat(context, 'This week', '$week'),
                const SizedBox(width: 12),
                _stat(context, 'Streak', '$streak ${streak == 1 ? 'day' : 'days'}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Expanded(
        child: Panel(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(label, style: context.text.bodySmall?.copyWith(fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
      );
}

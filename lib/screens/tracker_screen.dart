import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/prayer_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

const fardPrayers = [Salah.fajr, Salah.dhuhr, Salah.asr, Salah.maghrib, Salah.isha];

extension PrayerMarkX on PrayerMark {
  String get label => switch (this) {
        PrayerMark.onTime => 'Prayed on time',
        PrayerMark.late => 'Prayed late (qada)',
        PrayerMark.missed => 'Missed',
      };

  Color color(BuildContext context) => switch (this) {
        PrayerMark.onTime => context.colors.primary,
        PrayerMark.late => AppColors.warning,
        PrayerMark.missed => AppColors.danger,
      };

  IconData get icon => switch (this) {
        PrayerMark.onTime => Icons.check_rounded,
        PrayerMark.late => Icons.schedule_rounded,
        PrayerMark.missed => Icons.close_rounded,
      };
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Number of prayers performed (on time or late) on a day.
int prayedOn(DateTime day) {
  final s = AppState.instance;
  return fardPrayers.where((p) {
    final m = s.markOf(day, p);
    return m == PrayerMark.onTime || m == PrayerMark.late;
  }).length;
}

/// Consecutive days, ending today (or yesterday if today isn't complete yet), with all five prayed.
int currentStreak() {
  var d = _dateOnly(DateTime.now());
  if (prayedOn(d) < 5) d = d.subtract(const Duration(days: 1));
  var n = 0;
  while (prayedOn(d) == 5) {
    n++;
    d = d.subtract(const Duration(days: 1));
  }
  return n;
}

/// Tap: toggle on time. Long press: pick a status.
Future<void> editMark(BuildContext context, DateTime day, Salah s, {bool pick = false}) async {
  final state = AppState.instance;
  if (_dateOnly(day).isAfter(_dateOnly(DateTime.now()))) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can\'t log prayers for future days'), duration: Duration(seconds: 1)));
    return;
  }
  final current = state.markOf(day, s);
  if (!pick) {
    HapticFeedback.lightImpact();
    await state.setMark(day, s, current == null ? PrayerMark.onTime : null);
    return;
  }
  final result = await showSheet<Object>(
    context,
    (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(s.label, style: ctx.text.titleLarge?.copyWith(fontSize: 18)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(fmtDate(day), style: ctx.text.bodySmall),
          ),
          for (final m in PrayerMark.values)
            ListTile(
              leading: CircleAvatar(radius: 16, backgroundColor: m.color(ctx), child: Icon(m.icon, size: 18, color: Colors.white)),
              title: Text(m.label),
              trailing: current == m ? Icon(Icons.check_circle_rounded, color: ctx.colors.primary) : null,
              onTap: () => Navigator.pop(ctx, m),
            ),
          ListTile(
            leading: CircleAvatar(radius: 16, backgroundColor: ctx.colors.surfaceContainerHighest, child: Icon(Icons.remove_rounded, size: 18, color: ctx.tokens.muted)),
            title: const Text('Not logged'),
            onTap: () => Navigator.pop(ctx, 'clear'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (result == null) return;
  HapticFeedback.selectionClick();
  await state.setMark(day, s, result is PrayerMark ? result : null);
}

/// Circular check for one prayer; colour reflects its status.
class MarkDot extends StatelessWidget {
  const MarkDot({super.key, required this.mark, this.size = 36});
  final PrayerMark? mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = mark?.color(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c ?? Colors.transparent,
        border: Border.all(color: c ?? context.tokens.muted.withValues(alpha: 0.45), width: 1.6),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
        child: mark == null
            ? const SizedBox.shrink()
            : Icon(mark!.icon, key: ValueKey(mark), size: size * 0.55, color: Colors.white),
      ),
    );
  }
}

/// Progress summary for the Prayers tab; prayers are ticked off in the list below it.
class TrackerProgress extends StatelessWidget {
  const TrackerProgress({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final done = prayedOn(day);
    final future = _dateOnly(day).isAfter(_dateOnly(DateTime.now()));
    return Panel(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrackerScreen())),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(done == 5 ? Icons.verified_rounded : Icons.task_alt_rounded, size: 20, color: context.colors.primary),
              const SizedBox(width: 8),
              Text('Namaz tracker', style: context.text.titleMedium?.copyWith(fontSize: 15)),
              const SizedBox(width: 8),
              if (!future)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    '$done/5',
                    key: ValueKey(done),
                    style: TextStyle(color: done == 5 ? context.colors.primary : context.tokens.muted, fontWeight: FontWeight.w700),
                  ),
                ),
              const Spacer(),
              Text('Stats', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
              Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.primary),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: done / 5),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: context.tokens.accentSoft,
                color: context.colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            future
                ? 'You can log prayers once the day arrives'
                : (done == 5 ? 'All five prayed. Alhamdulillah.' : 'Tick each prayer below · hold for late or missed'),
            style: context.text.bodySmall?.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static const _wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Namaz Tracker')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final today = _dateOnly(DateTime.now());
          final days = DateUtils.getDaysInMonth(_month.year, _month.month);
          var logged = 0, onTime = 0, late = 0, possible = 0;
          for (var i = 1; i <= days; i++) {
            final d = DateTime(_month.year, _month.month, i);
            if (d.isAfter(today)) break;
            possible += 5;
            for (final p in fardPrayers) {
              switch (state.markOf(d, p)) {
                case PrayerMark.onTime:
                  onTime++;
                  logged++;
                case PrayerMark.late:
                  late++;
                  logged++;
                case _:
              }
            }
          }
          // Missed prayers across the whole log are qada still owed.
          final owed = <Salah, int>{for (final p in fardPrayers) p: 0};
          for (final e in state.prayerLog.values) {
            for (final p in fardPrayers) {
              if (e[p.name] == PrayerMark.missed.name) owed[p] = owed[p]! + 1;
            }
          }
          final owedTotal = owed.values.fold<int>(0, (a, b) => a + b);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              Row(
                children: [
                  _stat(context, Icons.local_fire_department_rounded, '${currentStreak()}', 'Day streak'),
                  const SizedBox(width: 10),
                  _stat(context, Icons.pie_chart_outline_rounded, possible == 0 ? '—' : '${(logged * 100 / possible).round()}%', 'This month'),
                  const SizedBox(width: 10),
                  _stat(context, Icons.alarm_on_rounded, logged == 0 ? '—' : '${(onTime * 100 / logged).round()}%', 'On time'),
                ],
              ),
              const SectionHeader('Last 7 days'),
              Panel(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 52),
                        for (final p in fardPrayers)
                          Expanded(
                            child: Text(p.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: context.tokens.muted, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < 7; i++)
                      Builder(builder: (context) {
                        final d = today.subtract(Duration(days: i));
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 52,
                                child: Text(
                                  i == 0 ? 'Today' : (i == 1 ? 'Yest.' : '${d.day}/${d.month}'),
                                  style: TextStyle(fontSize: 12.5, fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500),
                                ),
                              ),
                              for (final p in fardPrayers)
                                Expanded(
                                  child: Center(
                                    child: Pressable(
                                      scale: 0.85,
                                      onTap: () => editMark(context, d, p),
                                      onLongPress: () => editMark(context, d, p, pick: true),
                                      child: MarkDot(mark: state.markOf(d, p), size: 30),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        for (final m in PrayerMark.values)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: m.color(context), shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text(m == PrayerMark.onTime ? 'On time' : (m == PrayerMark.late ? 'Late' : 'Missed'), style: context.text.bodySmall?.copyWith(fontSize: 12)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionHeader('Monthly overview'),
              Panel(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text('${_monthNames[_month.month - 1]} ${_month.year}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          onPressed: _month.year == today.year && _month.month == today.month
                              ? null
                              : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        for (final w in _wd)
                          Expanded(child: Text(w, textAlign: TextAlign.center, style: TextStyle(color: context.tokens.muted, fontSize: 12, fontWeight: FontWeight.w600))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _Heatmap(key: ValueKey(_month), month: _month),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('0', style: context.text.bodySmall?.copyWith(fontSize: 11)),
                        const SizedBox(width: 6),
                        for (var i = 0; i <= 5; i++)
                          Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(color: _heat(context, i), borderRadius: BorderRadius.circular(4)),
                          ),
                        const SizedBox(width: 3),
                        Text('5 prayers', style: context.text.bodySmall?.copyWith(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionHeader('Qada to make up'),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: owedTotal == 0
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.verified_rounded, color: context.colors.primary),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('No missed prayers logged. Alhamdulillah.')),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          for (final p in fardPrayers)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(child: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  Text('${owed[p]}', style: TextStyle(fontWeight: FontWeight.w700, color: owed[p]! > 0 ? AppColors.danger : context.tokens.muted)),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: owed[p] == 0 ? null : () => _makeUp(p),
                                    child: const Text('Made up'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                late > 0 ? '$late prayer${late == 1 ? '' : 's'} prayed late this month.' : 'Log a missed prayer by holding its circle.',
                style: context.text.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Converts the oldest missed entry of [p] into a late (made-up) prayer.
  Future<void> _makeUp(Salah p) async {
    final state = AppState.instance;
    final keys = state.prayerLog.keys.where((k) => state.prayerLog[k]![p.name] == PrayerMark.missed.name).toList()..sort();
    if (keys.isEmpty) return;
    final parts = keys.first.split('-').map(int.parse).toList();
    HapticFeedback.mediumImpact();
    await state.setMark(DateTime(parts[0], parts[1], parts[2]), p, PrayerMark.late);
  }

  Widget _stat(BuildContext context, IconData icon, String value, String label) => Expanded(
        child: Panel(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: context.colors.primary, size: 22),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              const SizedBox(height: 2),
              Text(label, style: context.text.bodySmall?.copyWith(fontSize: 11.5)),
            ],
          ),
        ),
      );
}

Color _heat(BuildContext context, int count) {
  if (count == 0) return context.colors.surfaceContainerHighest;
  return context.colors.primary.withValues(alpha: 0.18 + 0.82 * count / 5);
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({super.key, required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final lead = DateTime(month.year, month.month, 1).weekday - 1;
    final today = _dateOnly(DateTime.now());
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (var i = 0; i < lead; i++) const SizedBox.shrink(),
        for (var d = 1; d <= days; d++)
          Builder(builder: (context) {
            final date = DateTime(month.year, month.month, d);
            final future = date.isAfter(today);
            final n = future ? 0 : prayedOn(date);
            final isToday = date == today;
            return Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: future ? Colors.transparent : _heat(context, n),
                borderRadius: BorderRadius.circular(8),
                border: isToday ? Border.all(color: context.colors.primary, width: 1.5) : null,
              ),
              child: Text(
                '$d',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: future ? context.tokens.muted.withValues(alpha: 0.5) : (n >= 3 ? Colors.white : null),
                ),
              ),
            );
          }),
      ],
    );
  }
}

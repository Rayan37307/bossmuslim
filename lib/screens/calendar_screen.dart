import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/hijri.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _gMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

Color eventColor(BuildContext context, EventKind k) => switch (k) {
      EventKind.major => context.colors.primary,
      EventKind.fasting => AppColors.warning,
      EventKind.sacred => const Color(0xFF7C3AED),
    };

String relativeDays(DateTime date) {
  final now = DateTime.now();
  final n = DateTime(date.year, date.month, date.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (n == 0) return 'Today';
  if (n == 1) return 'Tomorrow';
  if (n < 0) return 'Ongoing';
  return 'In $n days';
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late int _year;
  late int _month;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    final h = Hijri.of(DateTime.now());
    _year = h.year;
    _month = h.month;
  }

  void _shift(int by) {
    var m = _month + by, y = _year;
    if (m > 12) {
      m = 1;
      y++;
    } else if (m < 1) {
      m = 12;
      y--;
    }
    // Umm al-Qura tables cover 1356–1500 AH.
    if (y < 1357 || y > 1499) return;
    HapticFeedback.selectionClick();
    setState(() {
      _direction = by;
      _year = y;
      _month = m;
    });
  }

  void _goToday() {
    final h = Hijri.of(DateTime.now());
    setState(() {
      _direction = (h.year * 12 + h.month) >= (_year * 12 + _month) ? 1 : -1;
      _year = h.year;
      _month = h.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Islamic Calendar'),
        actions: [
          IconButton(tooltip: 'Adjust date', onPressed: () => _adjust(context), icon: const Icon(Icons.tune_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final now = DateTime.now();
          final today = Hijri.of(now);
          final isCurrent = today.year == _year && today.month == _month;
          final first = Hijri.toGregorian(_year, _month, 1);
          final last = first.add(Duration(days: Hijri.daysInMonth(_year, _month) - 1));
          final range = first.month == last.month
              ? '${_gMonths[first.month - 1]} ${first.year}'
              : '${_gMonths[first.month - 1]}${first.year != last.year ? ' ${first.year}' : ''} – ${_gMonths[last.month - 1]} ${last.year}';

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              _TodayCard(today: today, now: now),
              const SizedBox(height: 16),
              Panel(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
                        Expanded(
                          child: GestureDetector(
                            onTap: isCurrent ? null : _goToday,
                            child: Column(
                              children: [
                                Text('${hijriMonths[_month - 1]} $_year', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                const SizedBox(height: 2),
                                Text(isCurrent ? range : '$range · Back to today', style: context.text.bodySmall?.copyWith(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        for (final w in _weekdays)
                          Expanded(
                            child: Text(
                              w,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: w == 'Fri' ? context.colors.primary : context.tokens.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onHorizontalDragEnd: (d) {
                        final v = d.primaryVelocity ?? 0;
                        if (v.abs() > 250) _shift(v < 0 ? 1 : -1);
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, anim) {
                          final incoming = child.key == ValueKey('$_year-$_month');
                          return FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween(begin: Offset((incoming ? 0.12 : -0.12) * _direction, 0), end: Offset.zero).animate(anim),
                              child: child,
                            ),
                          );
                        },
                        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                        child: _MonthGrid(key: ValueKey('$_year-$_month'), year: _year, month: _month, today: today),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _legend(context, context.colors.primary, 'Eid & Ramadan'),
                  _legend(context, AppColors.warning, 'Sunnah fast'),
                  _legend(context, const Color(0xFF7C3AED), 'Sacred days'),
                  _legend(context, context.tokens.muted, 'White days', outline: true),
                ],
              ),
              const SectionHeader('Upcoming'),
              for (final (i, u) in upcomingEvents(now).indexed)
                FadeIn(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _EventTile(item: u),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'Dates follow the Umm al-Qura calendar${state.hijriOffset == 0 ? '' : ', adjusted by ${state.hijriOffset > 0 ? '+' : ''}${state.hijriOffset} day${state.hijriOffset.abs() == 1 ? '' : 's'}'}. '
                'Actual dates depend on local moon sighting — adjust with the button at the top.',
                style: context.text.bodySmall?.copyWith(height: 1.5, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _legend(BuildContext context, Color c, String label, {bool outline = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: outline ? null : c,
              border: outline ? Border.all(color: c, width: 1.4) : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: context.text.bodySmall?.copyWith(fontSize: 12)),
        ],
      );

  Future<void> _adjust(BuildContext context) => showSheet(
        context,
        (ctx) => ListenableBuilder(
          listenable: AppState.instance,
          builder: (ctx, _) {
            final s = AppState.instance;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hijri date adjustment', style: ctx.text.titleLarge?.copyWith(fontSize: 18)),
                    const SizedBox(height: 6),
                    Text('Match the date announced by your local moon-sighting authority.', style: ctx.text.bodySmall),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: ctx.tokens.accentSoft,
                          selectedForegroundColor: ctx.colors.primary,
                          side: BorderSide(color: ctx.tokens.border),
                        ),
                        segments: [
                          for (final d in [-2, -1, 0, 1, 2]) ButtonSegment(value: d, label: Text(d > 0 ? '+$d' : '$d')),
                        ],
                        selected: {s.hijriOffset},
                        onSelectionChanged: (v) => s.setHijriOffset(v.first),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(child: Text('Today: ${Hijri.of(DateTime.now())}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today, required this.now});
  final HijriDate today;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final events = eventsOn(today.month, today.day);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0E8A5F), Color(0xFF064E3B)]),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '${today.day} ${today.monthName}',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                Text('${today.year} AH', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(fmtDate(now), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                if (events.isNotEmpty || isWhiteDay(today.month, today.day)) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      events.isNotEmpty ? events.first.name : 'White day · Sunnah to fast',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(today.monthArabic, textDirection: TextDirection.rtl, style: arabicStyle(size: 28, color: Colors.white, height: 1.4)),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({super.key, required this.year, required this.month, required this.today});
  final int year;
  final int month;
  final HijriDate today;

  @override
  Widget build(BuildContext context) {
    final first = Hijri.toGregorian(year, month, 1);
    final length = Hijri.daysInMonth(year, month);
    final lead = first.weekday - 1;
    final accent = context.colors.primary;

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 0.82,
      children: [
        for (var i = 0; i < lead; i++) const SizedBox.shrink(),
        for (var d = 1; d <= length; d++)
          Builder(builder: (context) {
            final g = first.add(Duration(days: d - 1));
            final isToday = today.year == year && today.month == month && today.day == d;
            final events = eventsOn(month, d);
            final white = isWhiteDay(month, d);
            final eventC = events.isEmpty ? null : eventColor(context, events.first.kind);
            return Pressable(
              scale: 0.9,
              onTap: () => _showDay(context, d, g, events, white),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isToday ? accent : (eventC?.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(12),
                  border: white && !isToday ? Border.all(color: context.tokens.muted.withValues(alpha: 0.4)) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$d',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isToday ? Colors.white : (eventC ?? (g.weekday == DateTime.friday ? accent : null)),
                      ),
                    ),
                    Text(
                      '${g.day}',
                      style: TextStyle(fontSize: 10.5, color: isToday ? Colors.white70 : context.tokens.muted),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: eventC == null ? Colors.transparent : (isToday ? Colors.white : eventC),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showDay(BuildContext context, int d, DateTime g, List<IslamicEvent> events, bool white) {
    showSheet(
      context,
      (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$d ${hijriMonths[month - 1]} $year AH', style: ctx.text.titleLarge?.copyWith(fontSize: 19)),
              const SizedBox(height: 2),
              Text(fmtDate(g), style: ctx.text.bodySmall),
              const SizedBox(height: 16),
              if (events.isEmpty && !white) Text('No special occasions.', style: TextStyle(color: ctx.tokens.muted)),
              for (final e in events) ...[
                _occasion(ctx, eventColor(ctx, e.kind), e.name, e.description),
                const SizedBox(height: 12),
              ],
              if (white)
                _occasion(ctx, ctx.tokens.muted, 'White day (Ayyam al-Beed)', 'Fasting the 13th, 14th and 15th of each lunar month is Sunnah (Nasa\'i 2420).'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _occasion(BuildContext context, Color c, String title, String body) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 40, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: context.tokens.muted, height: 1.45, fontSize: 13.5)),
              ],
            ),
          ),
        ],
      );
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.item});
  final UpcomingEvent item;

  @override
  Widget build(BuildContext context) {
    final e = item.event;
    final c = eventColor(context, e.kind);
    final rel = relativeDays(item.date);
    final soon = rel == 'Today' || rel == 'Ongoing' || rel == 'Tomorrow';
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text('${e.day}', style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 18, height: 1.1)),
                Text(hijriMonths[e.month - 1].split(' ').first.replaceAll('\'', ''), style: TextStyle(color: c, fontSize: 9.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(fmtDate(item.date), style: context.text.bodySmall?.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: soon ? c : context.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(rel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: soon ? Colors.white : context.tokens.muted)),
          ),
        ],
      ),
    );
  }
}

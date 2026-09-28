import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/hijri.dart';
import '../services/prayer_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/night.dart';
import '../main.dart';
import 'duas_screen.dart';
import 'mosques_screen.dart';
import 'calendar_screen.dart';
import 'location_sheet.dart';
import 'muslim_ai_screen.dart';
import 'timetable_screen.dart';
import 'tracker_screen.dart';

const _verses = [
  ('وَقَالَ رَبُّكُمُ ادْعُونِي أَسْتَجِبْ لَكُمْ', '"Call upon Me; I will respond to you."', 'Ghafir 40:60'),
  ('فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ', '"So remember Me; I will remember you. And be grateful to Me and do not deny Me."', 'Al-Baqarah 2:152'),
  ('فَإِنَّ مَعَ الْعُسْرِ يُسْرًا ۝ إِنَّ مَعَ الْعُسْرِ يُسْرًا', '"For indeed, with hardship comes ease. Indeed, with hardship comes ease."', 'Ash-Sharh 94:5–6'),
  ('أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ', '"Verily, in the remembrance of Allah do hearts find rest."', 'Ar-Ra\'d 13:28'),
  ('لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا', '"Allah does not burden a soul beyond that it can bear."', 'Al-Baqarah 2:286'),
  ('وَمَنْ يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ', '"And whoever relies upon Allah — then He is sufficient for him."', 'At-Talaq 65:3'),
  ('إِنَّ اللَّهَ مَعَ الصَّابِرِينَ', '"Indeed, Allah is with the patient."', 'Al-Baqarah 2:153'),
];

String _countdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  return h > 0 ? '${h}h:${two(d.inMinutes % 60)}m:${two(d.inSeconds % 60)}s' : '${two(d.inMinutes)}m:${two(d.inSeconds % 60)}s';
}

class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  DateTime _day = DateTime.now();
  int _direction = 1; // for the day-change slide

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _shift(int days) {
    HapticFeedback.selectionClick();
    setState(() {
      _direction = days.sign;
      _day = _day.add(Duration(days: days));
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _direction = d.isAfter(_day) ? 1 : -1;
        _day = d;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Ticker(
        builder: (context, now) {
          final status = state.statusAt(now);
          final isToday = _sameDay(_day, now);
          final times = state.timesFor(_day);
          final verse = _verses[now.difference(DateTime(2024)).inDays % _verses.length];

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _TopBar()),
              SliverToBoxAdapter(child: _HeroCarousel(status: status, now: now)),
              const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SectionHeader('Prayer Times')),
              ),
              SliverToBoxAdapter(
                child: _DateRow(
                  day: _day,
                  isToday: isToday,
                  onPick: _pickDate,
                  onPrev: () => _shift(-1),
                  onNext: () => _shift(1),
                  onToday: () => setState(() {
                    _direction = now.isAfter(_day) ? 1 : -1;
                    _day = now;
                  }),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TrackerProgress(day: _day),
                ),
              ),
              SliverToBoxAdapter(
                child: GestureDetector(
                  // Swipe between days.
                  onHorizontalDragEnd: (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v.abs() > 250) _shift(v < 0 ? 1 : -1);
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) {
                      final incoming = child.key == ValueKey(_day.toIso8601String().substring(0, 10));
                      final dx = (incoming ? 0.15 : -0.15) * _direction;
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(anim), child: child),
                      );
                    },
                    layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                    child: _PrayerList(
                      key: ValueKey(_day.toIso8601String().substring(0, 10)),
                      times: times,
                      status: isToday ? status : null,
                      now: now,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList.list(
                  children: [
                    const SizedBox(height: 4),
                    _NextEventCard(now: now),
                    const SectionHeader('Fasting'),
                    Row(
                      children: [
                        _MiniTile(icon: Icons.dark_mode_outlined, label: 'Sehri ends', value: fmtTime(times.sehriEnds)),
                        const SizedBox(width: 12),
                        _MiniTile(icon: Icons.wb_twilight_rounded, label: 'Iftar', value: fmtTime(times.iftar)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _MiniTile(icon: Icons.bedtime_outlined, label: 'Midnight', value: fmtTime(times.midnight)),
                        const SizedBox(width: 12),
                        _MiniTile(icon: Icons.auto_awesome_outlined, label: 'Tahajjud', value: fmtTime(times.lastThird)),
                      ],
                    ),
                    const SectionHeader('Verse of the day'),
                    _VerseCard(arabic: verse.$1, meaning: verse.$2, ref: verse.$3),
                    SectionHeader('Features', action: 'See all', onAction: () => RootShell.goTo(context, 4)),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: _Features()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(
          children: [
            GlassIconButton(icon: Icons.place_outlined, tooltip: 'Change location', onTap: () => pickLocation(context)),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => pickLocation(context),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assalamu alaikum', style: context.text.bodySmall?.copyWith(fontSize: 12.5)),
                    Text(
                      state.location.name.split(',').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5),
                    ),
                  ],
                ),
              ),
            ),
            GlassIconButton(
              icon: Icons.calendar_month_outlined,
              tooltip: 'Monthly timetable',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TimetableScreen())),
            ),
            const SizedBox(width: 10),
            GlassIconButton(icon: Icons.tune_rounded, tooltip: 'Calculation settings', onTap: () => showCalcSettings(context)),
          ],
        ),
      ),
    );
  }
}

/// Swipeable banners in the lantern style: prayer countdown, tasbih, Muslim AI.
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.status, required this.now});
  final PrayerStatus status;
  final DateTime now;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final current = status.current;
    final remaining = (current != null ? status.currentEnds! : status.nextAt).difference(widget.now);
    final slides = [
      _Banner(
        eyebrow: current != null ? '${current.label} time left' : '${status.next.label} begins in',
        big: RollingText(
          _countdown(remaining),
          style: const TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.5, fontFeatures: [FontFeature.tabularFigures()]),
        ),
        subtitle: '${status.next.label} at ${fmtTime(status.nextAt)}',
      ),
      _Banner(
        title: 'Start Tasbih\nTracking',
        subtitle: 'Remember Allah every day',
        button: 'Get Start Now',
        onTap: () => RootShell.goTo(context, 3),
      ),
      _Banner(
        title: 'Ask\nMuslim AI',
        subtitle: 'Answers from the Quran & Sunnah',
        button: 'Ask a question',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MuslimAiScreen())),
      ),
    ];
    return Column(
      children: [
        SizedBox(
          height: 196,
          child: PageView(
            controller: _pages,
            onPageChanged: (i) => setState(() => _page = i),
            children: [for (final s in slides) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: s)],
          ),
        ),
        const SizedBox(height: 14),
        PageDots(count: slides.length, index: _page),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({this.eyebrow, this.title, this.big, this.subtitle, this.button, this.onTap});
  final String? eyebrow;
  final String? title;
  final Widget? big;
  final String? subtitle;
  final String? button;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3B55), Color(0xFF10263A), Color(0xFF0C1E30)],
        ),
        border: Border.all(color: const Color(0x26FFFFFF)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(right: -6, top: 0, bottom: 0, width: 170, child: LanternArt()),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 150, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (eyebrow != null) Text(eyebrow!, style: const TextStyle(color: Color(0xFFB9C8D6), fontSize: 14)),
                if (title != null)
                  Text(title!, style: const TextStyle(fontSize: 23, height: 1.2, fontWeight: FontWeight.w600)),
                if (big != null) FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: big),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(subtitle!, style: const TextStyle(color: Color(0xFFD5DEE7), fontSize: 13.5)),
                ],
                if (button != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                    ),
                    child: Text(button!, style: const TextStyle(fontSize: 13.5)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Features extends StatelessWidget {
  const _Features();

  @override
  Widget build(BuildContext context) {
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    final items = [
      (Icons.menu_book_rounded, 'Quran', const Color(0xFF6FD3C2), () => RootShell.goTo(context, 1)),
      (Icons.volunteer_activism_rounded, 'Dua', const Color(0xFF7EB8FF), () => push(const DuasPage())),
      (Icons.auto_awesome_rounded, 'Muslim AI', AppColors.gold, () => push(const MuslimAiScreen())),
      (Icons.task_alt_rounded, 'Tracker', const Color(0xFF8BE08F), () => push(const TrackerScreen())),
      (Icons.explore_rounded, 'Qibla', const Color(0xFFFFA86B), () => RootShell.goTo(context, 2)),
      (Icons.mosque_rounded, 'Mosques', const Color(0xFFE59BFF), () => push(const MosquesScreen())),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
        padding: EdgeInsets.zero,
        children: [
          for (final f in items)
            Panel(
              onTap: f.$4,
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(f.$1, size: 30, color: f.$3),
                  const SizedBox(height: 10),
                  Text(f.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.day,
    required this.isToday,
    required this.onPick,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });
  final DateTime day;
  final bool isToday;
  final VoidCallback onPick, onPrev, onNext, onToday;

  @override
  Widget build(BuildContext context) {
    final h = Hijri.of(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onPick,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(fmtDate(day), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded),
                    ],
                  ),
                  Text('$h', style: context.text.bodySmall),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: isToday
                ? const SizedBox.shrink()
                : TextButton(onPressed: onToday, child: const Text('Today', style: TextStyle(fontWeight: FontWeight.w700))),
          ),
          IconButton(onPressed: onPrev, visualDensity: VisualDensity.compact, icon: const Icon(Icons.chevron_left_rounded)),
          IconButton(onPressed: onNext, visualDensity: VisualDensity.compact, icon: const Icon(Icons.chevron_right_rounded)),
        ],
      ),
    );
  }
}

class _Row {
  const _Row(this.salah, this.name, this.subtitle, this.icon, this.time, {this.forbiddenUntil});
  final Salah? salah; // null for Zawal
  final String name;
  final String subtitle;
  final IconData icon;
  final DateTime time;
  final DateTime? forbiddenUntil;
}

class _PrayerList extends StatelessWidget {
  const _PrayerList({super.key, required this.times, required this.status, required this.now});
  final DayTimes times;
  final PrayerStatus? status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final friday = times.date.weekday == DateTime.friday;
    final zawal = times.forbidden[1];
    final rows = [
      _Row(Salah.fajr, 'Fajr', 'Dawn', Icons.wb_twilight_rounded, times[Salah.fajr]),
      _Row(Salah.sunrise, 'Shuruq', 'Sunrise', Icons.wb_sunny_outlined, times[Salah.sunrise]),
      _Row(null, 'Zawal', 'Avoid prayer until Dhuhr', Icons.do_not_disturb_on_outlined, zawal.start, forbiddenUntil: zawal.end),
      _Row(Salah.dhuhr, friday ? 'Jumu\'ah' : 'Dhuhr', 'Noon', Icons.light_mode_outlined, times[Salah.dhuhr]),
      _Row(Salah.asr, 'Asr', 'Afternoon', Icons.filter_drama_outlined, times[Salah.asr]),
      _Row(Salah.maghrib, 'Maghrib', 'Sunset', Icons.wb_twilight_outlined, times[Salah.maghrib]),
      _Row(Salah.isha, 'Isha', 'Night', Icons.nightlight_outlined, times[Salah.isha]),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(indent: 8, endIndent: 8),
              FadeIn(
                index: i,
                child: _PrayerCard(
                day: times.date,
                row: rows[i],
                active: rows[i].salah != null && status?.current == rows[i].salah,
                next: rows[i].salah != null && status?.next == rows[i].salah,
                  forbiddenNow: rows[i].forbiddenUntil != null && status != null && !now.isBefore(rows[i].time) && now.isBefore(rows[i].forbiddenUntil!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({required this.day, required this.row, required this.active, required this.next, required this.forbiddenNow});
  final DateTime day;
  final _Row row;
  final bool active;
  final bool next;
  final bool forbiddenNow;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final accent = context.colors.primary;
    final salah = row.salah;
    final trackable = salah != null && fardPrayers.contains(salah);
    final muted = context.tokens.muted;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
      decoration: BoxDecoration(
        color: active ? context.tokens.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? accent.withValues(alpha: 0.5) : (forbiddenNow ? AppColors.danger.withValues(alpha: 0.4) : Colors.transparent),
        ),
      ),
      child: Row(
        children: [
          IconTile(row.icon, size: 44, color: forbiddenNow ? AppColors.danger : (active ? AppColors.accentLight : null)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(row.name, style: TextStyle(fontSize: 16, fontWeight: active ? FontWeight.w700 : FontWeight.w600)),
                    if (active || next) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: active ? accent : accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          active ? 'Now' : 'Next',
                          style: TextStyle(color: active ? Colors.white : accent, fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  forbiddenNow ? 'Forbidden now' : row.subtitle,
                  style: TextStyle(fontSize: 12.5, color: forbiddenNow ? AppColors.danger : muted),
                ),
              ],
            ),
          ),
          Text(
            fmtTime(row.time),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.accentLight : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          if (trackable)
            Pressable(
              onTap: () => editMark(context, day, salah),
              onLongPress: () => editMark(context, day, salah, pick: true),
              scale: 0.85,
              child: SizedBox(
                width: 44,
                height: 40,
                child: Center(child: MarkDot(mark: state.markOf(day, salah), size: 30)),
              ),
            )
          else
            SizedBox(
              width: 44,
              child: Icon(salah == null ? Icons.block_rounded : Icons.remove_rounded, size: 22, color: muted.withValues(alpha: 0.6)),
            ),
        ],
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Panel(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconTile(icon, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.text.bodySmall),
                    const SizedBox(height: 2),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({required this.arabic, required this.meaning, required this.ref});
  final String arabic;
  final String meaning;
  final String ref;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(arabic, textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: arabicStyle(size: 24, height: 1.9)),
          const SizedBox(height: 12),
          Text(meaning, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, height: 1.5)),
          const SizedBox(height: 8),
          Text(ref, textAlign: TextAlign.center, style: TextStyle(color: context.colors.primary, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _NextEventCard extends StatelessWidget {
  const _NextEventCard({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final next = upcomingEvents(now, count: 1).first;
    final c = eventColor(context, next.event.kind);
    return Panel(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconTile(Icons.event_rounded, size: 40, color: c),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(next.event.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${next.event.day} ${hijriMonths[next.event.month - 1]} · ${relativeDays(next.date)}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Text('Calendar', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.primary),
        ],
      ),
    );
  }
}

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';

import '../services/prayer_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'location_sheet.dart';

const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// Location, method and Asr juristic setting.
Future<void> showCalcSettings(BuildContext context) => showSheet(context, (_) => const _CalcSheet());

class _CalcSheet extends StatelessWidget {
  const _CalcSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Prayer calculation', style: context.text.titleLarge?.copyWith(fontSize: 18)),
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: const Text('Location'),
              subtitle: Text(s.location.name, style: context.text.bodySmall),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => pickLocation(context),
            ),
            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('Method'),
              subtitle: Text(PrayerService.methods[s.method] ?? s.method.name, style: context.text.bodySmall),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final m = await showSheet<CalculationMethod>(
                  context,
                  (_) => OptionSheet(title: 'Calculation method', options: PrayerService.methods, selected: s.method),
                );
                if (m != null) s.setMethod(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Asr calculation'),
              subtitle: Text(s.madhab == Madhab.hanafi ? 'Hanafi (later Asr)' : 'Shafi, Maliki, Hanbali', style: context.text.bodySmall),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final m = await showSheet<Madhab>(
                  context,
                  (_) => OptionSheet(
                    title: 'Asr calculation',
                    options: const {Madhab.hanafi: 'Hanafi', Madhab.shafi: 'Shafi, Maliki, Hanbali'},
                    selected: s.madhab,
                  ),
                );
                if (m != null) s.setMadhab(m);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int m) => setState(() => _month = DateTime(_month.year, _month.month + m));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        actions: [
          IconButton(tooltip: 'Calculation settings', onPressed: () => showCalcSettings(context), icon: const Icon(Icons.tune_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
                  Expanded(
                    child: Column(
                      children: [
                        Text('${_monthNames[_month.month - 1]} ${_month.year}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(AppState.instance.location.name, style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _MonthTable(key: ValueKey(_month), month: _month),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthTable extends StatelessWidget {
  const _MonthTable({super.key, required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final now = DateTime.now();
    const cols = Salah.values;
    String short(DateTime t) {
      final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
      return '$h:${t.minute.toString().padLeft(2, '0')}';
    }

    final headStyle = TextStyle(color: context.tokens.muted, fontSize: 11.5, fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Panel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  SizedBox(width: 34, child: Text('Day', style: headStyle)),
                  for (final c in cols) Expanded(child: Text(c.label, textAlign: TextAlign.center, style: headStyle)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: days,
                itemBuilder: (context, i) {
                  final d = DateTime(month.year, month.month, i + 1);
                  final t = state.timesFor(d);
                  final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
                  final style = TextStyle(
                    fontSize: 12.5,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday ? context.colors.primary : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  );
                  return Container(
                    color: isToday ? context.tokens.accentSoft : (i.isOdd ? context.colors.surfaceContainerHighest.withValues(alpha: 0.5) : null),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(width: 34, child: Text('${i + 1}', style: style)),
                        for (final c in cols) Expanded(child: Text(short(t[c]), textAlign: TextAlign.center, style: style)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

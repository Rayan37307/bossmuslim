import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/prayer_service.dart';
import '../services/hijri.dart';
import '../services/quran_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'duas_screen.dart';
import 'location_sheet.dart';
import 'mosques_screen.dart';
import 'muslim_ai_screen.dart';
import 'calendar_screen.dart';
import 'timetable_screen.dart';
import 'tracker_screen.dart';

const _faq = [
  (
    'How are prayer times calculated?',
    'Times are calculated on your device from your coordinates using established astronomical methods. Choose the method used by your local mosque under Prayer → Calculation. No internet connection is required.',
  ),
  (
    'Why doesn\'t the Qur\'an include transliteration?',
    'Transliterating Arabic into Latin or Bengali script often changes pronunciation and, with it, meaning. We show the original Arabic with a translation and encourage learning to recite with tajweed.',
  ),
  (
    'Why is there no adhan sound for alarms?',
    'The adhan is a call to the congregation from the mosque. The app uses a clear, respectful notification tone to remind you of the prayer time instead.',
  ),
  (
    'Why is Isha shown until Fajr?',
    'The time for Isha extends until true dawn (Subh Sadiq), although it is preferable to pray it before the middle of the night. The Prayer tab shows the middle and last third of the night.',
  ),
  (
    'My alarms don\'t ring on time.',
    'Some phones restrict background apps. Allow notifications and "Alarms & reminders" for this app, and disable battery optimisation for it in your phone settings.',
  ),
];

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text('More', style: context.text.headlineMedium?.copyWith(fontSize: 26)),
            const SizedBox(height: 16),
            Row(
              children: [
                _tool(context, Icons.task_alt_rounded, 'Namaz Tracker', () => _push(context, const TrackerScreen())),
                const SizedBox(width: 12),
                _tool(context, Icons.event_note_outlined, 'Islamic Calendar', () => _push(context, const CalendarScreen())),
                const SizedBox(width: 12),
                _tool(context, Icons.auto_awesome_rounded, 'Muslim AI', () => _push(context, const MuslimAiScreen())),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _tool(context, Icons.calendar_month_outlined, 'Timetable', () => _push(context, const TimetableScreen())),
                const SizedBox(width: 12),
                _tool(context, Icons.volunteer_activism_outlined, 'Duas', () => _push(context, const DuasPage())),
                const SizedBox(width: 12),
                _tool(context, Icons.mosque_outlined, 'Mosques', () => _push(context, const MosquesScreen())),
              ],
            ),
            const SectionHeader('Alarms & reminders'),
            _group(context, [
              for (final p in Salah.values)
                SwitchListTile(
                  value: s.alarms[p] ?? false,
                  onChanged: (v) => s.setAlarm(p, v),
                  title: Text(p.label),
                  subtitle: p == Salah.sunrise ? Text('Marks the end of Fajr', style: context.text.bodySmall) : null,
                ),
              ListTile(
                title: const Text('Alert time'),
                subtitle: Text(s.alarmOffset == 0 ? 'At prayer time' : '${s.alarmOffset} minutes before', style: context.text.bodySmall),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final v = await showSheet<int>(
                    context,
                    (_) => OptionSheet(
                      title: 'Alert time',
                      options: const {0: 'At prayer time', 5: '5 minutes before', 10: '10 minutes before', 15: '15 minutes before', 30: '30 minutes before'},
                      selected: s.alarmOffset,
                    ),
                  );
                  if (v != null) s.setAlarmOffset(v);
                },
              ),
            ]),
            const SizedBox(height: 12),
            _group(context, [
              SwitchListTile(
                value: s.duroodReminder,
                onChanged: (v) => s.setDuroodReminder(v),
                title: const Text('Daily durood reminder'),
                subtitle: Text('Every day at ${s.duroodTime.format(context)}', style: context.text.bodySmall),
              ),
              if (s.duroodReminder)
                ListTile(
                  title: const Text('Reminder time'),
                  trailing: Text(s.duroodTime.format(context), style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: s.duroodTime);
                    if (t != null) s.setDuroodReminder(true, t);
                  },
                ),
              SwitchListTile(
                value: s.jumuahReminder,
                onChanged: s.setJumuahReminder,
                title: const Text('Jumu\'ah reminder'),
                subtitle: Text('Friday, one hour before Dhuhr', style: context.text.bodySmall),
              ),
              ListTile(
                title: const Text('Notification permission'),
                subtitle: Text('Grant if alarms aren\'t appearing', style: context.text.bodySmall),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await NotificationService.requestPermissions();
                  await s.reschedule();
                },
              ),
            ]),
            const SectionHeader('Prayer calculation'),
            _group(context, [
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
                  final m = await showSheet(context, (_) => OptionSheet(title: 'Calculation method', options: PrayerService.methods, selected: s.method));
                  if (m != null) s.setMethod(m);
                },
              ),
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('Asr calculation'),
                subtitle: Text(s.madhab.name == 'hanafi' ? 'Hanafi' : 'Shafi, Maliki, Hanbali', style: context.text.bodySmall),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showCalcSettings(context),
              ),
            ]),
            const SectionHeader('Qur\'an'),
            _group(context, [
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: const Text('Translation'),
                subtitle: Text(QuranService.translations[s.translation] ?? s.translation, style: context.text.bodySmall),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final v = await showSheet<String>(context, (_) => OptionSheet(title: 'Translation', options: QuranService.translations, selected: s.translation));
                  if (v != null) s.setTranslation(v);
                },
              ),
              ListTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Reciter'),
                subtitle: Text(QuranService.reciters[s.reciter] ?? s.reciter, style: context.text.bodySmall),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final v = await showSheet<String>(context, (_) => OptionSheet(title: 'Reciter', options: QuranService.reciters, selected: s.reciter));
                  if (v != null) s.setReciter(v);
                },
              ),
            ]),
            const SectionHeader('Hijri date'),
            _group(context, [
              ListTile(
                leading: const Icon(Icons.nightlight_outlined),
                title: Text(Hijri.of(DateTime.now()).toString()),
                subtitle: Text(
                  s.hijriOffset == 0 ? 'Umm al-Qura, no adjustment' : 'Adjusted ${s.hijriOffset > 0 ? '+' : ''}${s.hijriOffset} day${s.hijriOffset.abs() == 1 ? '' : 's'} for local moon sighting',
                  style: context.text.bodySmall,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: s.hijriOffset <= -2 ? null : () => s.setHijriOffset(s.hijriOffset - 1),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    IconButton(
                      onPressed: s.hijriOffset >= 2 ? null : () => s.setHijriOffset(s.hijriOffset + 1),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
              ),
            ]),
            const SectionHeader('Appearance'),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: context.tokens.accentSoft,
                selectedForegroundColor: context.colors.primary,
                side: BorderSide(color: context.tokens.border),
              ),
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined, size: 18)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined, size: 18)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined, size: 18)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.setThemeMode(v.first),
            ),
            const SectionHeader('Questions'),
            _group(context, [
              for (final q in _faq)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(q.$1, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedAlignment: Alignment.centerLeft,
                    iconColor: context.colors.primary,
                    children: [Text(q.$2, style: TextStyle(color: context.tokens.muted, height: 1.55))],
                  ),
                ),
            ]),
            const SizedBox(height: 28),
            Center(child: Text('Boss Muslim · v1.0.0', style: context.text.bodySmall)),
          ],
        ),
      ),
    );
  }

  Widget _tool(BuildContext context, IconData icon, String label, VoidCallback onTap) => Expanded(
        child: Panel(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              IconTile(icon, size: 42),
              const SizedBox(height: 10),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      );

  Widget _group(BuildContext context, List<Widget> children) => Panel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const Divider(indent: 16, endIndent: 16),
            ],
          ],
        ),
      );
}

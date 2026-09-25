import 'package:hijri/hijri_calendar.dart';

import '../state/app_state.dart';

class HijriDate {
  const HijriDate(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;

  String get monthName => hijriMonths[month - 1];
  String get monthArabic => hijriMonthsArabic[month - 1];

  @override
  String toString() => '$day $monthName $year AH';
}

const hijriMonths = [
  'Muharram', 'Safar', 'Rabi\' al-Awwal', 'Rabi\' al-Thani', 'Jumada al-Ula', 'Jumada al-Akhirah',
  'Rajab', 'Sha\'ban', 'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah',
];

const hijriMonthsArabic = [
  'مُحَرَّم', 'صَفَر', 'رَبِيع الأَوَّل', 'رَبِيع الآخِر', 'جُمَادَى الأُولَى', 'جُمَادَى الآخِرَة',
  'رَجَب', 'شَعْبَان', 'رَمَضَان', 'شَوَّال', 'ذُو القَعْدَة', 'ذُو الحِجَّة',
];

/// Umm al-Qura based conversion, shifted by the user's moon-sighting adjustment.
class Hijri {
  static final _cal = HijriCalendar();
  static int get _offset => AppState.instance.hijriOffset;

  static HijriDate of(DateTime g) {
    final h = HijriCalendar.fromDate(DateTime(g.year, g.month, g.day).add(Duration(days: _offset)));
    return HijriDate(h.hYear, h.hMonth, h.hDay);
  }

  static DateTime toGregorian(int year, int month, int day) {
    final g = _cal.hijriToGregorian(year, month, day);
    return DateTime(g.year, g.month, g.day).subtract(Duration(days: _offset));
  }

  static int daysInMonth(int year, int month) => _cal.getDaysInMonth(year, month);
}

enum EventKind { major, fasting, sacred }

class IslamicEvent {
  const IslamicEvent(this.month, this.day, this.name, this.description, this.kind, {this.days = 1});
  final int month;
  final int day;
  final String name;
  final String description;
  final EventKind kind;
  final int days; // span for multi-day events
}

const islamicEvents = [
  IslamicEvent(1, 1, 'Islamic New Year', 'The first day of Muharram begins the Hijri year.', EventKind.sacred),
  IslamicEvent(1, 9, 'Tasu\'a', 'Fasting on the 9th alongside Ashura is Sunnah.', EventKind.fasting),
  IslamicEvent(1, 10, 'Day of Ashura', 'Fasting expiates the sins of the previous year (Muslim 1162).', EventKind.fasting),
  IslamicEvent(9, 1, 'Ramadan begins', 'The month of fasting and the Qur\'an.', EventKind.major),
  IslamicEvent(9, 21, 'Last ten nights', 'Seek Laylat al-Qadr in the odd nights of the last ten.', EventKind.major, days: 10),
  IslamicEvent(10, 1, 'Eid al-Fitr', 'Celebration marking the end of Ramadan. Fasting is not permitted.', EventKind.major),
  IslamicEvent(12, 1, 'First ten days of Dhu al-Hijjah', 'The best days of the year for good deeds (Bukhari 969).', EventKind.sacred, days: 9),
  IslamicEvent(12, 8, 'Hajj begins', 'Day of Tarwiyah — pilgrims head to Mina.', EventKind.sacred),
  IslamicEvent(12, 9, 'Day of Arafah', 'Fasting expiates sins of the previous and coming year (Muslim 1162).', EventKind.fasting),
  IslamicEvent(12, 10, 'Eid al-Adha', 'The festival of sacrifice.', EventKind.major),
  IslamicEvent(12, 11, 'Days of Tashreeq', 'Days of eating, drinking and remembering Allah.', EventKind.sacred, days: 3),
];

/// Events that fall on a given Hijri day.
List<IslamicEvent> eventsOn(int month, int day) =>
    [for (final e in islamicEvents) if (e.month == month && day >= e.day && day < e.day + e.days) e];

/// The 13th–15th of each month are the "white days", Sunnah to fast (except 13 Dhu al-Hijjah).
bool isWhiteDay(int month, int day) => day >= 13 && day <= 15 && !(month == 12 && day == 13);

class UpcomingEvent {
  const UpcomingEvent(this.event, this.date, this.hijriYear);
  final IslamicEvent event;
  final DateTime date;
  final int hijriYear;
}

List<UpcomingEvent> upcomingEvents(DateTime from, {int count = 6}) {
  final today = DateTime(from.year, from.month, from.day);
  final h = Hijri.of(today);
  final out = <UpcomingEvent>[];
  for (final year in [h.year, h.year + 1]) {
    for (final e in islamicEvents) {
      final start = Hijri.toGregorian(year, e.month, e.day);
      final end = start.add(Duration(days: e.days - 1));
      if (!end.isBefore(today)) out.add(UpcomingEvent(e, start, year));
    }
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out.take(count).toList();
}

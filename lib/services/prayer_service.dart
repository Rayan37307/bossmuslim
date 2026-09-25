import 'package:adhan/adhan.dart';

enum Salah { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension SalahX on Salah {
  String get label => switch (this) {
        Salah.fajr => 'Fajr',
        Salah.sunrise => 'Sunrise',
        Salah.dhuhr => 'Dhuhr',
        Salah.asr => 'Asr',
        Salah.maghrib => 'Maghrib',
        Salah.isha => 'Isha',
      };

  String get arabic => switch (this) {
        Salah.fajr => 'الفجر',
        Salah.sunrise => 'الشروق',
        Salah.dhuhr => 'الظهر',
        Salah.asr => 'العصر',
        Salah.maghrib => 'المغرب',
        Salah.isha => 'العشاء',
      };

  bool get isPrayer => this != Salah.sunrise;
}

class TimeWindow {
  const TimeWindow(this.label, this.start, this.end);
  final String label;
  final DateTime start;
  final DateTime end;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

class DayTimes {
  DayTimes({required this.date, required this.times, required this.nextFajr, required this.midnight, required this.lastThird});

  final DateTime date;
  final Map<Salah, DateTime> times;
  final DateTime nextFajr;
  final DateTime midnight;
  final DateTime lastThird;

  DateTime operator [](Salah s) => times[s]!;

  DateTime get sehriEnds => times[Salah.fajr]!;
  DateTime get iftar => times[Salah.maghrib]!;

  /// Times in which voluntary prayer is disliked: while the sun rises,
  /// at its zenith, and while it sets.
  List<TimeWindow> get forbidden => [
        TimeWindow('Sunrise', this[Salah.sunrise], this[Salah.sunrise].add(const Duration(minutes: 15))),
        TimeWindow('Zawal (midday)', this[Salah.dhuhr].subtract(const Duration(minutes: 8)), this[Salah.dhuhr]),
        TimeWindow('Sunset', this[Salah.maghrib].subtract(const Duration(minutes: 15)), this[Salah.maghrib]),
      ];

  /// End of each prayer's window. Isha runs until Fajr (Subh Sadiq).
  DateTime endOf(Salah s) => switch (s) {
        Salah.fajr => this[Salah.sunrise],
        Salah.sunrise => this[Salah.dhuhr],
        Salah.dhuhr => this[Salah.asr],
        Salah.asr => this[Salah.maghrib],
        Salah.maghrib => this[Salah.isha],
        Salah.isha => nextFajr,
      };
}

class PrayerService {
  static const methods = <CalculationMethod, String>{
    CalculationMethod.karachi: 'University of Islamic Sciences, Karachi',
    CalculationMethod.muslim_world_league: 'Muslim World League',
    CalculationMethod.egyptian: 'Egyptian General Authority',
    CalculationMethod.umm_al_qura: 'Umm al-Qura, Makkah',
    CalculationMethod.north_america: 'ISNA (North America)',
    CalculationMethod.dubai: 'Dubai',
    CalculationMethod.kuwait: 'Kuwait',
    CalculationMethod.qatar: 'Qatar',
    CalculationMethod.singapore: 'Singapore',
    CalculationMethod.turkey: 'Diyanet, Turkey',
    CalculationMethod.tehran: 'Institute of Geophysics, Tehran',
    CalculationMethod.moon_sighting_committee: 'Moonsighting Committee',
  };

  static DayTimes compute({
    required double lat,
    required double lng,
    required DateTime date,
    required CalculationMethod method,
    required Madhab madhab,
  }) {
    final coords = Coordinates(lat, lng);
    final params = method.getParameters()..madhab = madhab;
    final day = DateTime(date.year, date.month, date.day);
    final pt = PrayerTimes(coords, DateComponents.from(day), params);
    final next = PrayerTimes(coords, DateComponents.from(day.add(const Duration(days: 1))), params);
    final sunnah = SunnahTimes(pt);
    return DayTimes(
      date: day,
      times: {
        Salah.fajr: pt.fajr.toLocal(),
        Salah.sunrise: pt.sunrise.toLocal(),
        Salah.dhuhr: pt.dhuhr.toLocal(),
        Salah.asr: pt.asr.toLocal(),
        Salah.maghrib: pt.maghrib.toLocal(),
        Salah.isha: pt.isha.toLocal(),
      },
      nextFajr: next.fajr.toLocal(),
      midnight: sunnah.middleOfTheNight.toLocal(),
      lastThird: sunnah.lastThirdOfTheNight.toLocal(),
    );
  }

  static double qibla(double lat, double lng) => Qibla(Coordinates(lat, lng)).direction;
}

/// Snapshot of "where are we now" relative to the prayer schedule.
class PrayerStatus {
  PrayerStatus({required this.current, required this.currentEnds, required this.next, required this.nextAt});

  final Salah? current;
  final DateTime? currentEnds;
  final Salah next;
  final DateTime nextAt;

  static PrayerStatus of(DayTimes yesterday, DayTimes today, DayTimes tomorrow, DateTime now) {
    // Before today's Fajr we're still inside yesterday's Isha.
    if (now.isBefore(today[Salah.fajr])) {
      return PrayerStatus(
        current: now.isBefore(yesterday[Salah.isha]) ? null : Salah.isha,
        currentEnds: today[Salah.fajr],
        next: Salah.fajr,
        nextAt: today[Salah.fajr],
      );
    }
    Salah? current;
    for (final s in Salah.values) {
      if (!now.isBefore(today[s])) current = s;
    }
    final idx = current!.index;
    if (idx == Salah.isha.index) {
      return PrayerStatus(current: Salah.isha, currentEnds: tomorrow[Salah.fajr], next: Salah.fajr, nextAt: tomorrow[Salah.fajr]);
    }
    final next = Salah.values[idx + 1];
    return PrayerStatus(
      current: current == Salah.sunrise ? null : current,
      currentEnds: current == Salah.sunrise ? null : today.endOf(current),
      next: next,
      nextAt: today[next],
    );
  }
}

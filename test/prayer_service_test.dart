import 'package:adhan/adhan.dart';
import 'package:bossmuslim/services/prayer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DayTimes day(DateTime d) => PrayerService.compute(
        lat: 23.8103,
        lng: 90.4125,
        date: d,
        method: CalculationMethod.karachi,
        madhab: Madhab.hanafi,
      );

  final today = DateTime(2026, 9, 25);
  final y = day(today.subtract(const Duration(days: 1)));
  final t = day(today);
  final tm = day(today.add(const Duration(days: 1)));

  test('times are in order', () {
    for (var i = 1; i < Salah.values.length; i++) {
      expect(t[Salah.values[i]].isAfter(t[Salah.values[i - 1]]), isTrue);
    }
    expect(t.nextFajr.isAfter(t[Salah.isha]), isTrue);
    expect(t.lastThird.isAfter(t.midnight), isTrue);
  });

  test('after midnight we are still in Isha, next is Fajr', () {
    final s = PrayerStatus.of(y, t, tm, DateTime(2026, 9, 25, 1, 30));
    expect(s.current, Salah.isha);
    expect(s.next, Salah.fajr);
    expect(s.nextAt, t[Salah.fajr]);
  });

  test('between sunrise and dhuhr there is no current prayer', () {
    final s = PrayerStatus.of(y, t, tm, t[Salah.sunrise].add(const Duration(minutes: 30)));
    expect(s.current, isNull);
    expect(s.next, Salah.dhuhr);
  });

  test('during asr, ends at maghrib', () {
    final s = PrayerStatus.of(y, t, tm, t[Salah.asr].add(const Duration(minutes: 1)));
    expect(s.current, Salah.asr);
    expect(s.currentEnds, t[Salah.maghrib]);
    expect(s.next, Salah.maghrib);
  });

  test('late evening isha rolls to tomorrow fajr', () {
    final s = PrayerStatus.of(y, t, tm, t[Salah.isha].add(const Duration(hours: 1)));
    expect(s.current, Salah.isha);
    expect(s.nextAt, tm[Salah.fajr]);
  });

  test('forbidden windows sit around sunrise, zawal and sunset', () {
    final f = t.forbidden;
    expect(f[0].start, t[Salah.sunrise]);
    expect(f[1].end, t[Salah.dhuhr]);
    expect(f[2].end, t[Salah.maghrib]);
  });

  test('qibla from Dhaka is roughly west-northwest', () {
    final q = PrayerService.qibla(23.8103, 90.4125);
    expect(q, inInclusiveRange(275, 280));
  });
}

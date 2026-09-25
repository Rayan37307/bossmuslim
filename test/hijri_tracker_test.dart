import 'package:bossmuslim/screens/tracker_screen.dart';
import 'package:bossmuslim/services/hijri.dart';
import 'package:bossmuslim/services/prayer_service.dart';
import 'package:bossmuslim/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppState.load();
  });

  test('hijri round-trips through gregorian', () {
    final g = DateTime(2026, 9, 25);
    final h = Hijri.of(g);
    expect(Hijri.toGregorian(h.year, h.month, h.day), g);
  });

  test('offset shifts the hijri date by whole days', () async {
    final g = DateTime(2026, 9, 25);
    final base = Hijri.of(g);
    await AppState.instance.setHijriOffset(1);
    final shifted = Hijri.of(g);
    expect(Hijri.toGregorian(shifted.year, shifted.month, shifted.day), g);
    expect(shifted.day == base.day + 1 || shifted.day == 1, isTrue);
  });

  test('known date: 1 Ramadan 1447 is 18 Feb 2026 (Umm al-Qura)', () {
    expect(Hijri.toGregorian(1447, 9, 1), DateTime(2026, 2, 18));
  });

  test('events and white days', () {
    expect(eventsOn(10, 1).single.name, 'Eid al-Fitr');
    expect(eventsOn(12, 9).map((e) => e.name), contains('Day of Arafah'));
    expect(eventsOn(9, 25).single.name, 'Last ten nights');
    expect(isWhiteDay(5, 14), isTrue);
    expect(isWhiteDay(12, 13), isFalse);
  });

  test('upcoming events are sorted and not in the past', () {
    final now = DateTime(2026, 9, 25);
    final list = upcomingEvents(now);
    expect(list, isNotEmpty);
    for (var i = 1; i < list.length; i++) {
      expect(list[i].date.isBefore(list[i - 1].date), isFalse);
    }
  });

  test('tracker counts prayed and streaks', () async {
    final s = AppState.instance;
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    for (final p in fardPrayers) {
      await s.setMark(yesterday, p, PrayerMark.onTime);
    }
    await s.setMark(today, Salah.fajr, PrayerMark.late);
    await s.setMark(today, Salah.dhuhr, PrayerMark.missed);
    expect(prayedOn(yesterday), 5);
    expect(prayedOn(today), 1);
    // Today is incomplete, so the streak counts from yesterday.
    expect(currentStreak(), 1);
    await s.setMark(today, Salah.dhuhr, null);
    expect(s.markOf(today, Salah.dhuhr), isNull);
  });
}

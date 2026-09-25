import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../services/prayer_service.dart';

class SavedLocation {
  const SavedLocation(this.lat, this.lng, this.name);
  final double lat;
  final double lng;
  final String name;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'name': name};
  factory SavedLocation.fromJson(Map<String, dynamic> j) =>
      SavedLocation((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble(), j['name'] as String);

  // Sensible default until the user shares a location.
  static const dhaka = SavedLocation(23.8103, 90.4125, 'Dhaka, Bangladesh');
}

/// How a fard prayer was performed, as logged in the tracker.
enum PrayerMark { onTime, late, missed }

class Bookmark {
  const Bookmark(this.surah, this.ayah, this.surahName);
  final int surah;
  final int ayah;
  final String surahName;

  String get key => '$surah:$ayah';
  Map<String, dynamic> toJson() => {'s': surah, 'a': ayah, 'n': surahName};
  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(j['s'], j['a'], j['n']);
}

/// One dhikr counter. [count] runs across rounds; [total] survives resets.
class TasbihItem {
  TasbihItem({required this.name, this.arabic = '', this.target = 33, this.count = 0, this.total = 0});
  String name;
  String arabic;
  int target; // 0 = no goal
  int count;
  int total;

  int get rounds => target == 0 ? 0 : count ~/ target;
  int get inRound => target == 0 ? count : count % target;

  Map<String, dynamic> toJson() => {'n': name, 'a': arabic, 't': target, 'c': count, 'tot': total};
  factory TasbihItem.fromJson(Map<String, dynamic> j) =>
      TasbihItem(name: j['n'], arabic: j['a'] ?? '', target: j['t'] ?? 33, count: j['c'] ?? 0, total: j['tot'] ?? 0);
}

/// Counters a fresh install starts with.
const defaultTasbihs = [
  ('SubhanAllah', 'سُبْحَانَ اللَّهِ', 33),
  ('Alhamdulillah', 'الْحَمْدُ لِلَّهِ', 33),
  ('Allahu Akbar', 'اللَّهُ أَكْبَرُ', 34),
  ('Astaghfirullah', 'أَسْتَغْفِرُ اللَّهَ', 100),
];

/// Single source of truth for user settings, persisted to SharedPreferences.
class AppState extends ChangeNotifier {
  AppState._(this._prefs);
  static late AppState instance;

  final SharedPreferences _prefs;

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    instance = AppState._(prefs).._read();
    return instance;
  }

  // ---- Settings ----
  late SavedLocation location;
  late CalculationMethod method;
  late Madhab madhab;
  late ThemeMode themeMode;
  late Map<Salah, bool> alarms;
  late int alarmOffset; // minutes before the adhan time
  late bool duroodReminder;
  late TimeOfDay duroodTime;
  late bool jumuahReminder;
  late bool onboarded;

  // Quran
  late String translation; // alquran.cloud edition id, or '' for none
  late String reciter;
  late double arabicSize;
  late List<Bookmark> bookmarks;
  Bookmark? lastRead;

  // Tasbih
  late List<TasbihItem> tasbihs;
  late int tasbihIndex;
  late int tasbihBead; // index into the bead colour palette
  late Map<String, int> tasbihDaily; // 'yyyy-mm-dd' -> count
  late bool tasbihVibrate;
  late bool tasbihSound;

  // Namaz tracker: 'yyyy-mm-dd' -> {salah name -> PrayerMark name}
  late Map<String, Map<String, String>> prayerLog;

  // Days added to the computed Hijri date to match local moon sighting.
  late int hijriOffset;

  // Duas: custom list name -> dua ids
  late Map<String, List<String>> duaLists;

  void _read() {
    final p = _prefs;
    final loc = p.getString('location');
    location = loc == null ? SavedLocation.dhaka : SavedLocation.fromJson(jsonDecode(loc));
    method = CalculationMethod.values.firstWhere((m) => m.name == p.getString('method'),
        orElse: () => CalculationMethod.karachi);
    madhab = p.getString('madhab') == 'shafi' ? Madhab.shafi : Madhab.hanafi;
    themeMode = ThemeMode.values.firstWhere((m) => m.name == p.getString('theme'), orElse: () => ThemeMode.system);
    alarms = {
      for (final s in Salah.values) s: p.getBool('alarm_${s.name}') ?? s.isPrayer,
    };
    alarmOffset = p.getInt('alarmOffset') ?? 0;
    duroodReminder = p.getBool('durood') ?? true;
    duroodTime = TimeOfDay(hour: p.getInt('duroodH') ?? 21, minute: p.getInt('duroodM') ?? 0);
    jumuahReminder = p.getBool('jumuah') ?? true;
    onboarded = p.getBool('onboarded') ?? false;

    translation = p.getString('translation') ?? 'en.sahih';
    reciter = p.getString('reciter') ?? 'ar.alafasy';
    arabicSize = p.getDouble('arabicSize') ?? 28;
    bookmarks = (p.getStringList('bookmarks') ?? [])
        .map((e) => Bookmark.fromJson(jsonDecode(e)))
        .toList();
    final lr = p.getString('lastRead');
    lastRead = lr == null ? null : Bookmark.fromJson(jsonDecode(lr));

    final items = p.getString('tasbihItems');
    if (items != null) {
      tasbihs = (jsonDecode(items) as List).map((e) => TasbihItem.fromJson(e)).toList();
    } else {
      // Seed defaults, carrying over the count from the old single counter.
      final oldPhrase = p.getString('tasbihPhrase');
      tasbihs = [
        for (final d in defaultTasbihs)
          TasbihItem(
            name: d.$1,
            arabic: d.$2,
            target: d.$3,
            count: d.$1 == oldPhrase ? p.getInt('tasbihCount') ?? 0 : 0,
            total: d.$1 == oldPhrase ? p.getInt('tasbihTotal') ?? 0 : 0,
          ),
      ];
    }
    if (tasbihs.isEmpty) tasbihs = [TasbihItem(name: defaultTasbihs.first.$1, arabic: defaultTasbihs.first.$2)];
    tasbihIndex = (p.getInt('tasbihIndex') ?? 0).clamp(0, tasbihs.length - 1);
    tasbihBead = p.getInt('tasbihBead') ?? 2;
    tasbihVibrate = p.getBool('tasbihVibrate') ?? true;
    tasbihSound = p.getBool('tasbihSound') ?? false;
    final log = p.getString('prayerLog');
    prayerLog = log == null
        ? {}
        : (jsonDecode(log) as Map<String, dynamic>).map((k, v) => MapEntry(k, Map<String, String>.from(v)));
    hijriOffset = p.getInt('hijriOffset') ?? 0;
    final daily = p.getString('tasbihDaily');
    tasbihDaily = daily == null ? {} : Map<String, int>.from(jsonDecode(daily));

    final lists = p.getString('duaLists');
    duaLists = lists == null
        ? {'Favorites': <String>[]}
        : (jsonDecode(lists) as Map<String, dynamic>).map((k, v) => MapEntry(k, List<String>.from(v)));
  }

  // ---- Prayer times ----
  final _timesCache = <String, DayTimes>{};

  DayTimes timesFor(DateTime date) => _timesCache.putIfAbsent(
        '${date.year}-${date.month}-${date.day}',
        () => PrayerService.compute(lat: location.lat, lng: location.lng, date: date, method: method, madhab: madhab),
      );


  PrayerStatus statusAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return PrayerStatus.of(
      timesFor(today.subtract(const Duration(days: 1))),
      timesFor(today),
      timesFor(today.add(const Duration(days: 1))),
      now,
    );
  }

  Future<void> reschedule() => NotificationService.scheduleAll(this);

  // ---- Mutations ----
  Future<void> setLocation(SavedLocation l) async {
    location = l;
    _timesCache.clear();
    await _prefs.setString('location', jsonEncode(l.toJson()));
    notifyListeners();
    reschedule();
  }

  Future<void> setMethod(CalculationMethod m) async {
    method = m;
    _timesCache.clear();
    await _prefs.setString('method', m.name);
    notifyListeners();
    reschedule();
  }

  Future<void> setMadhab(Madhab m) async {
    madhab = m;
    _timesCache.clear();
    await _prefs.setString('madhab', m.name);
    notifyListeners();
    reschedule();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await _prefs.setString('theme', m.name);
    notifyListeners();
  }

  Future<void> setAlarm(Salah s, bool on) async {
    alarms[s] = on;
    await _prefs.setBool('alarm_${s.name}', on);
    notifyListeners();
    reschedule();
  }

  Future<void> setAlarmOffset(int minutes) async {
    alarmOffset = minutes;
    await _prefs.setInt('alarmOffset', minutes);
    notifyListeners();
    reschedule();
  }

  Future<void> setDuroodReminder(bool on, [TimeOfDay? time]) async {
    duroodReminder = on;
    if (time != null) duroodTime = time;
    await _prefs.setBool('durood', on);
    await _prefs.setInt('duroodH', duroodTime.hour);
    await _prefs.setInt('duroodM', duroodTime.minute);
    notifyListeners();
    reschedule();
  }

  Future<void> setJumuahReminder(bool on) async {
    jumuahReminder = on;
    await _prefs.setBool('jumuah', on);
    notifyListeners();
    reschedule();
  }

  Future<void> completeOnboarding() async {
    onboarded = true;
    await _prefs.setBool('onboarded', true);
    notifyListeners();
  }

  Future<void> setTranslation(String t) async {
    translation = t;
    await _prefs.setString('translation', t);
    notifyListeners();
  }

  Future<void> setReciter(String r) async {
    reciter = r;
    await _prefs.setString('reciter', r);
    notifyListeners();
  }

  Future<void> setArabicSize(double s) async {
    arabicSize = s;
    await _prefs.setDouble('arabicSize', s);
    notifyListeners();
  }

  bool isBookmarked(int surah, int ayah) => bookmarks.any((b) => b.surah == surah && b.ayah == ayah);

  Future<void> toggleBookmark(Bookmark b) async {
    if (isBookmarked(b.surah, b.ayah)) {
      bookmarks.removeWhere((x) => x.key == b.key);
    } else {
      bookmarks.insert(0, b);
    }
    await _prefs.setStringList('bookmarks', bookmarks.map((b) => jsonEncode(b.toJson())).toList());
    notifyListeners();
  }

  Future<void> setLastRead(Bookmark b) async {
    lastRead = b;
    await _prefs.setString('lastRead', jsonEncode(b.toJson()));
    notifyListeners();
  }

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int tasbihOn(DateTime d) => tasbihDaily[dayKey(d)] ?? 0;

  TasbihItem get tasbih => tasbihs[tasbihIndex];

  Future<void> _saveTasbihs() async {
    notifyListeners();
    await _prefs.setString('tasbihItems', jsonEncode([for (final t in tasbihs) t.toJson()]));
    await _prefs.setInt('tasbihIndex', tasbihIndex);
  }

  Future<void> tasbihTap() async {
    tasbih
      ..count += 1
      ..total += 1;
    final key = dayKey(DateTime.now());
    tasbihDaily[key] = (tasbihDaily[key] ?? 0) + 1;
    notifyListeners(); // before any await, so the bead animation sees the new count this frame
    if (tasbihDaily.length > 60) {
      // Keep roughly two months of history.
      final keys = tasbihDaily.keys.toList()..sort();
      for (final k in keys.take(tasbihDaily.length - 60)) {
        tasbihDaily.remove(k);
      }
    }
    await _prefs.setString('tasbihDaily', jsonEncode(tasbihDaily));
    await _saveTasbihs();
  }

  /// Takes back the last count, e.g. after an accidental swipe.
  Future<void> tasbihUndo() async {
    if (tasbih.count == 0) return;
    tasbih
      ..count -= 1
      ..total = (tasbih.total - 1).clamp(0, tasbih.total);
    notifyListeners();
    final key = dayKey(DateTime.now());
    if ((tasbihDaily[key] ?? 0) > 0) {
      tasbihDaily[key] = tasbihDaily[key]! - 1;
      await _prefs.setString('tasbihDaily', jsonEncode(tasbihDaily));
    }
    await _saveTasbihs();
  }

  Future<void> tasbihReset() async {
    tasbih.count = 0;
    await _saveTasbihs();
  }

  Future<void> selectTasbih(int i) async {
    if (i == tasbihIndex) return;
    tasbihIndex = i;
    await _saveTasbihs();
  }

  Future<void> addTasbih(TasbihItem t) async {
    tasbihs.add(t);
    tasbihIndex = tasbihs.length - 1;
    await _saveTasbihs();
  }

  Future<void> updateTasbih(int i, {required String name, required String arabic, required int target}) async {
    tasbihs[i]
      ..name = name
      ..arabic = arabic
      ..target = target;
    await _saveTasbihs();
  }

  Future<void> deleteTasbih(int i) async {
    if (tasbihs.length <= 1) return;
    tasbihs.removeAt(i);
    tasbihIndex = tasbihIndex.clamp(0, tasbihs.length - 1);
    await _saveTasbihs();
  }

  Future<void> setTasbihBead(int i) async {
    tasbihBead = i;
    notifyListeners();
    await _prefs.setInt('tasbihBead', i);
  }

  Future<void> setTasbihFeedback({bool? vibrate, bool? sound}) async {
    if (vibrate != null) tasbihVibrate = vibrate;
    if (sound != null) tasbihSound = sound;
    await _prefs.setBool('tasbihVibrate', tasbihVibrate);
    await _prefs.setBool('tasbihSound', tasbihSound);
    notifyListeners();
  }

  // ---- Namaz tracker ----
  PrayerMark? markOf(DateTime day, Salah s) {
    final v = prayerLog[dayKey(day)]?[s.name];
    return v == null ? null : PrayerMark.values.byName(v);
  }

  Future<void> setMark(DateTime day, Salah s, PrayerMark? mark) async {
    final key = dayKey(day);
    final entry = prayerLog.putIfAbsent(key, () => {});
    mark == null ? entry.remove(s.name) : entry[s.name] = mark.name;
    if (entry.isEmpty) prayerLog.remove(key);
    notifyListeners();
    await _prefs.setString('prayerLog', jsonEncode(prayerLog));
  }

  Future<void> setHijriOffset(int days) async {
    hijriOffset = days;
    await _prefs.setInt('hijriOffset', days);
    notifyListeners();
  }

  Future<void> _saveDuaLists() async {
    await _prefs.setString('duaLists', jsonEncode(duaLists));
    notifyListeners();
  }

  bool isInAnyList(String duaId) => duaLists.values.any((l) => l.contains(duaId));

  Future<void> toggleDuaInList(String list, String duaId) async {
    final l = duaLists.putIfAbsent(list, () => []);
    l.contains(duaId) ? l.remove(duaId) : l.add(duaId);
    await _saveDuaLists();
  }

  Future<void> createDuaList(String name) async {
    duaLists.putIfAbsent(name, () => []);
    await _saveDuaLists();
  }

  Future<void> deleteDuaList(String name) async {
    duaLists.remove(name);
    await _saveDuaLists();
  }
}

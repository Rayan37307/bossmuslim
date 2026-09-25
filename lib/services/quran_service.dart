import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class SurahInfo {
  const SurahInfo({
    required this.number,
    required this.name,
    required this.englishName,
    required this.meaning,
    required this.ayahs,
    required this.meccan,
  });

  final int number;
  final String name;
  final String englishName;
  final String meaning;
  final int ayahs;
  final bool meccan;

  factory SurahInfo.fromJson(Map<String, dynamic> j) => SurahInfo(
        number: j['number'],
        name: j['name'],
        englishName: j['englishName'],
        meaning: j['englishNameTranslation'],
        ayahs: j['numberOfAyahs'],
        meccan: j['revelationType'] == 'Meccan',
      );
}

class Ayah {
  const Ayah({required this.number, required this.inSurah, required this.arabic, this.translation, required this.juz, required this.sajda});

  /// Global ayah number (1–6236), used for audio URLs.
  final int number;
  final int inSurah;
  final String arabic;
  final String? translation;
  final int juz;
  final bool sajda;
}

class QuranService {
  static const _base = 'https://api.alquran.cloud/v1';

  static const translations = <String, String>{
    'en.sahih': 'English — Saheeh International',
    'en.maududi': 'English — Maududi (Tafhim)',
    'bn.bengali': 'বাংলা — Muhiuddin Khan',
    'bn.hoque': 'বাংলা — Zohurul Hoque',
    'ur.jalandhry': 'اردو — Jalandhry',
    'id.indonesian': 'Indonesian — Kemenag',
    '': 'Arabic only',
  };

  static const reciters = <String, String>{
    'ar.alafasy': 'Mishary Rashid Alafasy',
    'ar.abdurrahmaansudais': 'Abdurrahmaan As-Sudais',
    'ar.husary': 'Mahmoud Khalil Al-Husary',
    'ar.mahermuaiqly': 'Maher Al-Muaiqly',
    'ar.minshawi': 'Mohamed Siddiq El-Minshawi',
    'ar.saoodshuraym': 'Saood Ash-Shuraym',
  };

  static String audioUrl(String reciter, int globalAyah) =>
      'https://cdn.islamic.network/quran/audio/128/$reciter/$globalAyah.mp3';

  static List<SurahInfo>? _surahCache;

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/quran');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Network-first with a disk cache so previously opened surahs work offline.
  static Future<dynamic> _getJson(String path, String cacheKey) async {
    File? cache;
    if (!kIsWeb) {
      cache = File('${(await _dir()).path}/$cacheKey.json');
      if (await cache.exists()) return jsonDecode(await cache.readAsString());
    }
    final res = await http.get(Uri.parse('$_base$path')).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw HttpException('Server returned ${res.statusCode}');
    final body = utf8.decode(res.bodyBytes);
    final data = jsonDecode(body)['data'];
    await cache?.writeAsString(jsonEncode(data));
    return data;
  }

  static Future<List<SurahInfo>> surahs() async {
    if (_surahCache != null) return _surahCache!;
    final data = await _getJson('/surah', 'surahs') as List;
    return _surahCache = data.map((e) => SurahInfo.fromJson(e)).toList();
  }

  static Future<List<Ayah>> surah(int number, String translation) async {
    final editions = ['quran-uthmani', if (translation.isNotEmpty) translation].join(',');
    final data = await _getJson('/surah/$number/editions/$editions', 'surah_${number}_${translation.isEmpty ? 'ar' : translation}') as List;
    final arabic = data[0]['ayahs'] as List;
    final trans = data.length > 1 ? data[1]['ayahs'] as List : null;
    return [
      for (var i = 0; i < arabic.length; i++)
        Ayah(
          number: arabic[i]['number'],
          inSurah: arabic[i]['numberInSurah'],
          arabic: _stripBismillah(number, arabic[i]['numberInSurah'], arabic[i]['text']),
          translation: trans?[i]['text'],
          juz: arabic[i]['juz'],
          sajda: arabic[i]['sajda'] != false,
        ),
    ];
  }

  // The API prefixes ayah 1 of every surah (except Al-Fatiha and At-Tawbah) with
  // the bismillah. We show it as a separate header instead.
  static const _bismillahPrefix = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
  static String _stripBismillah(int surah, int ayah, String text) {
    final t = text.replaceFirst('﻿', '');
    if (surah == 1 || ayah != 1 || !t.startsWith(_bismillahPrefix)) return t;
    return t.substring(_bismillahPrefix.length).trim();
  }
}

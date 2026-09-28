import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A Quran verse or hadith whose text was fetched from a public dataset, not written by the model.
class AiSource {
  const AiSource({
    required this.id,
    required this.isQuran,
    required this.title,
    required this.arabic,
    required this.english,
    required this.url,
    this.grade,
  });

  final int id; // the [n] the answer cites
  final bool isQuran;
  final String title; // e.g. "Quran 2:153" or "Sahih al-Bukhari 1"
  final String arabic;
  final String english;
  final String url;
  final String? grade;
}

class AiAnswer {
  const AiAnswer(this.text, this.sources);
  final String text;
  final List<AiSource> sources;
}

class AiTurn {
  const AiTurn(this.fromUser, this.text);
  final bool fromUser;
  final String text;
}

class MuslimAiException implements Exception {
  const MuslimAiException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum AiStage { searching, verifying, writing }

/// Free AI providers the user can bring a key for.
enum AiProvider {
  gemini('Google Gemini', 'https://aistudio.google.com/apikey', 'AIza…'),
  groq('Groq', 'https://console.groq.com/keys', 'gsk_…'),
  openrouter('OpenRouter', 'https://openrouter.ai/keys', 'sk-or-…');

  const AiProvider(this.label, this.keyUrl, this.keyHint);
  final String label;
  final String keyUrl;
  final String keyHint;
}

/// Answers questions from the Quran and hadith using a free AI provider.
///
/// Two passes keep answers grounded: the model first names candidate verses and
/// hadith, the app fetches their real text, then the model answers using only
/// the fetched text and cites it.
class MuslimAiService {
  static const _gemini = 'https://generativelanguage.googleapis.com/v1beta';
  static const _geminiModel = 'models/gemini-2.5-flash-lite';
  static const _hadithCdn = 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions';
  static const _timeout = Duration(seconds: 40);

  static const collections = <String, String>{
    'bukhari': 'Sahih al-Bukhari',
    'muslim': 'Sahih Muslim',
    'abudawud': 'Sunan Abi Dawud',
    'tirmidhi': "Jami' at-Tirmidhi",
    'nasai': "Sunan an-Nasa'i",
    'ibnmajah': 'Sunan Ibn Majah',
    'malik': "Muwatta Malik",
    'nawawi': "An-Nawawi's Forty",
    'qudsi': 'Forty Hadith Qudsi',
  };

  static final _models = <AiProvider, String>{};

  static Future<Map<String, dynamic>> _getJson(Uri uri, {Map<String, String>? headers}) async {
    final r = await http.get(uri, headers: headers).timeout(_timeout);
    if (r.statusCode != 200) throw http.ClientException('HTTP ${r.statusCode}', uri);
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  static MuslimAiException _apiError(AiProvider p, int status, String body) {
    String msg = '';
    try {
      final e = jsonDecode(body)['error'];
      msg = (e is Map ? e['message'] as String? : e as String?) ?? '';
    } catch (_) {}
    final name = p.label;
    if (status == 401 || (status == 400 && msg.contains('API key'))) {
      return MuslimAiException('That $name API key is not valid. Check it in Muslim AI settings.');
    }
    if (status == 402) return MuslimAiException('$name says this key has no credit left. Free models should not need credit; try again or switch provider.');
    if (status == 403) return MuslimAiException('This key is not allowed to use $name. Create a new key at ${Uri.parse(p.keyUrl).host}.');
    if (status == 429) return MuslimAiException('The free $name limit was reached. Wait a minute and try again, or switch provider in settings.');
    if (status >= 500) return MuslimAiException('$name is busy right now. Please try again shortly.');
    return MuslimAiException(msg.isEmpty ? '$name returned an error ($status).' : msg);
  }

  static Map<String, String> _headers(AiProvider p, String key) => switch (p) {
        AiProvider.gemini => {'x-goog-api-key': key, 'content-type': 'application/json'},
        AiProvider.groq => {'authorization': 'Bearer $key', 'content-type': 'application/json'},
        AiProvider.openrouter => {
            'authorization': 'Bearer $key',
            'content-type': 'application/json',
            'x-title': 'BossMuslim',
          },
      };

  static String _chatUrl(AiProvider p) => switch (p) {
        AiProvider.groq => 'https://api.groq.com/openai/v1/chat/completions',
        _ => 'https://openrouter.ai/api/v1/chat/completions',
      };

  /// Picks the model to use; Groq comes from its live list so the app keeps working as models are retired.
  static Future<String> _pickModel(AiProvider p, String key) async {
    final cached = _models[p];
    if (cached != null) return cached;
    switch (p) {
      case AiProvider.gemini:
        // Fetching the model also validates the key.
        final r = await http.get(Uri.parse('$_gemini/$_geminiModel'), headers: _headers(p, key)).timeout(_timeout);
        if (r.statusCode != 200) throw _apiError(p, r.statusCode, r.body);
        return _models[p] = _geminiModel;
      case AiProvider.groq:
        final r = await http.get(Uri.parse('https://api.groq.com/openai/v1/models'), headers: _headers(p, key)).timeout(_timeout);
        if (r.statusCode != 200) throw _apiError(p, r.statusCode, r.body);
        final ids = [
          for (final m in (jsonDecode(r.body)['data'] as List? ?? []))
            if (m['active'] != false && !RegExp(r'whisper|guard|tts|orpheus|playai|distil|safeguard').hasMatch(m['id'] as String)) m['id'] as String,
        ];
        const preferred = ['gpt-oss-120b', 'llama-3.3-70b', 'kimi-k2', 'llama-4-maverick', 'qwen3', 'llama-4', 'gpt-oss', 'llama'];
        for (final want in preferred) {
          final hit = ids.where((id) => id.contains(want)).firstOrNull;
          if (hit != null) return _models[p] = hit;
        }
        if (ids.isEmpty) throw const MuslimAiException('No Groq chat models are available for this key.');
        return _models[p] = ids.first;
      case AiProvider.openrouter:
        // Validates the key; free models are then reached through OpenRouter's free router.
        var r = await http.get(Uri.parse('https://openrouter.ai/api/v1/key'), headers: _headers(p, key)).timeout(_timeout);
        if (r.statusCode == 404) {
          r = await http.get(Uri.parse('https://openrouter.ai/api/v1/auth/key'), headers: _headers(p, key)).timeout(_timeout);
        }
        if (r.statusCode != 200) throw _apiError(p, r.statusCode, r.body);
        return _models[p] = 'openrouter/free';
    }
  }

  /// Checks that a key works before saving it.
  static Future<void> verifyKey(AiProvider p, String key) async {
    _models.remove(p);
    await _pickModel(p, key);
  }

  /// Gemini schema types are upper-case; JSON Schema's are lower-case.
  static Object? _jsonSchema(Object? v) {
    if (v is Map) return {for (final e in v.entries) e.key: e.key == 'type' ? (e.value as String).toLowerCase() : _jsonSchema(e.value)};
    if (v is List) return v.map(_jsonSchema).toList();
    return v;
  }

  static Map<String, dynamic> _parseJson(String text) {
    var t = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
    final start = t.indexOf('{'), end = t.lastIndexOf('}');
    if (start >= 0 && end > start) t = t.substring(start, end + 1);
    try {
      return jsonDecode(t) as Map<String, dynamic>;
    } catch (_) {
      throw const MuslimAiException('The answer came back in an unexpected format. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> _generate(
    AiProvider p,
    String key, {
    required String system,
    required List<AiTurn> turns,
    required Map<String, dynamic> schema,
  }) async {
    final model = await _pickModel(p, key);
    if (p == AiProvider.gemini) return _generateGemini(key, model, system, turns, schema);

    final jsonSchema = _jsonSchema(schema);
    final messages = [
      {'role': 'system', 'content': '$system\n\nRespond with only a JSON object matching this JSON schema, and nothing else:\n${jsonEncode(jsonSchema)}'},
      for (final t in turns) {'role': t.fromUser ? 'user' : 'assistant', 'content': t.text},
    ];
    // Strictest format first; fall back when a model doesn't support it.
    final formats = <Map<String, dynamic>?>[
      if (p == AiProvider.openrouter)
        {
          'type': 'json_schema',
          'json_schema': {'name': 'reply', 'schema': jsonSchema},
        },
      {'type': 'json_object'},
      null,
    ];
    http.Response? r;
    for (final f in formats) {
      r = await http
          .post(
            Uri.parse(_chatUrl(p)),
            headers: _headers(p, key),
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'temperature': 0.2,
              'response_format': ?f,
            }),
          )
          .timeout(const Duration(seconds: 90));
      if (r.statusCode != 400 || f == null) break;
    }
    if (r!.statusCode == 404) _models.remove(p);
    if (r.statusCode != 200) throw _apiError(p, r.statusCode, r.body);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data['error'] != null) throw _apiError(p, (data['error']['code'] as num?)?.toInt() ?? 500, jsonEncode(data));
    final content = (data['choices'] as List?)?.firstOrNull?['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) throw const MuslimAiException('No answer was returned for this question. Try rephrasing it.');
    return _parseJson(content);
  }

  static Future<Map<String, dynamic>> _generateGemini(
    String key,
    String model,
    String system,
    List<AiTurn> turns,
    Map<String, dynamic> schema,
  ) async {
    final r = await http
        .post(
          Uri.parse('$_gemini/$model:generateContent'),
          headers: _headers(AiProvider.gemini, key),
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': system},
              ],
            },
            'contents': [
              for (final t in turns)
                {
                  'role': t.fromUser ? 'user' : 'model',
                  'parts': [
                    {'text': t.text},
                  ],
                },
            ],
            'generationConfig': {'temperature': 0.2, 'responseMimeType': 'application/json', 'responseSchema': schema},
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (r.statusCode != 200) throw _apiError(AiProvider.gemini, r.statusCode, r.body);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    final candidate = (data['candidates'] as List?)?.firstOrNull;
    if (candidate == null) throw const MuslimAiException('No answer was returned for this question. Try rephrasing it.');
    final text = [
      for (final part in (candidate['content']?['parts'] as List? ?? []))
        if (part['thought'] != true && part['text'] != null) part['text'] as String,
    ].join();
    return _parseJson(text);
  }

  static List<AiTurn> _recent(List<AiTurn> history) => history.length > 8 ? history.sublist(history.length - 8) : history;

  static const _findPrompt = '''
You help a Muslim app find sources. For the user's latest question, list the Quran verses and hadith that most directly address it.
- Only list references you are confident exist with exactly that number. Quran as surah and ayah numbers. Hadith by collection and the standard hadith number used on sunnah.com.
- Prefer Sahih al-Bukhari and Sahih Muslim, then the Sunan. Up to 5 Quran passages (each at most 5 consecutive ayahs) and up to 5 hadith.
- Set in_scope to false only if the question has nothing to do with Islam, Muslim life, worship, ethics, or the Quran and Sunnah. Greetings and thanks are in scope with no sources.
- If out of scope, put a short polite reply in the user's language in out_of_scope_reply explaining you only answer questions about Islam from the Quran and Sunnah.''';

  static const _answerPrompt = '''
You are Muslim AI inside a Muslim app. Answer the user's question using ONLY the numbered SOURCES provided with it.
Rules:
- Every factual or religious claim must be supported by a source and cited with its number in square brackets, like [1] or [2][3].
- Never quote, paraphrase or mention any verse, hadith, scholar or ruling that is not in SOURCES. Do not invent anything. Ignore sources that are not relevant.
- If the sources do not clearly answer the question, say that plainly and suggest asking a qualified scholar or local imam. Do not fill gaps from memory.
- Do not issue personal fatwas. On matters where the schools of fiqh differ, say that scholars differ and recommend following a trusted scholar.
- Mention a hadith's grade when one is given. Do not base a ruling on a hadith graded weak (da'if).
- If the user seems to be in danger, in crisis, or asking about health or legal emergencies, gently urge them to contact local emergency services or a professional as well.
- Reply in the same language as the user's question. Be warm, clear and concise: a short answer, then key points. Plain text only; you may use "- " bullets and **bold**. Write ﷺ after the Prophet's name.
- For greetings or thanks with no sources, reply briefly and kindly without citations.
- In "used", list the numbers of every source you cited.''';

  static Future<AiAnswer> ask(AiProvider provider, String key, List<AiTurn> history, String question, {void Function(AiStage)? onStage}) async {
    onStage?.call(AiStage.searching);
    final plan = await _generate(
      provider,
      key,
      system: _findPrompt,
      turns: [..._recent(history), AiTurn(true, question)],
      schema: {
        'type': 'OBJECT',
        'properties': {
          'in_scope': {'type': 'BOOLEAN'},
          'out_of_scope_reply': {'type': 'STRING'},
          'quran': {
            'type': 'ARRAY',
            'items': {
              'type': 'OBJECT',
              'properties': {
                'surah': {'type': 'INTEGER'},
                'ayah_start': {'type': 'INTEGER'},
                'ayah_end': {'type': 'INTEGER'},
              },
              'required': ['surah', 'ayah_start', 'ayah_end'],
            },
          },
          'hadith': {
            'type': 'ARRAY',
            'items': {
              'type': 'OBJECT',
              'properties': {
                'collection': {'type': 'STRING', 'enum': collections.keys.toList()},
                'number': {'type': 'INTEGER'},
              },
              'required': ['collection', 'number'],
            },
          },
        },
        'required': ['in_scope', 'quran', 'hadith'],
      },
    );

    if (plan['in_scope'] == false) {
      final reply = (plan['out_of_scope_reply'] as String?)?.trim();
      return AiAnswer(
        reply == null || reply.isEmpty ? 'I can only answer questions about Islam, based on the Quran and authentic hadith.' : reply,
        const [],
      );
    }

    onStage?.call(AiStage.verifying);
    final futures = <Future<AiSource?>>[];
    for (final q in (plan['quran'] as List? ?? []).take(5)) {
      final s = (q['surah'] as num?)?.toInt() ?? 0;
      final a = (q['ayah_start'] as num?)?.toInt() ?? 0;
      var b = (q['ayah_end'] as num?)?.toInt() ?? a;
      if (b < a) b = a;
      if (b - a > 4) b = a + 4;
      futures.add(fetchQuran(s, a, b));
    }
    for (final h in (plan['hadith'] as List? ?? []).take(5)) {
      futures.add(fetchHadith(h['collection'] as String? ?? '', (h['number'] as num?)?.toInt() ?? 0));
    }
    final fetched = (await Future.wait(futures)).whereType<AiSource>().toList();
    final sources = [
      for (var i = 0; i < fetched.length; i++)
        AiSource(
          id: i + 1,
          isQuran: fetched[i].isQuran,
          title: fetched[i].title,
          arabic: fetched[i].arabic,
          english: fetched[i].english,
          url: fetched[i].url,
          grade: fetched[i].grade,
        ),
    ];

    onStage?.call(AiStage.writing);
    final block = sources.isEmpty
        ? '(No sources could be found or verified for this question.)'
        : sources.map((s) => '[${s.id}] ${s.title}${s.grade == null ? '' : ' (grade: ${s.grade})'}\n${s.english}').join('\n\n');
    final result = await _generate(
      provider,
      key,
      system: _answerPrompt,
      turns: [..._recent(history), AiTurn(true, 'QUESTION:\n$question\n\nSOURCES:\n$block')],
      schema: {
        'type': 'OBJECT',
        'properties': {
          'answer': {'type': 'STRING'},
          'used': {
            'type': 'ARRAY',
            'items': {'type': 'INTEGER'},
          },
        },
        'required': ['answer', 'used'],
      },
    );
    final text = (result['answer'] as String? ?? '').trim();
    // Show a source if the model listed it or cited it inline.
    final cited = {
      ...(result['used'] as List? ?? []).map((e) => (e as num).toInt()),
      ...RegExp(r'\[(\d+)\]').allMatches(text).map((m) => int.parse(m.group(1)!)),
    };
    return AiAnswer(text, sources.where((s) => cited.contains(s.id)).toList());
  }

  // ---- Source fetching ----

  static Future<AiSource?> fetchQuran(int surah, int from, int to) async {
    if (surah < 1 || surah > 114 || from < 1) return null;
    try {
      final ayahs = await Future.wait([
        for (var a = from; a <= to; a++)
          _getJson(Uri.parse('https://api.alquran.cloud/v1/ayah/$surah:$a/editions/quran-uthmani,en.sahih')).then<Map<String, dynamic>?>((j) => j).catchError((_) => null),
      ]);
      final ok = ayahs.whereType<Map<String, dynamic>>().toList();
      if (ok.isEmpty) return null;
      final arabic = <String>[], english = <String>[];
      for (final j in ok) {
        final eds = j['data'] as List;
        final n = eds.first['numberInSurah'];
        arabic.add('${eds[0]['text']} ﴿$n﴾');
        english.add('($n) ${eds[1]['text']}');
      }
      final last = from + ok.length - 1;
      final name = ok.first['data'][1]['surah']['englishName'];
      return AiSource(
        id: 0,
        isQuran: true,
        title: 'Quran $surah:$from${last > from ? '–$last' : ''} ($name)',
        arabic: arabic.join(' '),
        english: english.join(' '),
        url: 'https://quran.com/$surah/$from${last > from ? '-$last' : ''}',
      );
    } catch (_) {
      return null;
    }
  }

  static String? _gradeOf(Map<String, dynamic> h) {
    final grades = h['grades'] as List? ?? [];
    if (grades.isEmpty) return null;
    final g = grades.firstWhere((g) => g['name'] == 'Al-Albani', orElse: () => grades.first);
    return '${g['grade']} (${g['name']})';
  }

  static Future<AiSource?> fetchHadith(String collection, int number) async {
    final name = collections[collection];
    if (name == null || number < 1) return null;
    try {
      Map<String, dynamic>? eng;
      String arabic = '';
      if (collection == 'muslim') {
        // Sahih Muslim is cited by Fuad Abdul Baqi's numbers, which this dataset stores per book.
        final section = _muslimSections.where((r) => number >= r.$2 && number <= r.$3).firstOrNull?.$1;
        if (section == null) return null;
        final results = await Future.wait([
          _getJson(Uri.parse('$_hadithCdn/eng-muslim/sections/$section.min.json')),
          _getJson(Uri.parse('$_hadithCdn/ara-muslim/sections/$section.min.json')).then<Map<String, dynamic>?>((j) => j).catchError((_) => null),
        ]);
        bool matches(dynamic h) => double.tryParse('${h['arabicnumber']}')?.floor() == number;
        final engAll = (results[0]!['hadiths'] as List).where(matches).toList();
        if (engAll.isEmpty) return null;
        // The main narration is usually the longest of the sub-numbered ones.
        engAll.sort((a, b) => (b['text'] as String).length.compareTo((a['text'] as String).length));
        eng = engAll.first as Map<String, dynamic>;
        final ara = (results[1]?['hadiths'] as List? ?? []).where((h) => h['hadithnumber'] == eng!['hadithnumber']).firstOrNull;
        arabic = ara?['text'] as String? ?? '';
      } else {
        final results = await Future.wait([
          _getJson(Uri.parse('$_hadithCdn/eng-$collection/$number.min.json')),
          _getJson(Uri.parse('$_hadithCdn/ara-$collection/$number.min.json')).then<Map<String, dynamic>?>((j) => j).catchError((_) => null),
        ]);
        eng = (results[0]!['hadiths'] as List).firstOrNull as Map<String, dynamic>?;
        arabic = (results[1]?['hadiths'] as List?)?.firstOrNull?['text'] as String? ?? '';
      }
      final text = (eng?['text'] as String? ?? '').trim();
      if (eng == null || text.isEmpty) return null;
      return AiSource(
        id: 0,
        isQuran: false,
        title: '$name $number',
        arabic: arabic.trim(),
        english: text,
        grade: _gradeOf(eng) ?? (collection == 'bukhari' || collection == 'muslim' ? 'Sahih' : null),
        url: 'https://sunnah.com/$collection:$number',
      );
    } catch (_) {
      return null;
    }
  }

  /// Sahih Muslim books: (section, first Abdul Baqi number, last).
  static const _muslimSections = [
    (0, 1, 7), (1, 8, 222), (2, 223, 292), (3, 293, 376), (4, 377, 519), (5, 520, 684), (6, 685, 843), (7, 844, 883),
    (8, 884, 893), (9, 894, 900), (10, 901, 915), (11, 916, 978), (12, 979, 1078), (13, 1079, 1170), (14, 1171, 1176),
    (15, 1177, 1399), (16, 1400, 1443), (17, 1444, 1470), (18, 1471, 1491), (19, 1492, 1500), (20, 1501, 1510),
    (21, 1511, 1550), (22, 1551, 1613), (23, 1614, 1619), (24, 1620, 1626), (25, 1627, 1637), (26, 1638, 1645),
    (27, 1646, 1668), (28, 1669, 1683), (29, 1684, 1710), (30, 1711, 1721), (31, 1722, 1729), (32, 1730, 1817),
    (33, 1818, 1928), (34, 1929, 1959), (35, 1960, 1978), (36, 1979, 2064), (37, 2065, 2130), (38, 2131, 2159),
    (39, 2160, 2245), (40, 2246, 2254), (41, 2255, 2260), (42, 2261, 2275), (43, 2276, 2380), (44, 2381, 2547),
    (45, 2548, 2642), (46, 2643, 2664), (47, 2665, 2674), (48, 2675, 2735), (49, 2736, 2743), (50, 2744, 2771),
    (51, 2772, 2784), (52, 2785, 2821), (53, 2822, 2879), (54, 2880, 2955), (55, 2956, 3014), (56, 3015, 3033),
  ];
}

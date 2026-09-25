import 'package:flutter/material.dart';

class Dua {
  const Dua({required this.id, required this.title, required this.arabic, required this.meaning, required this.source, this.note});
  final String id;
  final String title;
  final String arabic;
  final String meaning;
  final String source;
  final String? note;
}

class DuaCategory {
  const DuaCategory(this.id, this.title, this.icon, this.duas);
  final String id;
  final String title;
  final IconData icon;
  final List<Dua> duas;
}

const duaCategories = <DuaCategory>[
  DuaCategory('morning', 'Morning & Evening', Icons.wb_twilight_rounded, [
    Dua(
      id: 'm1',
      title: 'Protection by the name of Allah',
      arabic: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
      meaning: 'In the name of Allah, with whose name nothing on earth or in the heavens can cause harm, and He is the All-Hearing, the All-Knowing.',
      source: 'Abu Dawud 5088, Tirmidhi 3388',
      note: 'Recite 3 times in the morning and evening.',
    ),
    Dua(
      id: 'm2',
      title: 'Seeking refuge from evil',
      arabic: 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
      meaning: 'I seek refuge in the perfect words of Allah from the evil of what He has created.',
      source: 'Muslim 2709',
      note: 'Recite 3 times in the evening.',
    ),
    Dua(
      id: 'm3',
      title: 'Contentment with Allah',
      arabic: 'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا',
      meaning: 'I am pleased with Allah as my Lord, with Islam as my religion, and with Muhammad ﷺ as my Prophet.',
      source: 'Abu Dawud 5072',
      note: 'Recite 3 times in the morning and evening.',
    ),
    Dua(
      id: 'm4',
      title: 'Allah is sufficient for me',
      arabic: 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
      meaning: 'Allah is sufficient for me. There is no god but Him. In Him I put my trust, and He is the Lord of the Mighty Throne.',
      source: 'Qur\'an 9:129, Abu Dawud 5081',
      note: 'Recite 7 times in the morning and evening.',
    ),
    Dua(
      id: 'm5',
      title: 'Sayyid al-Istighfar',
      arabic: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي، فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
      meaning: 'O Allah, You are my Lord; there is no god but You. You created me and I am Your servant, and I keep Your covenant and promise as best I can. I seek refuge in You from the evil I have done. I acknowledge Your favour upon me and I acknowledge my sin, so forgive me, for none forgives sins but You.',
      source: 'Bukhari 6306',
      note: 'Whoever says it with conviction in the day and dies before evening is among the people of Paradise.',
    ),
  ]),
  DuaCategory('daily', 'Daily Life', Icons.wb_sunny_outlined, [
    Dua(
      id: 'd1',
      title: 'Upon waking up',
      arabic: 'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
      meaning: 'All praise is for Allah who gave us life after causing us to die, and to Him is the return.',
      source: 'Bukhari 6312',
    ),
    Dua(
      id: 'd2',
      title: 'Before sleeping',
      arabic: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
      meaning: 'In Your name, O Allah, I die and I live.',
      source: 'Bukhari 6324',
    ),
    Dua(
      id: 'd3',
      title: 'Before eating',
      arabic: 'بِسْمِ اللَّهِ',
      meaning: 'In the name of Allah.',
      source: 'Abu Dawud 3767',
      note: 'If you forget at the start, say: بِسْمِ اللَّهِ أَوَّلَهُ وَآخِرَهُ (In the name of Allah at its beginning and end). — Tirmidhi 1858',
    ),
    Dua(
      id: 'd4',
      title: 'After eating',
      arabic: 'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ',
      meaning: 'All praise is for Allah who fed me this and provided it for me without any might or power on my part.',
      source: 'Tirmidhi 3458, Abu Dawud 4023',
    ),
    Dua(
      id: 'd5',
      title: 'Wearing new clothes',
      arabic: 'الْحَمْدُ لِلَّهِ الَّذِي كَسَانِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ',
      meaning: 'All praise is for Allah who clothed me with this and provided it for me without any might or power on my part.',
      source: 'Abu Dawud 4023',
    ),
    Dua(
      id: 'd6',
      title: 'Entering the toilet',
      arabic: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْخُبُثِ وَالْخَبَائِثِ',
      meaning: 'O Allah, I seek refuge in You from the male and female devils.',
      source: 'Bukhari 142, Muslim 375',
    ),
    Dua(
      id: 'd7',
      title: 'Leaving the toilet',
      arabic: 'غُفْرَانَكَ',
      meaning: 'I seek Your forgiveness.',
      source: 'Abu Dawud 30, Tirmidhi 7',
    ),
    Dua(
      id: 'd8',
      title: 'Leaving the home',
      arabic: 'بِسْمِ اللَّهِ، تَوَكَّلْتُ عَلَى اللَّهِ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
      meaning: 'In the name of Allah, I place my trust in Allah, and there is no might nor power except with Allah.',
      source: 'Abu Dawud 5095, Tirmidhi 3426',
    ),
    Dua(
      id: 'd9',
      title: 'Entering the home',
      arabic: 'بِسْمِ اللَّهِ وَلَجْنَا، وَبِسْمِ اللَّهِ خَرَجْنَا، وَعَلَى رَبِّنَا تَوَكَّلْنَا',
      meaning: 'In the name of Allah we enter, in the name of Allah we leave, and upon our Lord we place our trust.',
      source: 'Abu Dawud 5096',
    ),
    Dua(
      id: 'd10',
      title: 'When it rains',
      arabic: 'اللَّهُمَّ صَيِّبًا نَافِعًا',
      meaning: 'O Allah, (make it) a beneficial rain.',
      source: 'Bukhari 1032',
    ),
    Dua(
      id: 'd11',
      title: 'Visiting the sick',
      arabic: 'لَا بَأْسَ طَهُورٌ إِنْ شَاءَ اللَّهُ',
      meaning: 'No harm; it is a purification, if Allah wills.',
      source: 'Bukhari 3616',
    ),
  ]),
  DuaCategory('salah', 'Salah & Mosque', Icons.mosque_outlined, [
    Dua(
      id: 's1',
      title: 'After wudu',
      arabic: 'أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ',
      meaning: 'I bear witness that there is no god but Allah alone, without partner, and I bear witness that Muhammad is His servant and Messenger.',
      source: 'Muslim 234',
    ),
    Dua(
      id: 's2',
      title: 'Entering the mosque',
      arabic: 'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
      meaning: 'O Allah, open for me the doors of Your mercy.',
      source: 'Muslim 713',
    ),
    Dua(
      id: 's3',
      title: 'Leaving the mosque',
      arabic: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ',
      meaning: 'O Allah, I ask You of Your bounty.',
      source: 'Muslim 713',
    ),
    Dua(
      id: 's4',
      title: 'After the obligatory prayer',
      arabic: 'أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ، اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ',
      meaning: 'I seek Allah\'s forgiveness (three times). O Allah, You are Peace and from You is peace. Blessed are You, O Possessor of majesty and honour.',
      source: 'Muslim 591',
    ),
    Dua(
      id: 's5',
      title: 'Ayat al-Kursi',
      arabic: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
      meaning: 'Allah — there is no god except Him, the Ever-Living, the Sustainer of all existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and the earth. Who can intercede with Him except by His permission? He knows what is before them and what is behind them, and they encompass nothing of His knowledge except what He wills. His Kursi extends over the heavens and the earth, and preserving them does not tire Him. He is the Most High, the Most Great.',
      source: 'Qur\'an 2:255',
      note: 'Recite after each obligatory prayer and before sleeping (Bukhari 5010).',
    ),
    Dua(
      id: 's6',
      title: 'Durood Ibrahim',
      arabic: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ، اللَّهُمَّ بَارِكْ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا بَارَكْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ',
      meaning: 'O Allah, send prayers upon Muhammad and the family of Muhammad as You sent prayers upon Ibrahim and the family of Ibrahim; You are Praiseworthy, Glorious. O Allah, bless Muhammad and the family of Muhammad as You blessed Ibrahim and the family of Ibrahim; You are Praiseworthy, Glorious.',
      source: 'Bukhari 3370',
    ),
  ]),
  DuaCategory('quranic', 'From the Qur\'an', Icons.menu_book_outlined, [
    Dua(
      id: 'q1',
      title: 'Good in this world and the next',
      arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      meaning: 'Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.',
      source: 'Qur\'an 2:201',
    ),
    Dua(
      id: 'q2',
      title: 'Steadfast hearts',
      arabic: 'رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِنْ لَدُنْكَ رَحْمَةً ۚ إِنَّكَ أَنْتَ الْوَهَّابُ',
      meaning: 'Our Lord, do not let our hearts deviate after You have guided us, and grant us mercy from Yourself. Indeed, You are the Bestower.',
      source: 'Qur\'an 3:8',
    ),
    Dua(
      id: 'q3',
      title: 'Increase in knowledge',
      arabic: 'رَبِّ زِدْنِي عِلْمًا',
      meaning: 'My Lord, increase me in knowledge.',
      source: 'Qur\'an 20:114',
    ),
    Dua(
      id: 'q4',
      title: 'Ease in affairs',
      arabic: 'رَبِّ اشْرَحْ لِي صَدْرِي ۝ وَيَسِّرْ لِي أَمْرِي',
      meaning: 'My Lord, expand for me my chest, and ease for me my task.',
      source: 'Qur\'an 20:25–26',
    ),
    Dua(
      id: 'q5',
      title: 'For parents',
      arabic: 'رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا',
      meaning: 'My Lord, have mercy upon them as they brought me up when I was small.',
      source: 'Qur\'an 17:24',
    ),
    Dua(
      id: 'q6',
      title: 'For family',
      arabic: 'رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا',
      meaning: 'Our Lord, grant us from among our spouses and offspring comfort to our eyes, and make us leaders of the righteous.',
      source: 'Qur\'an 25:74',
    ),
    Dua(
      id: 'q7',
      title: 'Dua of Yunus (AS)',
      arabic: 'لَا إِلَٰهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ',
      meaning: 'There is no god except You; exalted are You. Indeed, I have been of the wrongdoers.',
      source: 'Qur\'an 21:87',
    ),
    Dua(
      id: 'q8',
      title: 'When travelling',
      arabic: 'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَٰذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ ۝ وَإِنَّا إِلَىٰ رَبِّنَا لَمُنْقَلِبُونَ',
      meaning: 'Glory be to Him who has subjected this to us, and we could never have done so ourselves. And indeed, to our Lord we will return.',
      source: 'Qur\'an 43:13–14, Muslim 1342',
    ),
  ]),
  DuaCategory('hardship', 'Hardship & Protection', Icons.shield_outlined, [
    Dua(
      id: 'h1',
      title: 'Worry and grief',
      arabic: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ',
      meaning: 'O Allah, I seek refuge in You from worry and grief, from incapacity and laziness, from miserliness and cowardice, and from the burden of debt and being overpowered by men.',
      source: 'Bukhari 6369',
    ),
    Dua(
      id: 'h2',
      title: 'Seeking pardon',
      arabic: 'اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي',
      meaning: 'O Allah, You are Pardoning and love to pardon, so pardon me.',
      source: 'Tirmidhi 3513',
      note: 'Taught by the Prophet ﷺ for Laylat al-Qadr.',
    ),
  ]),
  DuaCategory('ramadan', 'Ramadan', Icons.nightlight_outlined, [
    Dua(
      id: 'r1',
      title: 'Breaking the fast',
      arabic: 'ذَهَبَ الظَّمَأُ وَابْتَلَّتِ الْعُرُوقُ وَثَبَتَ الْأَجْرُ إِنْ شَاءَ اللَّهُ',
      meaning: 'The thirst has gone, the veins are moistened, and the reward is confirmed, if Allah wills.',
      source: 'Abu Dawud 2357',
    ),
  ]),
];

final Map<String, Dua> duaById = {
  for (final c in duaCategories)
    for (final d in c.duas) d.id: d,
};

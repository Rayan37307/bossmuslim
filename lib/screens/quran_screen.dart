import 'package:flutter/material.dart';

import '../services/quran_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'quran_reader_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  late Future<List<SurahInfo>> _future = QuranService.surahs();
  String _query = '';
  int _tab = 0;

  void _open(int surah, String name, [int? ayah]) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => QuranReaderScreen(surah: surah, surahName: name, initialAyah: ayah)),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Text('Qur\'an', style: context.text.headlineMedium?.copyWith(fontSize: 26)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(hintText: 'Search surah by name or number', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                _tabChip('Surahs', 0),
                const SizedBox(width: 8),
                ListenableBuilder(
                  listenable: AppState.instance,
                  builder: (_, _) => _tabChip('Bookmarks · ${AppState.instance.bookmarks.length}', 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _tab == 0 ? _surahList() : _bookmarks(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String label, int i) => ChoiceChip(
        label: Text(label),
        selected: _tab == i,
        onSelected: (_) => setState(() => _tab = i),
        labelStyle: TextStyle(
          color: _tab == i ? context.colors.primary : null,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      );

  Widget _surahList() {
    return FutureBuilder<List<SurahInfo>>(
      key: const ValueKey('surahs'),
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return ErrorState(
            message: 'Couldn\'t load the surah list.\nConnect to the internet once to download it.',
            onRetry: () => setState(() => _future = QuranService.surahs()),
          );
        }
        if (!snap.hasData) return const Loading();
        final list = snap.data!
            .where((s) =>
                _query.isEmpty ||
                s.englishName.toLowerCase().contains(_query) ||
                s.meaning.toLowerCase().contains(_query) ||
                '${s.number}' == _query)
            .toList();
        final last = AppState.instance.lastRead;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          itemCount: list.length + (last != null && _query.isEmpty ? 1 : 0),
          itemBuilder: (context, i) {
            if (last != null && _query.isEmpty) {
              if (i == 0) return _lastReadCard(last);
              i--;
            }
            final s = list[i];
            return _SurahTile(surah: s, onTap: () => _open(s.number, s.englishName));
          },
        );
      },
    );
  }

  Widget _lastReadCard(Bookmark b) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Pressable(
          onTap: () => _open(b.surah, b.surahName, b.ayah),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1E40AF)]),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Last read', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                      const SizedBox(height: 4),
                      Text(b.surahName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Ayah ${b.ayah}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                  child: const Text('Continue', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _bookmarks() {
    return ListenableBuilder(
      key: const ValueKey('bookmarks'),
      listenable: AppState.instance,
      builder: (context, _) {
        final list = AppState.instance.bookmarks;
        if (list.isEmpty) {
          return const ErrorState(icon: Icons.bookmark_outline_rounded, message: 'No bookmarks yet.\nTap the bookmark icon on any ayah to save it here.');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final b = list[i];
            return Dismissible(
              key: ValueKey(b.key),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => AppState.instance.toggleBookmark(b),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              ),
              child: Panel(
                onTap: () => _open(b.surah, b.surahName, b.ayah),
                child: Row(
                  children: [
                    const IconTile(Icons.bookmark_rounded, size: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.surahName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${b.surah}:${b.ayah}', style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.tokens.muted),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({required this.surah, required this.onTap});
  final SurahInfo surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.tokens.border))),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.tokens.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${surah.number}', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(surah.englishName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    '${surah.meaning} · ${surah.meccan ? 'Meccan' : 'Medinan'} · ${surah.ayahs} ayahs',
                    style: context.text.bodySmall?.copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(surah.name, style: arabicStyle(size: 20, height: 1.4, color: context.colors.primary)),
          ],
        ),
      ),
    );
  }
}

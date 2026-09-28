import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../services/quran_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({super.key, required this.surah, required this.surahName, this.initialAyah});
  final int surah;
  final String surahName;
  final int? initialAyah;

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final _state = AppState.instance;
  final _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  final _player = AudioPlayer();
  late Future<List<Ayah>> _future;
  List<Ayah> _ayahs = [];
  String _loadedTranslation = '';

  int? _playingIndex;
  bool _playerVisible = false;
  int _topAyah = 1;
  final _subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    _load();
    _positions.itemPositions.addListener(_onScroll);
    _subs.add(_player.currentIndexStream.listen((i) {
      if (i == null || !mounted) return;
      setState(() => _playingIndex = i);
      _scroll.scrollTo(index: i + 1, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic, alignment: 0.1);
    }));
    _subs.add(_player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted) {
        setState(() => _playingIndex = null);
      }
    }));
  }

  void _load() {
    _loadedTranslation = _state.translation;
    _future = QuranService.surah(widget.surah, _state.translation).then((a) => _ayahs = a);
  }

  void _onScroll() {
    final visible = _positions.itemPositions.value.where((p) => p.itemTrailingEdge > 0.15);
    if (visible.isEmpty) return;
    final first = visible.reduce((a, b) => a.index < b.index ? a : b).index;
    _topAyah = first == 0 ? 1 : first;
  }

  @override
  void dispose() {
    if (_ayahs.isNotEmpty) {
      final b = Bookmark(widget.surah, _topAyah.clamp(1, _ayahs.length), widget.surahName);
      // Deferred: notifying listeners while the tree is unmounting is not allowed.
      Future.microtask(() => _state.setLastRead(b));
    }
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _playFrom(int index) async {
    HapticFeedback.lightImpact();
    if (_playingIndex == index && _player.playing) {
      await _player.pause();
      setState(() {});
      return;
    }
    setState(() {
      _playerVisible = true;
      _playingIndex = index;
    });
    try {
      if (_player.sequence.length != _ayahs.length || _player.sequence.isEmpty) {
        await _player.setAudioSources(
          [for (final a in _ayahs) AudioSource.uri(Uri.parse(QuranService.audioUrl(_state.reciter, a.number)))],
          initialIndex: index,
        );
      } else {
        await _player.seek(Duration.zero, index: index);
      }
      _player.play();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio unavailable. Check your connection.')));
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() {
      _playerVisible = false;
      _playingIndex = null;
    });
  }

  Future<void> _openSettings() async {
    final reciter = _state.reciter;
    await showSheet(context, (_) => const _ReaderSettings());
    if (!mounted) return;
    if (_state.reciter != reciter) {
      await _player.stop();
      await _player.clearAudioSources();
      setState(() => _playingIndex = null);
    }
    if (_state.translation != _loadedTranslation) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surahName),
        actions: [
          IconButton(
            tooltip: 'Play surah',
            onPressed: _ayahs.isEmpty ? null : () => _playFrom(_playingIndex ?? 0),
            icon: const Icon(Icons.play_circle_outline_rounded),
          ),
          IconButton(tooltip: 'Reading settings', onPressed: _openSettings, icon: const Icon(Icons.tune_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<List<Ayah>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorState(
              message: 'Couldn\'t load this surah.\nIt will be available offline after the first download.',
              onRetry: () => setState(_load),
            );
          }
          if (!snap.hasData) return const Loading();
          final ayahs = snap.data!;
          return ListenableBuilder(
            listenable: _state,
            builder: (context, _) => ScrollablePositionedList.builder(
              itemScrollController: _scroll,
              itemPositionsListener: _positions,
              initialScrollIndex: (widget.initialAyah ?? 0).clamp(0, ayahs.length),
              padding: EdgeInsets.fromLTRB(16, 8, 16, _playerVisible ? 110 : 32),
              itemCount: ayahs.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return _SurahHeader(surah: widget.surah, name: widget.surahName, count: ayahs.length);
                final a = ayahs[i - 1];
                return _AyahCard(
                  surah: widget.surah,
                  surahName: widget.surahName,
                  ayah: a,
                  arabicSize: _state.arabicSize,
                  playing: _playingIndex == i - 1,
                  highlighted: widget.initialAyah == a.inSurah,
                  onPlay: () => _playFrom(i - 1),
                );
              },
            ),
          );
        },
      ),
      bottomSheet: AnimatedSlide(
        offset: _playerVisible ? Offset.zero : const Offset(0, 1.2),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: _playerVisible ? _PlayerBar(player: _player, surahName: widget.surahName, index: _playingIndex, onClose: _stop) : const SizedBox.shrink(),
      ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({required this.surah, required this.name, required this.count});
  final int surah;
  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0E8A5F), Color(0xFF065F46)]),
      ),
      child: Column(
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Surah $surah · $count ayahs', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (surah != 1 && surah != 9) ...[
            const SizedBox(height: 16),
            Container(height: 1, width: 120, color: Colors.white24),
            const SizedBox(height: 12),
            Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ', textDirection: TextDirection.rtl, style: quranStyle(size: 26, color: Colors.white, height: 1.8)),
          ],
        ],
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  const _AyahCard({
    required this.surah,
    required this.surahName,
    required this.ayah,
    required this.arabicSize,
    required this.playing,
    required this.highlighted,
    required this.onPlay,
  });

  final int surah;
  final String surahName;
  final Ayah ayah;
  final double arabicSize;
  final bool playing;
  final bool highlighted;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final bookmarked = state.isBookmarked(surah, ayah.inSurah);
    final accent = context.colors.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: playing ? context.tokens.accentSoft : context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: playing || highlighted ? accent.withValues(alpha: 0.5) : context.tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: context.tokens.accentSoft, borderRadius: BorderRadius.circular(99)),
                child: Text('$surah:${ayah.inSurah}', style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              if (ayah.sajda) ...[
                const SizedBox(width: 8),
                Text('Sajdah', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
              const Spacer(),
              _action(context, playing ? Icons.pause_rounded : Icons.play_arrow_rounded, onPlay, active: playing),
              _action(context, bookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, () {
                HapticFeedback.selectionClick();
                state.toggleBookmark(Bookmark(surah, ayah.inSurah, surahName));
              }, active: bookmarked),
              _action(context, Icons.copy_rounded, () {
                Clipboard.setData(ClipboardData(text: '${ayah.arabic}\n\n${ayah.translation ?? ''}\n— $surahName $surah:${ayah.inSurah}'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ayah copied'), duration: Duration(seconds: 1)));
              }),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            ayah.arabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: quranStyle(size: arabicSize, height: 2.3),
          ),
          if (ayah.translation != null) ...[
            const SizedBox(height: 12),
            Text(ayah.translation!, style: TextStyle(fontSize: 15, height: 1.6, color: context.colors.onSurface.withValues(alpha: 0.85))),
          ],
        ],
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, VoidCallback onTap, {bool active = false}) => IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        icon: Icon(icon, color: active ? context.colors.primary : context.tokens.muted),
      );
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({required this.player, required this.surahName, required this.index, required this.onClose});
  final AudioPlayer player;
  final String surahName;
  final int? index;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.tokens.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(surahName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${index == null ? 'Finished' : 'Ayah ${index! + 1}'} · ${QuranService.reciters[AppState.instance.reciter] ?? ''}',
                    style: context.text.bodySmall?.copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(onPressed: player.hasPrevious ? player.seekToPrevious : null, icon: const Icon(Icons.skip_previous_rounded)),
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snap) {
                final s = snap.data;
                final loading = s?.processingState == ProcessingState.loading || s?.processingState == ProcessingState.buffering;
                return IconButton.filled(
                  onPressed: () => player.playing ? player.pause() : player.play(),
                  icon: loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                );
              },
            ),
            IconButton(onPressed: player.hasNext ? player.seekToNext : null, icon: const Icon(Icons.skip_next_rounded)),
            IconButton(onPressed: onClose, icon: Icon(Icons.close_rounded, color: context.tokens.muted)),
          ],
        ),
      ),
    );
  }
}

class _ReaderSettings extends StatelessWidget {
  const _ReaderSettings();

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reading settings', style: context.text.titleLarge?.copyWith(fontSize: 18)),
              const SizedBox(height: 20),
              Text('Arabic text size', style: context.text.bodySmall),
              Row(
                children: [
                  const Text('ع', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Slider(value: s.arabicSize, min: 20, max: 44, divisions: 12, onChanged: s.setArabicSize),
                  ),
                  const Text('ع', style: TextStyle(fontSize: 26)),
                ],
              ),
              Text('بِسْمِ ٱللَّهِ', textAlign: TextAlign.center, style: quranStyle(size: s.arabicSize, height: 1.8)),
              const SizedBox(height: 12),
              _picker(context, 'Translation', QuranService.translations, s.translation, s.setTranslation),
              const SizedBox(height: 10),
              _picker(context, 'Reciter', QuranService.reciters, s.reciter, s.setReciter),
            ],
          ),
        ),
      ),
    );
  }

  Widget _picker(BuildContext context, String label, Map<String, String> options, String value, ValueChanged<String> onChanged) {
    return Panel(
      onTap: () async {
        final v = await showSheet<String>(context, (_) => OptionSheet(title: label, options: options, selected: value));
        if (v != null) onChanged(v);
      },
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.bodySmall),
                const SizedBox(height: 2),
                Text(options[value] ?? value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Icon(Icons.unfold_more_rounded, color: context.tokens.muted),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/muslim_ai_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _suggestions = [
  'What does the Quran say about patience?',
  'What are the virtues of sending durood?',
  'How should I treat my parents?',
  'Is there a dua for anxiety and worry?',
];

class _Message {
  _Message.user(this.text)
      : fromUser = true,
        sources = const [],
        error = false;
  _Message.ai(AiAnswer a)
      : fromUser = false,
        text = a.text,
        sources = a.sources,
        error = false;
  _Message.error(this.text)
      : fromUser = false,
        sources = const [],
        error = true;

  final bool fromUser;
  final String text;
  final List<AiSource> sources;
  final bool error;
}

class MuslimAiScreen extends StatefulWidget {
  const MuslimAiScreen({super.key});

  @override
  State<MuslimAiScreen> createState() => _MuslimAiScreenState();
}

AiProvider _providerOf(AppState s) => AiProvider.values.where((p) => p.name == s.aiProvider).firstOrNull ?? AiProvider.gemini;

List<String> _steps(AiProvider p) => switch (p) {
      AiProvider.gemini => ['Open Google AI Studio and sign in with a Google account.', 'Tap "Create API key" and copy it.'],
      AiProvider.groq => ['Open the Groq console and sign up for free.', 'Go to API Keys, tap "Create API Key" and copy it.'],
      AiProvider.openrouter => ['Open OpenRouter and sign up for free.', 'Go to Keys, create a key and copy it. Only free models are used.'],
    };

class _ProviderPicker extends StatelessWidget {
  const _ProviderPicker({required this.selected, required this.onPick});
  final AiProvider selected;
  final ValueChanged<AiProvider> onPick;

  @override
  Widget build(BuildContext context) {
    final keys = AppState.instance.aiKeys;
    return SegmentedButton<AiProvider>(
      showSelectedIcon: false,
      segments: [
        for (final p in AiProvider.values)
          ButtonSegment(
            value: p,
            label: Text(p == AiProvider.gemini ? 'Gemini' : p.label, style: const TextStyle(fontSize: 13)),
            icon: keys.containsKey(p.name) ? const Icon(Icons.check_circle_rounded, size: 16) : null,
          ),
      ],
      selected: {selected},
      onSelectionChanged: (v) => onPick(v.first),
    );
  }
}

class _MuslimAiScreenState extends State<MuslimAiScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Message>[];
  AiStage? _stage;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });

  Future<void> _send([String? preset]) async {
    final q = (preset ?? _input.text).trim();
    if (q.isEmpty || _stage != null) return;
    HapticFeedback.lightImpact();
    final history = [
      for (final m in _messages)
        if (!m.error) AiTurn(m.fromUser, m.text),
    ];
    setState(() {
      _messages.add(_Message.user(q));
      _input.clear();
      _stage = AiStage.searching;
    });
    _toBottom();
    try {
      final state = AppState.instance;
      final a = await MuslimAiService.ask(_providerOf(state), state.aiKey, history, q, onStage: (s) {
        if (mounted) setState(() => _stage = s);
      });
      if (mounted) setState(() => _messages.add(_Message.ai(a)));
    } on MuslimAiException catch (e) {
      if (mounted) setState(() => _messages.add(_Message.error(e.message)));
    } catch (_) {
      if (mounted) setState(() => _messages.add(_Message.error('Could not reach the server. Check your internet connection and try again.')));
    } finally {
      if (mounted) setState(() => _stage = null);
      _toBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final hasKey = state.aiKey.isNotEmpty;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Muslim AI'),
                if (hasKey) Text('via ${_providerOf(state).label}', style: context.text.bodySmall?.copyWith(fontSize: 11.5)),
              ],
            ),
            actions: [
              if (hasKey && _messages.isNotEmpty)
                IconButton(
                  tooltip: 'New chat',
                  onPressed: _stage != null ? null : () => setState(_messages.clear),
                  icon: const Icon(Icons.add_comment_outlined),
                ),
              if (hasKey)
                IconButton(
                  tooltip: 'AI provider & keys',
                  onPressed: () => showSheet(context, (_) => const _KeySheet()),
                  icon: const Icon(Icons.key_rounded),
                ),
            ],
          ),
          body: !hasKey
              ? const _Setup()
              : Column(
                  children: [
                    Expanded(
                      child: _messages.isEmpty && _stage == null
                          ? _Welcome(onPick: _send)
                          : ListView(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              children: [
                                for (final m in _messages) m.fromUser ? _UserBubble(m.text) : _AiBubble(m),
                                if (_stage != null) _Thinking(_stage!),
                              ],
                            ),
                    ),
                    _InputBar(controller: _input, busy: _stage != null, onSend: _send),
                  ],
                ),
        );
      },
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        Center(child: IconTile(Icons.auto_awesome_rounded, size: 64)),
        const SizedBox(height: 16),
        Text('Assalamu alaikum', textAlign: TextAlign.center, style: context.text.headlineMedium?.copyWith(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          'Ask about Islam. Every answer is built only from Quran verses and hadith fetched for your question, and cites them.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: context.tokens.muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        for (final s in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              onTap: () => onPick(s),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(s, style: const TextStyle(fontWeight: FontWeight.w500))),
                  Icon(Icons.north_east_rounded, size: 18, color: context.colors.primary),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        const _Disclaimer(),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) => Text(
        'AI can make mistakes. Read the cited sources, and ask a qualified scholar for rulings on your situation.',
        textAlign: TextAlign.center,
        style: context.text.bodySmall?.copyWith(fontSize: 11.5),
      );
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 48, bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: SelectableText(text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
        ),
      );
}

/// Renders **bold** and [n] citation markers.
List<InlineSpan> _rich(BuildContext context, String text, List<AiSource> sources) {
  final accent = context.colors.primary;
  final ids = {for (final s in sources) s.id};
  final spans = <InlineSpan>[];
  final re = RegExp(r'\*\*(.+?)\*\*|\[(\d+)\]');
  var i = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start)));
    if (m.group(1) != null) {
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
    } else if (ids.contains(int.parse(m.group(2)!))) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: context.tokens.accentSoft, borderRadius: BorderRadius.circular(6)),
          child: Text(m.group(2)!, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ));
    }
    i = m.end;
  }
  if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
  return spans;
}

class _AiBubble extends StatelessWidget {
  const _AiBubble(this.m);
  final _Message m;

  @override
  Widget build(BuildContext context) {
    if (m.error) {
      return Container(
        margin: const EdgeInsets.only(right: 32, bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(m.text, style: const TextStyle(height: 1.4))),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Panel(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: context.colors.primary),
                    const SizedBox(width: 6),
                    Text('Muslim AI', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText.rich(
                  TextSpan(style: TextStyle(fontSize: 15, height: 1.55, color: context.colors.onSurface), children: _rich(context, m.text, m.sources)),
                ),
              ],
            ),
          ),
          if (m.sources.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, size: 15, color: context.colors.primary),
                  const SizedBox(width: 6),
                  Text('Verified sources', style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            for (final s in m.sources) _SourceCard(s),
          ],
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard(this.s);
  final AiSource s;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            shape: const Border(),
            leading: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: context.tokens.accentSoft, borderRadius: BorderRadius.circular(8)),
              child: Text('${s.id}', style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
            title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              s.grade ?? (s.isQuran ? 'Saheeh International' : 'Hadith'),
              style: context.text.bodySmall?.copyWith(fontSize: 11.5),
            ),
            children: [
              if (s.arabic.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    s.arabic,
                    textDirection: TextDirection.rtl,
                    style: s.isQuran ? quranStyle(size: 22, height: 2.0) : arabicStyle(size: 19, height: 1.9),
                  ),
                ),
              const SizedBox(height: 8),
              SelectableText(s.english, style: const TextStyle(fontSize: 14, height: 1.5)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(s.isQuran ? 'Read on quran.com' : 'View on sunnah.com'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking(this.stage);
  final AiStage stage;

  @override
  Widget build(BuildContext context) {
    final label = switch (stage) {
      AiStage.searching => 'Searching the Quran and hadith…',
      AiStage.verifying => 'Fetching and verifying sources…',
      AiStage.writing => 'Writing the answer…',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: context.colors.primary)),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(label, key: ValueKey(stage), style: TextStyle(color: context.tokens.muted, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.busy, required this.onSend});
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.tokens.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask about Islam…',
                  filled: true,
                  fillColor: context.colors.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: busy ? null : onSend,
              icon: const Icon(Icons.arrow_upward_rounded),
              style: IconButton.styleFrom(minimumSize: const Size(46, 46)),
            ),
          ],
        ),
      ),
    );
  }
}

/// First-run screen: explains the free key and takes it.
class _Setup extends StatefulWidget {
  const _Setup();

  @override
  State<_Setup> createState() => _SetupState();
}

class _SetupState extends State<_Setup> {
  AiProvider _p = AiProvider.gemini;

  @override
  Widget build(BuildContext context) {
    Widget step(int n, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: context.tokens.accentSoft,
                child: Text('$n', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
            ],
          ),
        );
    final steps = _steps(_p);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Center(child: IconTile(Icons.auto_awesome_rounded, size: 64)),
        const SizedBox(height: 16),
        Text('Answers from the Quran and Sunnah', textAlign: TextAlign.center, style: context.text.headlineMedium?.copyWith(fontSize: 22)),
        const SizedBox(height: 8),
        Text(
          'Muslim AI works with a free API key from Google Gemini, Groq or OpenRouter. Setup takes about a minute and needs no payment card.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.tokens.muted, height: 1.5),
        ),
        const SizedBox(height: 20),
        _ProviderPicker(selected: _p, onPick: (p) => setState(() => _p = p)),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) step(i + 1, steps[i]),
              step(steps.length + 1, 'Paste the key below. It is stored only on this device.'),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(_p.keyUrl), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('Get a free ${_p.label} key'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _KeyForm(key: ValueKey(_p), provider: _p),
      ],
    );
  }
}

class _KeySheet extends StatefulWidget {
  const _KeySheet();

  @override
  State<_KeySheet> createState() => _KeySheetState();
}

class _KeySheetState extends State<_KeySheet> {
  late AiProvider _p = _providerOf(AppState.instance);

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final saved = state.aiKeys[_p.name] ?? '';
    final active = state.aiProvider == _p.name;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('AI provider', style: context.text.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: 12),
            _ProviderPicker(selected: _p, onPick: (p) => setState(() => _p = p)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    saved.isEmpty ? 'No ${_p.label} key saved yet.' : (active ? 'In use.' : 'Key saved, not in use.'),
                    style: context.text.bodySmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(_p.keyUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Get free key'),
                ),
              ],
            ),
            if (saved.isNotEmpty && !active) ...[
              FilledButton(
                onPressed: () {
                  state.setAiProvider(_p.name);
                  Navigator.pop(context);
                },
                child: Text('Use ${_p.label}'),
              ),
              const SizedBox(height: 16),
            ],
            _KeyForm(key: ValueKey(_p), provider: _p, initial: saved, onDone: () => Navigator.pop(context)),
            if (saved.isNotEmpty) ...[
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  await state.setAiKey(_p.name, '');
                  if (!context.mounted) return;
                  state.aiKeys.isEmpty ? Navigator.pop(context) : setState(() {});
                },
                child: const Text('Remove key'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KeyForm extends StatefulWidget {
  const _KeyForm({super.key, required this.provider, this.initial = '', this.onDone});
  final AiProvider provider;
  final String initial;
  final VoidCallback? onDone;

  @override
  State<_KeyForm> createState() => _KeyFormState();
}

class _KeyFormState extends State<_KeyForm> {
  late final _c = TextEditingController(text: widget.initial);
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _c.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await MuslimAiService.verifyKey(widget.provider, key);
      await AppState.instance.setAiKey(widget.provider.name, key);
      widget.onDone?.call();
    } on MuslimAiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not check the key. Are you online?');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _c,
          obscureText: _hidden,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: '${widget.provider.label} API key',
            hintText: widget.provider.keyHint,
            errorText: _error,
            errorMaxLines: 3,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidden = !_hidden),
              icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)) : const Text('Save key'),
        ),
      ],
    );
  }
}

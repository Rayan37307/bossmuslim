import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Quick picks offered when adding a counter.
const tasbihPresets = [
  ...defaultTasbihs,
  ('La ilaha illallah', 'لَا إِلَٰهَ إِلَّا اللَّهُ', 100),
  ('SubhanAllahi wa bihamdihi', 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 100),
  ('Durood', 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ', 100),
];

/// Bead colours: highlight, body, shade.
const beadPalettes = [
  (Color(0xFFF0A6FF), Color(0xFFB21FE0), Color(0xFF5B0B7A)), // amethyst
  (Color(0xFFFFFFFF), Color(0xFFEDE8DF), Color(0xFFB9AE9C)), // pearl
  (Color(0xFF8BF7D0), Color(0xFF14C98E), Color(0xFF04795A)), // emerald
  (Color(0xFFFFE49A), Color(0xFFF2A900), Color(0xFFA85A06)), // amber
  (Color(0xFF9A9AA2), Color(0xFF404047), Color(0xFF111114)), // onyx
];

/// Counts one dhikr with feedback; a stronger buzz marks a completed round.
void countTasbih() {
  final s = AppState.instance;
  s.tasbihTap();
  if (s.tasbihSound) SystemSound.play(SystemSoundType.click);
  if (!s.tasbihVibrate) return;
  final t = s.tasbih;
  if (t.target > 0 && t.count % t.target == 0) {
    HapticFeedback.heavyImpact();
  } else {
    HapticFeedback.lightImpact();
  }
}

/// Count within the current round, and how far through the round we are.
(int, double) tasbihRoundProgress() {
  final t = AppState.instance.tasbih;
  return (t.inRound, t.target == 0 ? 0 : t.inRound / t.target);
}

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> with SingleTickerProviderStateMixin {
  final _state = AppState.instance;
  late final _pages = PageController(viewportFraction: 0.8, initialPage: _state.tasbihIndex);
  // 0..1: how far the next bead has travelled across the gap.
  late final _slide = AnimationController(vsync: this);
  bool _toOne = false;

  @override
  void dispose() {
    _pages.dispose();
    _slide.dispose();
    super.dispose();
  }

  void _finish() {
    countTasbih();
    _slide.value = 0;
  }

  void _advance() {
    if (_slide.isAnimating) {
      _slide.stop();
      if (_toOne) _finish();
    }
    _toOne = true;
    final ms = 60 + (200 * (1 - _slide.value)).round();
    _slide
        .animateTo(
          1,
          duration: Duration(milliseconds: ms),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          _toOne = false;
          _finish();
        });
  }

  void _settle() {
    _toOne = false;
    _slide.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOutBack);
  }

  void _goTo(int i) {
    if (_pages.hasClients) _pages.animateToPage(i, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  Future<void> _add() async {
    final r = await showSheet<(String, String, int)>(context, (_) => const _TasbihEditor());
    if (r == null) return;
    await _state.addTasbih(TasbihItem(name: r.$1, arabic: r.$2, target: r.$3));
    WidgetsBinding.instance.addPostFrameCallback((_) => _goTo(_state.tasbihIndex));
  }

  Future<void> _edit(int i) async {
    final t = _state.tasbihs[i];
    final r = await showSheet<(String, String, int)>(context, (_) => _TasbihEditor(initial: t));
    if (r != null) await _state.updateTasbih(i, name: r.$1, arabic: r.$2, target: r.$3);
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _reset() async {
    if (_state.tasbih.count == 0) return;
    if (!await _confirm('Reset counter?', 'The count and rounds for ${_state.tasbih.name} go back to 0. The total is kept.', 'Reset')) return;
    HapticFeedback.mediumImpact();
    _slide.value = 0;
    await _state.tasbihReset();
  }

  Future<void> _delete(int i) async {
    if (!await _confirm('Delete tasbih?', '${_state.tasbihs[i].name} and its counts will be removed.', 'Delete')) return;
    await _state.deleteTasbih(i);
    if (_pages.hasClients) _pages.jumpToPage(_state.tasbihIndex);
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Tasbih', style: context.text.headlineMedium?.copyWith(fontSize: 26))),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => showSheet(context, (_) => const _TasbihSettingsSheet()),
                    icon: Icon(Icons.settings_rounded, color: context.colors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 262,
              child: PageView.builder(
                controller: _pages,
                itemCount: s.tasbihs.length,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  _slide.value = 0;
                  s.selectTasbih(i);
                },
                itemBuilder: (context, i) => _TasbihCard(
                  item: s.tasbihs[i],
                  active: i == s.tasbihIndex,
                  canDelete: s.tasbihs.length > 1,
                  onUndo: () {
                    HapticFeedback.selectionClick();
                    _slide.value = 0;
                    s.tasbihUndo();
                  },
                  onReset: _reset,
                  onEdit: () => _edit(i),
                  onDelete: () => _delete(i),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _advance,
                onHorizontalDragStart: (_) {
                  if (_slide.isAnimating) {
                    _slide.stop();
                    if (_toOne) _finish();
                    _toOne = false;
                  }
                },
                onHorizontalDragUpdate: (d) {
                  final gap = context.size!.width * 0.34;
                  _slide.value = (_slide.value - d.delta.dx / gap).clamp(0.0, 1.0);
                },
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (_slide.value > 0.3 || v.abs() > 300) {
                    _advance();
                  } else {
                    _settle();
                  }
                },
                child: CustomPaint(
                  painter: _BeadsPainter(slide: _slide, state: s, palette: beadPalettes[s.tasbihBead.clamp(0, beadPalettes.length - 1)]),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Text(
              'Swipe to count',
              style: TextStyle(color: context.tokens.muted, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Row(
                children: [
                  _BeadPicker(selected: s.tasbihBead, onPick: s.setTasbihBead),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: FilledButton.icon(
                          onPressed: _add,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Tasbih'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 54),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: const StadiumBorder(),
                            elevation: 4,
                            shadowColor: context.colors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasbihCard extends StatelessWidget {
  const _TasbihCard({
    required this.item,
    required this.active,
    required this.canDelete,
    required this.onUndo,
    required this.onReset,
    required this.onEdit,
    required this.onDelete,
  });
  final TasbihItem item;
  final bool active;
  final bool canDelete;
  final VoidCallback onUndo, onReset, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    final muted = context.tokens.muted;
    return AnimatedScale(
      scale: active ? 1 : 0.92,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(6, 4, 6, 26),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.tokens.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: item.arabic.isEmpty
                      ? Text(item.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700))
                      : Text(item.arabic, textDirection: TextDirection.rtl, style: arabicStyle(size: 30, height: 1.5)),
                ),
                if (item.arabic.isNotEmpty)
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 14),
                  ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(children: [_Chip('Round', item.rounds), const SizedBox(width: 10), _Chip('Total', item.total)]),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    RollingText(
                      '${item.inRound}',
                      style: TextStyle(
                        fontSize: 46,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      item.target == 0 ? '  / ∞' : '  / ${item.target}',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 2,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !active,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: accent, width: 1.6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionDot(Icons.undo_rounded, AppColors.warning, 'Undo', item.count == 0 ? null : onUndo),
                      _ActionDot(Icons.restart_alt_rounded, AppColors.warning, 'Reset', item.count == 0 ? null : onReset),
                      _ActionDot(Icons.edit_rounded, accent, 'Edit', onEdit),
                      _ActionDot(Icons.delete_rounded, AppColors.danger, 'Delete', canDelete ? onDelete : null),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: context.tokens.accentSoft,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: context.colors.primary.withValues(alpha: 0.15)),
    ),
    child: Text.rich(
      TextSpan(
        text: '$label: ',
        style: TextStyle(color: context.tokens.muted, fontSize: 13),
        children: [
          TextSpan(
            text: '$value',
            style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _ActionDot extends StatelessWidget {
  const _ActionDot(this.icon, this.color, this.tooltip, this.onTap);
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Pressable(
      onTap: onTap,
      scale: 0.85,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedOpacity(
          opacity: onTap == null ? 0.4 : 1,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

/// Draws one glossy bead with its drop shadow.
void _paintBead(Canvas canvas, Offset c, double r, (Color, Color, Color) palette) {
  canvas.drawOval(
    Rect.fromCenter(center: c + Offset(r * 0.12, r * 0.95), width: r * 1.7, height: r * 0.45),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22),
  );
  final rect = Rect.fromCircle(center: c, radius: r);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 1.05,
        colors: [palette.$1, palette.$2, palette.$3],
        stops: const [0, 0.5, 1],
      ).createShader(rect),
  );
  // Soft reflected light along the lower rim.
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.3, 0.9),
        radius: 0.6,
        colors: [palette.$1.withValues(alpha: 0.35), palette.$1.withValues(alpha: 0)],
      ).createShader(rect),
  );
  canvas.drawCircle(
    c + Offset(-r * 0.36, -r * 0.4),
    r * 0.11,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05),
  );
}

/// A string of beads with a gap: counted beads gather on the left, the next one crosses the gap.
class _BeadsPainter extends CustomPainter {
  _BeadsPainter({required this.slide, required this.state, required this.palette}) : super(repaint: Listenable.merge([slide, state]));
  final Animation<double> slide;
  final AppState state;
  final (Color, Color, Color) palette;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = math.min(w * 0.06, size.height * 0.16);
    final d = r * 1.96;
    final gapStart = w * 0.4;
    final gapEnd = w * 0.76;
    double y(double x) => size.height * 0.5 + (w * 0.5 - x) * 0.17 + math.sin(x / w * math.pi * 2) * w * 0.018;

    final string = Path()..moveTo(-r, y(-r));
    for (var x = -r; x <= w + r; x += 6) {
      string.lineTo(x, y(x));
    }
    canvas.drawPath(
      string,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = palette.$2.withValues(alpha: 0.35),
    );

    // Bead k's position for a fractional count n + f; continuous as f wraps from 1 to 0.
    final n = state.tasbih.count;
    final f = slide.value;
    double pos(int k) {
      if (k < n) return gapStart - (n - 1 - k) * d - f * d;
      if (k == n) return gapEnd + (gapStart - gapEnd) * f;
      return gapEnd + (k - n) * d - f * d;
    }

    final visible = (w / d).ceil() + 2;
    for (var k = n - visible; k <= n + visible; k++) {
      final x = pos(k);
      if (x < -r * 2 || x > w + r * 2) continue;
      final lift = k == n ? 1 + 0.06 * math.sin(math.pi * f) : 1.0;
      _paintBead(canvas, Offset(x, y(x)), r * lift, palette);
    }
  }

  @override
  bool shouldRepaint(_BeadsPainter old) => old.palette != palette;
}

class _BeadPicker extends StatelessWidget {
  const _BeadPicker({required this.selected, required this.onPick});
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: context.tokens.muted.withValues(alpha: 0.6), width: 1.2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < beadPalettes.length; i++)
          Pressable(
            scale: 0.85,
            onTap: () {
              HapticFeedback.selectionClick();
              onPick(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: i == selected ? context.colors.primary : Colors.transparent, width: 2),
              ),
              child: CustomPaint(size: const Size.square(28), painter: _SwatchPainter(beadPalettes[i])),
            ),
          ),
      ],
    ),
  );
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter(this.palette);
  final (Color, Color, Color) palette;

  @override
  void paint(Canvas canvas, Size size) => _paintBead(canvas, size.center(Offset.zero), size.width / 2, palette);

  @override
  bool shouldRepaint(_SwatchPainter old) => old.palette != palette;
}

/// Add or edit a counter; pops (name, arabic, target).
class _TasbihEditor extends StatefulWidget {
  const _TasbihEditor({this.initial});
  final TasbihItem? initial;

  @override
  State<_TasbihEditor> createState() => _TasbihEditorState();
}

class _TasbihEditorState extends State<_TasbihEditor> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _arabic = TextEditingController(text: widget.initial?.arabic);
  late int _target = widget.initial?.target ?? 33;
  late final _custom = TextEditingController();

  static const _goals = [33, 34, 99, 100, 0];

  @override
  void initState() {
    super.initState();
    if (!_goals.contains(_target)) _custom.text = '$_target';
  }

  @override
  void dispose() {
    _name.dispose();
    _arabic.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name, _arabic.text.trim(), _target));
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.initial == null ? 'Add tasbih' : 'Edit tasbih', style: context.text.titleLarge?.copyWith(fontSize: 18)),
            if (widget.initial == null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in tasbihPresets)
                    ActionChip(
                      label: Text(p.$1),
                      onPressed: () => setState(() {
                        _name.text = p.$1;
                        _arabic.text = p.$2;
                        _target = p.$3;
                        _custom.clear();
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. SubhanAllah'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _arabic,
              textDirection: TextDirection.rtl,
              style: arabicStyle(size: 20, height: 1.4),
              decoration: const InputDecoration(labelText: 'Arabic (optional)'),
            ),
            const SizedBox(height: 16),
            Text(
              'Goal per round',
              style: TextStyle(color: context.tokens.muted, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final g in _goals) ...[
                  Expanded(
                    child: Pressable(
                      onTap: () => setState(() {
                        _target = g;
                        _custom.clear();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _target == g && _custom.text.isEmpty ? accent : context.colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          g == 0 ? '∞' : '$g',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: g == 0 ? 18 : 14,
                            color: _target == g && _custom.text.isEmpty ? Colors.white : context.tokens.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (g != _goals.last) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _custom,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Custom goal'),
              onChanged: (v) => setState(() => _target = int.tryParse(v) ?? 33),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _name.text.trim().isEmpty ? null : _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasbihSettingsSheet extends StatelessWidget {
  const _TasbihSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Tasbih settings', style: context.text.titleLarge?.copyWith(fontSize: 18)),
            ),
            SwitchListTile(
              value: s.tasbihVibrate,
              onChanged: (v) => s.setTasbihFeedback(vibrate: v),
              secondary: const Icon(Icons.vibration_rounded),
              title: const Text('Vibration'),
            ),
            SwitchListTile(
              value: s.tasbihSound,
              onChanged: (v) => s.setTasbihFeedback(sound: v),
              secondary: const Icon(Icons.volume_up_rounded),
              title: const Text('Click sound'),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded),
              title: const Text('History'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                showSheet(context, (_) => const TasbihHistorySheet());
              },
            ),
            ListTile(
              leading: const Icon(Icons.fullscreen_rounded),
              title: const Text('Full screen counter'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (_, _, _) => const TasbihFullscreen(),
                    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Distraction-free counter: the whole screen is the tap target.
class TasbihFullscreen extends StatefulWidget {
  const TasbihFullscreen({super.key});

  @override
  State<TasbihFullscreen> createState() => _TasbihFullscreenState();
}

class _TasbihFullscreenState extends State<TasbihFullscreen> with SingleTickerProviderStateMixin {
  late final _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _ripple.dispose();
    super.dispose();
  }

  void _tap() {
    countTasbih();
    _ripple.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    return Scaffold(
      backgroundColor: const Color(0xFF052E22),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final t = s.tasbih;
          final (inRound, progress) = tasbihRoundProgress();
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            child: Stack(
              children: [
                // Soft expanding glow on each tap.
                Center(
                  child: AnimatedBuilder(
                    animation: _ripple,
                    builder: (_, _) => Container(
                      width: 200 + _ripple.value * 260,
                      height: 200 + _ripple.value * 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentLight.withValues(alpha: (1 - _ripple.value) * 0.18),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      t.arabic.isEmpty
                          ? Text(
                              t.name,
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600),
                            )
                          : Text(
                              t.arabic,
                              textDirection: TextDirection.rtl,
                              style: arabicStyle(size: 34, color: Colors.white, height: 1.6),
                            ),
                      const SizedBox(height: 12),
                      Text(
                        '$inRound',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 120,
                          fontWeight: FontWeight.w200,
                          letterSpacing: -4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (t.target > 0) ...[
                        SizedBox(
                          width: 180,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: progress),
                              duration: const Duration(milliseconds: 250),
                              builder: (_, v, _) => LinearProgressIndicator(
                                value: v,
                                minHeight: 4,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Round ${t.rounds + 1} · target ${t.target}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 32,
                  child: SafeArea(
                    child: Text(
                      'Tap anywhere',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TasbihHistorySheet extends StatelessWidget {
  const TasbihHistorySheet({super.key});

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final counts = [for (final d in days) s.tasbihOn(d)];
    final max = counts.fold<int>(0, math.max);
    final week = counts.fold<int>(0, (a, b) => a + b);
    var streak = 0;
    for (var d = today; s.tasbihOn(d) > 0; d = d.subtract(const Duration(days: 1))) {
      streak++;
    }
    final accent = context.colors.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 7 days', style: context.text.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: 20),
            SizedBox(
              height: 170,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              counts[i] == 0 ? '' : '${counts[i]}',
                              style: TextStyle(fontSize: 11, color: context.tokens.muted, fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                            const SizedBox(height: 4),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: max == 0 ? 0 : counts[i] / max),
                              duration: Duration(milliseconds: 400 + i * 60),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) => Container(
                                height: 4 + v * 116,
                                decoration: BoxDecoration(
                                  color: i == days.length - 1 ? accent : accent.withValues(alpha: counts[i] == 0 ? 0.12 : 0.45),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              i == days.length - 1 ? 'Today' : _weekdays[days[i].weekday - 1],
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: i == days.length - 1 ? FontWeight.w700 : FontWeight.w500,
                                color: i == days.length - 1 ? accent : context.tokens.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _stat(context, 'Today', '${counts.last}'),
                const SizedBox(width: 12),
                _stat(context, 'This week', '$week'),
                const SizedBox(width: 12),
                _stat(context, 'Streak', '$streak ${streak == 1 ? 'day' : 'days'}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Expanded(
    child: Panel(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(label, style: context.text.bodySmall?.copyWith(fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    ),
  );
}

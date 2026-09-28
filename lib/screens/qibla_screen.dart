import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../services/prayer_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'location_sheet.dart';

enum _Mode { compass, digital, arrow }

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<CompassEvent>? _sub;
  double? _heading;
  // Continuous (unwrapped) heading so rotations never spin the long way round.
  double _unwrapped = 0;
  bool _aligned = false;
  bool _noSensor = kIsWeb;
  _Mode _mode = _Mode.compass;

  double get _qibla => PrayerService.qibla(AppState.instance.location.lat, AppState.instance.location.lng);

  /// Signed angle to turn (−180..180); positive means turn right.
  double _offset(double heading) => ((_qibla - heading + 540) % 360) - 180;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only listen to the sensor while this tab is visible.
    TickerMode.valuesOf(context).enabled ? _listen() : _stop();
  }

  void _listen() {
    if (_sub != null || kIsWeb) return;
    final events = FlutterCompass.events;
    if (events == null) {
      setState(() => _noSensor = true);
      return;
    }
    _sub = events.listen((e) {
      final h = e.heading;
      if (h == null) {
        if (!_noSensor) setState(() => _noSensor = true);
        return;
      }
      if (_heading == null) _unwrapped = h;
      final prev = _heading ?? h;
      var delta = (h - prev) % 360;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      final aligned = _offset(h).abs() < 3;
      if (aligned && !_aligned) HapticFeedback.mediumImpact();
      setState(() {
        _heading = (h + 360) % 360;
        _unwrapped += delta;
        _aligned = aligned;
        _noSensor = false;
      });
    });
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final loc = AppState.instance.location;
        final heading = _heading;
        final qibla = _qibla;
        final km = Geolocator.distanceBetween(loc.lat, loc.lng, 21.4225241, 39.8261818) / 1000;

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text('Qibla Direction', style: context.text.headlineMedium?.copyWith(fontSize: 26)),
              const SizedBox(height: 14),
              Center(
                child: Pressable(
                  onTap: () => pickLocation(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(color: context.tokens.accentSoft, borderRadius: BorderRadius.circular(99)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.place_rounded, size: 16, color: accent),
                        const SizedBox(width: 6),
                        Flexible(child: Text(loc.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500))),
                        const SizedBox(width: 8),
                        Icon(Icons.my_location_rounded, size: 16, color: accent),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final m in _Mode.values) ...[
                    Expanded(child: _modeButton(context, m)),
                    if (m != _Mode.arrow) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              AspectRatio(
                aspectRatio: 1,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: c)),
                  child: KeyedSubtree(key: ValueKey(_mode), child: _visual(context, qibla)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TweenAnimationBuilder<double>(
                  // Tween the unwrapped value so 359° → 1° doesn't count down through 180°.
                  tween: Tween(end: heading == null ? qibla : _unwrapped),
                  duration: const Duration(milliseconds: 250),
                  builder: (_, v, _) => Text(
                    '${(((v % 360) + 360) % 360).round() % 360}°',
                    style: TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1.5, height: 1),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 20, height: 20, child: KaabaIcon()),
                    const SizedBox(width: 8),
                    Text('Qibla: ${qibla.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _StatusPill(aligned: _aligned, noSensor: _noSensor, heading: heading, offset: heading == null ? 0 : _offset(heading)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _stat(context, 'Latitude', loc.lat.toStringAsFixed(4)),
                  const SizedBox(width: 10),
                  _stat(context, 'Longitude', loc.lng.toStringAsFixed(4)),
                  const SizedBox(width: 10),
                  _stat(context, 'To Makkah', '${km.round()} km'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _noSensor
                    ? 'No compass on this device. Face ${qibla.toStringAsFixed(0)}° clockwise from true north.'
                    : 'Hold your phone flat, away from metal. Move it in a figure-8 to calibrate.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modeButton(BuildContext context, _Mode m) {
    final selected = _mode == m;
    final accent = context.colors.primary;
    final (label, icon) = switch (m) {
      _Mode.compass => ('Compass', Icons.explore_outlined),
      _Mode.digital => ('Digital', Icons.speed_rounded),
      _Mode.arrow => ('Arrow', Icons.navigation_rounded),
    };
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _mode = m);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : context.tokens.muted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: selected ? Colors.white : null)),
          ],
        ),
      ),
    );
  }

  Widget _visual(BuildContext context, double qibla) {
    final accent = context.colors.primary;
    final turns = _noSensor ? 0.0 : -_unwrapped / 360;
    switch (_mode) {
      case _Mode.compass:
        return Stack(
          alignment: Alignment.center,
          children: [
            AnimatedRotation(
              turns: turns,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: CustomPaint(
                size: Size.infinite,
                painter: _CompassPainter(
                  qibla: qibla,
                  accent: accent,
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
                child: LayoutBuilder(
                  builder: (context, c) {
                    // Kaaba sits on the rim at the Qibla bearing.
                    final r = c.maxWidth / 2 - 26;
                    final a = (qibla - 90) * math.pi / 180;
                    return Stack(
                      children: [
                        Positioned(
                          left: c.maxWidth / 2 + math.cos(a) * r - 15,
                          top: c.maxHeight / 2 + math.sin(a) * r - 15,
                          child: Transform.rotate(
                            angle: qibla * math.pi / 180,
                            child: const SizedBox(width: 30, height: 30, child: KaabaIcon()),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 4,
                height: 18,
                decoration: BoxDecoration(color: _aligned ? accent : context.colors.onSurface, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ],
        );
      case _Mode.digital:
        return _DigitalView(heading: _heading ?? 0, unwrapped: _noSensor ? qibla : _unwrapped, qibla: qibla, aligned: _aligned);
      case _Mode.arrow:
        final offsetTurns = (qibla - (_noSensor ? 0 : _unwrapped)) / 360;
        return Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _aligned ? accent : context.tokens.accentSoft,
            ),
            child: AnimatedRotation(
              turns: offsetTurns,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Icon(Icons.navigation_rounded, size: 150, color: _aligned ? Colors.white : accent),
            ),
          ),
        );
    }
  }

  Widget _stat(BuildContext context, String label, String value) => Expanded(
        child: Panel(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            children: [
              Text(label, style: context.text.bodySmall?.copyWith(fontSize: 11.5)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.aligned, required this.noSensor, required this.heading, required this.offset});
  final bool aligned;
  final bool noSensor;
  final double? heading;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    final text = noSensor
        ? 'Compass sensor unavailable'
        : heading == null
            ? 'Calibrating…'
            : aligned
                ? 'You are facing the Qibla'
                : 'Turn ${offset > 0 ? 'right' : 'left'} ${offset.abs().round()}°';
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: aligned ? accent : context.tokens.accentSoft, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(color: aligned ? Colors.white : accent, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

/// A horizontal compass tape that slides with the heading.
class _DigitalView extends StatelessWidget {
  const _DigitalView({required this.heading, required this.unwrapped, required this.qibla, required this.aligned});
  final double heading;
  final double unwrapped;
  final double qibla;
  final bool aligned;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    return Center(
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: aligned ? accent : context.tokens.border, width: aligned ? 2 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: unwrapped),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (_, v, _) => CustomPaint(
              size: Size.infinite,
              painter: _TapePainter(
                heading: v,
                qibla: qibla,
                accent: accent,
                text: context.colors.onSurface,
                muted: context.tokens.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TapePainter extends CustomPainter {
  _TapePainter({required this.heading, required this.qibla, required this.accent, required this.text, required this.muted});
  final double heading, qibla;
  final Color accent, text, muted;

  static const _pxPerDeg = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseline = size.height * 0.62;
    const names = {0: 'N', 45: 'NE', 90: 'E', 135: 'SE', 180: 'S', 225: 'SW', 270: 'W', 315: 'NW'};
    final span = size.width / 2 / _pxPerDeg + 10;
    for (var d = (heading - span).floor(); d <= heading + span; d++) {
      final x = cx + (d - heading) * _pxPerDeg;
      final deg = ((d % 360) + 360) % 360;
      if (deg % 5 != 0) continue;
      final major = deg % 15 == 0;
      canvas.drawLine(
        Offset(x, baseline),
        Offset(x, baseline - (major ? 26 : 14)),
        Paint()
          ..color = major ? text.withValues(alpha: 0.7) : muted.withValues(alpha: 0.5)
          ..strokeWidth = major ? 2 : 1,
      );
      final label = names[deg] ?? (deg % 30 == 0 ? '$deg' : null);
      if (label != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: deg == 0 ? AppColors.danger : text,
              fontWeight: names.containsKey(deg) ? FontWeight.w800 : FontWeight.w500,
              fontSize: names.containsKey(deg) ? 16 : 12,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, baseline + 10));
      }
      if ((deg - qibla.round()).abs() < 1) {
        // Qibla marker
        final path = Path()
          ..moveTo(x, baseline - 32)
          ..lineTo(x - 9, baseline - 48)
          ..lineTo(x + 9, baseline - 48)
          ..close();
        canvas.drawPath(path, Paint()..color = accent);
        final tp = TextPainter(
          text: TextSpan(text: 'QIBLA', style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, baseline - 66));
      }
    }
    // Centre reference line
    canvas.drawLine(Offset(cx, 16), Offset(cx, size.height - 16), Paint()
      ..color = accent.withValues(alpha: 0.9)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _TapePainter old) => old.heading != heading || old.qibla != qibla || old.accent != accent || old.text != text;
}

/// Metallic compass face with a red/blue rose.
class _CompassPainter extends CustomPainter {
  _CompassPainter({required this.qibla, required this.accent, required this.dark});
  final double qibla;
  final Color accent;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 4;
    final face = outer - 16;

    // Bezel
    canvas.drawCircle(c + const Offset(0, 6), outer, Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawCircle(
      c,
      outer,
      Paint()
        ..shader = SweepGradient(
          colors: dark
              ? const [Color(0xFF3A4459), Color(0xFF1C2230), Color(0xFF4A566E), Color(0xFF1C2230), Color(0xFF3A4459)]
              : const [Color(0xFFE9ECF1), Color(0xFF9AA3AF), Color(0xFFF8F9FB), Color(0xFF9AA3AF), Color(0xFFE9ECF1)],
        ).createShader(Rect.fromCircle(center: c, radius: outer)),
    );
    // Face
    canvas.drawCircle(
      c,
      face,
      Paint()
        ..shader = RadialGradient(
          colors: dark ? const [Color(0xFF14304A), Color(0xFF0C1E30)] : const [Colors.white, Color(0xFFF1F4F8)],
        ).createShader(Rect.fromCircle(center: c, radius: face)),
    );

    final ink = dark ? const Color(0xFFF2F6FA) : const Color(0xFF12241C);
    for (var d = 0; d < 360; d += 2) {
      final major = d % 30 == 0;
      final mid = d % 10 == 0;
      final a = (d - 90) * math.pi / 180;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * (face - 4),
        c + dir * (face - (major ? 18 : mid ? 12 : 7)),
        Paint()
          ..color = ink.withValues(alpha: major ? 0.85 : 0.45)
          ..strokeWidth = major ? 1.8 : 0.9,
      );
      if (major && d % 90 != 0) {
        _label(canvas, c + dir * (face - 30), '$d', d, TextStyle(color: ink.withValues(alpha: 0.55), fontSize: 10, fontWeight: FontWeight.w500));
      }
    }
    const cardinals = {'N': 0, 'E': 90, 'S': 180, 'W': 270};
    cardinals.forEach((l, d) {
      final a = (d - 90) * math.pi / 180;
      _label(canvas, c + Offset(math.cos(a), math.sin(a)) * (face - 32), l, d,
          TextStyle(color: l == 'N' ? AppColors.danger : ink, fontWeight: FontWeight.w800, fontSize: 18, fontFamily: 'serif'));
    });
    const inter = {'NE': 45, 'SE': 135, 'SW': 225, 'NW': 315};
    inter.forEach((l, d) {
      final a = (d - 90) * math.pi / 180;
      _label(canvas, c + Offset(math.cos(a), math.sin(a)) * (face * 0.45), l, d,
          TextStyle(color: ink.withValues(alpha: 0.6), fontWeight: FontWeight.w600, fontSize: 11, fontFamily: 'serif'));
    });

    // Compass rose: thin 8-point star
    final rose = Paint()..color = ink.withValues(alpha: 0.85);
    for (var d = 45; d < 360; d += 90) {
      _needle(canvas, c, d.toDouble(), face * 0.42, 6, rose);
    }
    for (var d = 90; d < 360; d += 180) {
      _needle(canvas, c, d.toDouble(), face * 0.58, 8, rose);
    }
    // North (red) and south (blue) needles
    _needle(canvas, c, 0, face * 0.66, 10, Paint()..color = AppColors.danger);
    _needle(canvas, c, 180, face * 0.66, 10, Paint()..color = accent);

    // Qibla line from centre to rim
    final qa = (qibla - 90) * math.pi / 180;
    canvas.drawLine(
      c,
      c + Offset(math.cos(qa), math.sin(qa)) * (face - 40),
      Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Hub
    canvas.drawCircle(
      c,
      9,
      Paint()
        ..shader = const RadialGradient(colors: [Colors.white, Color(0xFF9CA3AF)]).createShader(Rect.fromCircle(center: c, radius: 9)),
    );
  }

  void _needle(Canvas canvas, Offset c, double deg, double length, double width, Paint paint) {
    final a = (deg - 90) * math.pi / 180;
    final dir = Offset(math.cos(a), math.sin(a));
    final perp = Offset(-dir.dy, dir.dx);
    final path = Path()
      ..moveTo(c.dx + dir.dx * length, c.dy + dir.dy * length)
      ..lineTo(c.dx + perp.dx * width, c.dy + perp.dy * width)
      ..lineTo(c.dx - perp.dx * width, c.dy - perp.dy * width)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _label(Canvas canvas, Offset at, String text, int deg, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(deg * math.pi / 180);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) => old.qibla != qibla || old.accent != accent || old.dark != dark;
}

/// Small Kaaba glyph: black cube with a gold band.
class KaabaIcon extends StatelessWidget {
  const KaabaIcon({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _KaabaPainter());
}

class _KaabaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.1, h * 0.18, w * 0.8, h * 0.74), Radius.circular(w * 0.08));
    canvas.drawRRect(body, Paint()..color = const Color(0xFF111111));
    // Top face for a hint of depth
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.18, w * 0.8, h * 0.08), Paint()..color = const Color(0xFF3A3A3A));
    // Kiswa band
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.34, w * 0.8, h * 0.1), Paint()..color = const Color(0xFFD4A537));
    // Door
    canvas.drawRect(Rect.fromLTWH(w * 0.6, h * 0.56, w * 0.16, h * 0.3), Paint()..color = const Color(0xFFD4A537).withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

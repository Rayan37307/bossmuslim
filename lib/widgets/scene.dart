import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/prayer_service.dart';

/// Sky palette for each part of the day, all within the blue family.
class SkyPalette {
  const SkyPalette(this.colors, {this.stars = false, this.moon = false, this.glow});
  final List<Color> colors;
  final bool stars;
  final bool moon;
  final Color? glow; // horizon glow near sunrise / sunset

  static SkyPalette forPeriod(Salah? current, Salah next) {
    final phase = current ?? (next == Salah.dhuhr ? Salah.sunrise : next);
    return switch (phase) {
      Salah.fajr => const SkyPalette([Color(0xFF06281D), Color(0xFF0F5A40)], stars: true, moon: true, glow: Color(0xFF6EE7B7)),
      Salah.sunrise => const SkyPalette([Color(0xFF0B6B4A), Color(0xFF34C98E)], glow: Color(0xFFFCD34D)),
      Salah.dhuhr => const SkyPalette([Color(0xFF0E7A54), Color(0xFF3FD19B)]),
      Salah.asr => const SkyPalette([Color(0xFF0A5C40), Color(0xFF22A474)], glow: Color(0xFFFDE68A)),
      Salah.maghrib => const SkyPalette([Color(0xFF093D2C), Color(0xFF157A58)], glow: Color(0xFFFB923C)),
      Salah.isha => const SkyPalette([Color(0xFF03130D), Color(0xFF0B3325)], stars: true, moon: true),
    };
  }
}

class SkyScene extends StatelessWidget {
  const SkyScene({super.key, required this.palette, required this.child});
  final SkyPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: palette.colors,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _SkyPainter(palette, t))),
            Positioned.fill(child: CustomPaint(painter: _MosquePainter(t))),
            child,
          ],
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.p, this.t);
  final SkyPalette p;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (p.glow != null) {
      final rect = Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.55);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.glow!.withValues(alpha: 0), p.glow!.withValues(alpha: 0.35 * t)],
          ).createShader(rect),
      );
    }
    if (p.stars) {
      final rnd = math.Random(7);
      final paint = Paint()..color = Colors.white;
      for (var i = 0; i < 46; i++) {
        final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.7);
        paint.color = Colors.white.withValues(alpha: (0.25 + rnd.nextDouble() * 0.6) * t);
        canvas.drawCircle(o, 0.6 + rnd.nextDouble() * 1.1, paint);
      }
    }
    final c = Offset(size.width * 0.86, size.height * 0.42 + (1 - t) * 20);
    if (p.moon) {
      // Crescent: a disc minus an offset disc.
      final moon = Path()..addOval(Rect.fromCircle(center: c, radius: 14));
      final cut = Path()..addOval(Rect.fromCircle(center: c + const Offset(6, -4), radius: 12));
      canvas.drawPath(
        Path.combine(PathOperation.difference, moon, cut),
        Paint()..color = const Color(0xFFFFF4C2).withValues(alpha: 0.95 * t),
      );
    } else {
      canvas.drawCircle(c, 34, Paint()..color = Colors.white.withValues(alpha: 0.10 * t));
      canvas.drawCircle(c, 16, Paint()..color = const Color(0xFFFFF7D6).withValues(alpha: 0.9 * t));
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.p != p || old.t != t;
}

/// Minimal mosque skyline anchored to the bottom-right.
class _MosquePainter extends CustomPainter {
  _MosquePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final base = h + (1 - t) * 30;
    final back = Paint()..color = Colors.black.withValues(alpha: 0.18);
    final front = Paint()..color = Colors.black.withValues(alpha: 0.30);

    void minaret(Paint p, double x, double top, double width) {
      final path = Path()
        ..addRect(Rect.fromLTRB(x, top, x + width, base))
        ..addRect(Rect.fromLTRB(x - 2, top + 18, x + width + 2, top + 22))
        ..moveTo(x - 1, top)
        ..quadraticBezierTo(x + width / 2, top - 16, x + width + 1, top)
        ..close()
        ..addRect(Rect.fromLTRB(x + width / 2 - 0.6, top - 24, x + width / 2 + 0.6, top - 12));
      canvas.drawPath(path, p);
    }

    void dome(Paint p, double cx, double top, double radius, double bodyTop) {
      final path = Path()
        ..addRect(Rect.fromLTRB(cx - radius * 1.25, bodyTop, cx + radius * 1.25, base))
        ..moveTo(cx - radius, bodyTop)
        ..cubicTo(cx - radius, top + radius * 0.2, cx - radius * 0.2, top, cx, top - radius * 0.35)
        ..cubicTo(cx + radius * 0.2, top, cx + radius, top + radius * 0.2, cx + radius, bodyTop)
        ..close()
        ..addRect(Rect.fromLTRB(cx - 0.8, top - radius * 0.35 - 12, cx + 0.8, top - radius * 0.35));
      canvas.drawPath(path, p);
    }

    // Distant layer
    dome(back, w * 0.48, h - 70, 22, h - 50);
    minaret(back, w * 0.36, h - 110, 7);

    // Main mosque
    dome(front, w * 0.74, h - 92, 34, h - 58);
    dome(front, w * 0.60, h - 56, 16, h - 40);
    dome(front, w * 0.88, h - 56, 16, h - 40);
    minaret(front, w * 0.53, h - 128, 8);
    minaret(front, w * 0.95, h - 128, 8);
  }

  @override
  bool shouldRepaint(covariant _MosquePainter old) => old.t != t;
}

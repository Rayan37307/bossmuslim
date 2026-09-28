import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Optional artwork. Drop files with these names into assets/images/ and they replace the painted fallbacks.
class Art {
  static const nightSky = 'assets/images/night_sky.jpg';
  static const lanterns = 'assets/images/lanterns.png';
  static const quranStand = 'assets/images/quran_stand.png';
}

/// Shows [asset] if it is bundled, otherwise [fallback].
class AssetOr extends StatelessWidget {
  const AssetOr(this.asset, {super.key, required this.fallback, this.fit = BoxFit.contain, this.alignment = Alignment.center});
  final String asset;
  final Widget fallback;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Image.asset(
        asset,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, _, _) => fallback,
      );
}

/// Starry navy sky with a faint mosque skyline; sits behind every page.
class NightBackground extends StatelessWidget {
  const NightBackground({super.key});

  @override
  Widget build(BuildContext context) => const RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bgTop, AppColors.bg, Color(0xFF050C15)],
              stops: [0, 0.55, 1],
            ),
          ),
          child: AssetOr(Art.nightSky, fit: BoxFit.cover, fallback: CustomPaint(painter: _SkyPainter(), size: Size.infinite)),
        ),
      );
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Soft haze near the top.
    canvas.drawCircle(
      Offset(w * 0.8, h * 0.08),
      w * 0.7,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFF2B6F8A).withValues(alpha: 0.16), Colors.transparent])
            .createShader(Rect.fromCircle(center: Offset(w * 0.8, h * 0.08), radius: w * 0.7)),
    );

    final rnd = math.Random(3);
    final star = Paint();
    for (var i = 0; i < 170; i++) {
      final o = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.8);
      final big = rnd.nextDouble() > 0.93;
      final r = big ? 1.2 + rnd.nextDouble() * 0.8 : 0.4 + rnd.nextDouble() * 0.7;
      final a = big ? 0.8 : 0.15 + rnd.nextDouble() * 0.45;
      if (big) {
        canvas.drawCircle(o, r * 4, star..color = Colors.white.withValues(alpha: 0.06));
      }
      canvas.drawCircle(o, r, star..color = Colors.white.withValues(alpha: a));
    }

    _skyline(canvas, size);
  }

  void _skyline(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final base = h;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF0C1C2C).withValues(alpha: 0.0), const Color(0xFF0A1826).withValues(alpha: 0.9)],
      ).createShader(Rect.fromLTWH(0, h * 0.62, w, h * 0.38));

    final p = Path();
    void minaret(double x, double top, double width) {
      p.addRect(Rect.fromLTRB(x, top, x + width, base));
      p.addRect(Rect.fromLTRB(x - width * 0.35, top + width * 1.6, x + width * 1.35, top + width * 2.0));
      p.moveTo(x - width * 0.1, top);
      p.quadraticBezierTo(x + width / 2, top - width * 2.2, x + width * 1.1, top);
      p.close();
    }

    void dome(double cx, double top, double r) {
      p.addRect(Rect.fromLTRB(cx - r, top + r * 0.9, cx + r, base));
      p.moveTo(cx - r * 1.05, top + r);
      p.cubicTo(cx - r * 1.2, top, cx - r * 0.2, top - r * 0.2, cx, top - r * 0.75);
      p.cubicTo(cx + r * 0.2, top - r * 0.2, cx + r * 1.2, top, cx + r * 1.05, top + r);
      p.close();
    }

    final y = h * 0.78;
    dome(w * 0.5, y, w * 0.13);
    dome(w * 0.28, y + w * 0.1, w * 0.07);
    dome(w * 0.72, y + w * 0.1, w * 0.07);
    minaret(w * 0.12, y - w * 0.05, w * 0.03);
    minaret(w * 0.85, y - w * 0.05, w * 0.03);
    p.addRect(Rect.fromLTRB(0, y + w * 0.2, w, base));
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => false;
}

/// Gold crescent with hanging lanterns (painted until [Art.lanterns] is added).
class LanternArt extends StatelessWidget {
  const LanternArt({super.key});

  @override
  Widget build(BuildContext context) =>
      const AssetOr(Art.lanterns, alignment: Alignment.topCenter, fallback: CustomPaint(painter: _LanternPainter(), size: Size.infinite));
}

class _LanternPainter extends CustomPainter {
  const _LanternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final s = math.min(w / 1.3, h);

    // Crescent: a disc minus an offset disc, filled with gold.
    final c = Offset(w * 0.36, h * 0.58);
    final r = s * 0.34;
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()..addOval(Rect.fromCircle(center: c + Offset(r * 0.42, -r * 0.3), radius: r * 0.86)),
    );
    canvas.drawPath(moon.shift(const Offset(0, 6)), Paint()..color = Colors.black.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawPath(
      moon,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6DDA0), AppColors.gold, Color(0xFF9C7231)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Lattice dots inside the crescent.
    canvas.save();
    canvas.clipPath(moon);
    final dot = Paint()..color = const Color(0xFF1B2B4A).withValues(alpha: 0.55);
    for (var y = c.dy - r; y < c.dy + r; y += r * 0.16) {
      for (var x = c.dx - r; x < c.dx + r; x += r * 0.16) {
        canvas.drawCircle(Offset(x, y), r * 0.035, dot);
      }
    }
    canvas.restore();

    _lantern(canvas, Offset(w * 0.68, h * 0.34), s * 0.19, h);
    _lantern(canvas, Offset(w * 0.9, h * 0.5), s * 0.21, h);
  }

  void _lantern(Canvas canvas, Offset top, double lw, double h) {
    final gold = Paint()..color = AppColors.gold;
    canvas.drawLine(Offset(top.dx, 0), top, Paint()..color = AppColors.gold.withValues(alpha: 0.7)..strokeWidth = 1.2);
    final bodyTop = top.dy + lw * 0.5;
    final bodyH = lw * 1.5;
    // Warm glow.
    final glowC = Offset(top.dx, bodyTop + bodyH * 0.55);
    canvas.drawCircle(
      glowC,
      lw * 1.6,
      Paint()..shader = RadialGradient(colors: [const Color(0xFFFFD27A).withValues(alpha: 0.35), Colors.transparent]).createShader(Rect.fromCircle(center: glowC, radius: lw * 1.6)),
    );
    // Cap.
    final cap = Path()
      ..moveTo(top.dx - lw * 0.5, bodyTop)
      ..quadraticBezierTo(top.dx, top.dy - lw * 0.1, top.dx + lw * 0.5, bodyTop)
      ..close();
    canvas.drawPath(cap, gold);
    canvas.drawCircle(top, lw * 0.08, gold);
    // Glass body.
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(top.dx - lw * 0.42, bodyTop, lw * 0.84, bodyH), Radius.circular(lw * 0.18));
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF1C9), Color(0xFFFFC862), Color(0xFFE39A3A)],
        ).createShader(body.outerRect),
    );
    final frame = Paint()
      ..color = const Color(0xFFB8893F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lw * 0.06;
    canvas.drawRRect(body, frame);
    canvas.drawLine(Offset(top.dx, bodyTop), Offset(top.dx, bodyTop + bodyH), frame);
    // Base.
    final base = Path()
      ..moveTo(top.dx - lw * 0.5, bodyTop + bodyH)
      ..lineTo(top.dx + lw * 0.5, bodyTop + bodyH)
      ..lineTo(top.dx, bodyTop + bodyH + lw * 0.45)
      ..close();
    canvas.drawPath(base, gold);
  }

  @override
  bool shouldRepaint(_LanternPainter old) => false;
}

/// Open Quran on a stand (glowing icon until [Art.quranStand] is added).
class QuranStandArt extends StatelessWidget {
  const QuranStandArt({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: AssetOr(
          Art.quranStand,
          fallback: Icon(
            Icons.menu_book_rounded,
            size: size * 0.7,
            color: AppColors.gold,
            shadows: [Shadow(color: AppColors.gold.withValues(alpha: 0.55), blurRadius: 30)],
          ),
        ),
      );
}

/// Rounded-square glass button with a thin border, as used in headers.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onTap, this.tooltip, this.size = 48});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.glass,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size * 0.3), side: const BorderSide(color: Color(0x33FFFFFF))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: size, height: size, child: Icon(icon, color: Colors.white, size: size * 0.46)),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Page indicator: the current page is a teal pill, others are dots.
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == index ? AppColors.accent : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ],
      );
}

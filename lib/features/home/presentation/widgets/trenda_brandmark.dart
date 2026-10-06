// lib/features/home/presentation/widgets/trenda_brandmark.dart
// The app-bar brand lockup. Replaces the plain `Text(platformName)` title with a
// gradient monogram tile carrying a hand-drawn "trend" stroke (the name means
// trend) beside a two-tone wordmark. The name is still the admin-configured
// platform name — nothing here is hardcoded to "Trenda".
import 'package:flutter/material.dart';
import 'package:trenda_shared/widgets/app_config_gate.dart' show platformName;

const Color _kInk = Color(0xFF0B1B4D);
const Color _kBlue = Color(0xFF2563EB);
const Color _kSky = Color(0xFF3B82F6);
const Color _kGold = Color(0xFFD4AF37);

class TrendaBrandMark extends StatelessWidget {
  /// Edge of the square monogram tile; the wordmark scales off it.
  final double tileSize;

  const TrendaBrandMark({super.key, this.tileSize = 31});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The wordmark is a gradient, so it keeps the tile's colour story instead of
    // sitting next to it as flat black text.
    final wordGradient = dark
        ? const [Color(0xFFDBEAFE), Color(0xFF7DA8F7)]
        : const [_kInk, _kBlue];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tileSize * 0.31),
            gradient: const LinearGradient(
              colors: [_kInk, _kBlue, _kSky],
              stops: [0, 0.55, 1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _kBlue.withValues(alpha: dark ? 0.35 : 0.28),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: CustomPaint(painter: _TrendGlyphPainter()),
        ),
        SizedBox(width: tileSize * 0.31),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ShaderMask(
                  shaderCallback: (r) => LinearGradient(
                    colors: wordGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(r),
                  child: Text(
                    platformName,
                    style: TextStyle(
                      fontSize: tileSize * 0.63,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      color: Colors.white, // masked by the shader
                    ),
                  ),
                ),
                // A single gold accent — the same gold the Official Store uses.
                Padding(
                  padding: EdgeInsets.only(
                      left: tileSize * 0.08, bottom: tileSize * 0.13),
                  child: Container(
                    width: tileSize * 0.14,
                    height: tileSize * 0.14,
                    decoration: const BoxDecoration(
                      color: _kGold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'MARKETPLACE',
              style: TextStyle(
                fontSize: tileSize * 0.235,
                height: 1.1,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.1,
                color: dark
                    ? const Color(0xFF8FB3F5)
                    : _kBlue.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// An ascending stroke that lifts off a faint baseline, with a gold apex dot:
/// a rising trend, drawn rather than borrowed from an icon set.
class _TrendGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawLine(
      Offset(w * 0.20, h * 0.80),
      Offset(w * 0.80, h * 0.80),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.32)
        ..strokeWidth = w * 0.075
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.21, h * 0.64)
        ..lineTo(w * 0.41, h * 0.44)
        ..lineTo(w * 0.55, h * 0.56)
        ..lineTo(w * 0.79, h * 0.26),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.115
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(
      Offset(w * 0.79, h * 0.26),
      w * 0.115,
      Paint()..color = _kGold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// lib/features/stores/widgets/storefront_awning.dart
// The striped, scallop-edged canvas awning that sits over every storefront card,
// plus the plain shopfront wall drawn behind stores that have no banner photo.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/storefront_style.dart';

/// A shop awning: vertical canvas stripes clipped to a scalloped valance.
///
/// [height] is the full extent including the deepest point of the scallops.
class StorefrontAwning extends StatelessWidget {
  final AwningPalette palette;
  final double height;
  final int scallops;

  const StorefrontAwning({
    super.key,
    required this.palette,
    this.height = 30,
    this.scallops = 9,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _AwningPainter(palette: palette, scallops: scallops),
      ),
    );
  }
}

class _AwningPainter extends CustomPainter {
  final AwningPalette palette;
  final int scallops;

  const _AwningPainter({required this.palette, required this.scallops});

  /// Canvas edge: flat across the top, scalloped along the bottom. The control
  /// point sits a full [depth] below the flat edge so each scallop bottoms out
  /// at exactly `size.height`.
  Path _canvasPath(Size size) {
    final w = size.width;
    final h = size.height;
    final step = w / scallops;
    final depth = math.min(step * 0.34, h * 0.30);
    final flat = h - depth;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, flat);
    for (var i = scallops - 1; i >= 0; i--) {
      final from = step * (i + 1);
      final to = step * i;
      path.quadraticBezierTo((from + to) / 2, flat + depth * 2, to, flat);
    }
    path
      ..lineTo(0, 0)
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final path = _canvasPath(size);

    // Soft shadow the awning throws down the shopfront.
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.save();
    canvas.clipPath(path);

    // Canvas stripes.
    final stripeWidth = size.width / (scallops * 2);
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.canvas);
    final stripePaint = Paint()..color = palette.stripe;
    for (var x = 0.0, i = 0; x < size.width; x += stripeWidth, i++) {
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, stripeWidth, size.height),
          stripePaint,
        );
      }
    }

    // Sunlight across the top of the canvas, shade where it folds under.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0.02),
            Colors.black.withValues(alpha: 0.16),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();

    // Trim along the scalloped edge + the rail it hangs from.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = palette.trim.withValues(alpha: 0.55),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 2),
      Paint()..color = palette.trim.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_AwningPainter old) =>
      old.palette.stripe != palette.stripe ||
      old.palette.canvas != palette.canvas ||
      old.scallops != scallops;
}

/// The painted shopfront wall shown when a store has no banner photo: clapboard
/// boards, a doorway, and a lit window, tinted with the shop's house colour.
class StorefrontWall extends StatelessWidget {
  final AwningPalette palette;
  final Brightness brightness;

  const StorefrontWall({
    super.key,
    required this.palette,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _WallPainter(palette: palette, brightness: brightness),
    );
  }
}

class _WallPainter extends CustomPainter {
  final AwningPalette palette;
  final Brightness brightness;

  const _WallPainter({required this.palette, required this.brightness});

  @override
  void paint(Canvas canvas, Size size) {
    final dark = brightness == Brightness.dark;
    final base = Color.lerp(
      palette.stripe,
      dark ? const Color(0xFF111827) : Colors.white,
      dark ? 0.80 : 0.86,
    )!;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(base, Colors.black, dark ? 0.10 : 0.04)!,
            Color.lerp(base, dark ? Colors.black : Colors.white, 0.10)!,
          ],
        ).createShader(rect),
    );

    // Clapboard lines.
    final board = Paint()
      ..color = palette.trim.withValues(alpha: dark ? 0.14 : 0.10)
      ..strokeWidth = 1;
    for (var y = size.height * 0.18; y < size.height; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), board);
    }

    // Doorway + window, sitting on the pavement line.
    final ink = palette.trim.withValues(alpha: dark ? 0.30 : 0.22);
    final doorW = size.width * 0.14;
    final doorH = size.height * 0.46;
    final doorL = size.width * 0.58;
    final doorTop = size.height - doorH;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        doorL, doorTop, doorL + doorW, size.height,
        topLeft: Radius.circular(doorW / 2),
        topRight: Radius.circular(doorW / 2),
      ),
      Paint()..color = ink,
    );

    final winW = size.width * 0.22;
    final winL = size.width * 0.26;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(winL, doorTop + 6, winW, doorH * 0.62),
        const Radius.circular(3),
      ),
      Paint()..color = ink.withValues(alpha: dark ? 0.22 : 0.14),
    );
    canvas.drawLine(
      Offset(winL + winW / 2, doorTop + 6),
      Offset(winL + winW / 2, doorTop + 6 + doorH * 0.62),
      Paint()
        ..color = palette.trim.withValues(alpha: 0.18)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_WallPainter old) =>
      old.palette.stripe != palette.stripe || old.brightness != brightness;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Custom map markers.
///
/// Drawn rather than imported. The shape is a squircle with a short tail — a
/// softened take on the classic teardrop that sits better against the flat,
/// nearly-monochrome basemap than a glossy stock pin would.
///
/// Three details do most of the work:
///
/// * A **ring** in the surface colour separates the pin from whatever is under
///   it, so pins stay legible over parks, water and dense labels alike.
/// * The **shadow is offset downward only**, so a field of pins reads as
///   floating above the map rather than embossed into it.
/// * **Selection scales and raises** rather than recolouring, so the category
///   colour keeps meaning one thing and one thing only.
class MapPin extends StatelessWidget {
  const MapPin({
    super.key,
    required this.color,
    this.icon,
    this.glyph,
    this.selected = false,
    this.dimmed = false,
  });

  final Color color;
  final IconData? icon;
  final String? glyph;
  final bool selected;

  /// Pins outside the active filter fade rather than disappear — keeping them
  /// visible preserves the user's sense of place while filtering.
  final bool dimmed;

  static const double width = 32;
  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scale = selected ? 1.18 : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: Motion.fast,
      curve: Motion.emphasized,
      alignment: Alignment.bottomCenter,
      child: AnimatedOpacity(
        opacity: dimmed ? 0.42 : 1,
        duration: Motion.fast,
        child: CustomPaint(
          size: const Size(width, height),
          painter: _PinPainter(
            color: color,
            ring: p.surface,
            selected: selected,
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: Align(
              alignment: const Alignment(0, -0.42),
              child: icon != null
                  ? Icon(icon, size: 15, color: Colors.white)
                  : Text(
                      glyph ?? '•',
                      style: AppType.numeric(
                        color: Colors.white,
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter({
    required this.color,
    required this.ring,
    required this.selected,
  });

  final Color color;
  final Color ring;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    const tail = 7.0;
    final bodyH = size.height - tail;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, bodyH),
      const Radius.circular(11),
    );

    final path = Path()..addRRect(body);
    // The tail: a short, wide wedge. Narrow enough to read as a point, wide
    // enough not to disappear at device pixel ratios below 2.
    path.moveTo(size.width / 2 - 5, bodyH - 1);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width / 2 + 5, bodyH - 1);
    path.close();

    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: selected ? 0.28 : 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(path, Paint()..color = ring..strokeWidth = 0);
    canvas.drawPath(
      path,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinPainter old) =>
      old.color != color || old.ring != ring || old.selected != selected;
}

/// Groups of pins collapse into a count at low zoom.
class ClusterPin extends StatelessWidget {
  const ClusterPin({super.key, required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = (34 + math.min(count, 30) * 0.5).toDouble();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: p.surface, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$count',
        style: AppType.numeric(
          color: Colors.white,
          size: 12,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The user's own position: a pulsing halo around a solid dot.
///
/// Distinct in *shape* from every other marker, not just colour — at a glance
/// you should never confuse yourself with a café.
class UserLocationPin extends StatefulWidget {
  const UserLocationPin({super.key});

  @override
  State<UserLocationPin> createState() => _UserLocationPinState();
}

class _UserLocationPinState extends State<UserLocationPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        return SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 12 + 22 * t,
                height: 12 + 22 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.gold.withValues(alpha: 0.28 * (1 - t)),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: p.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.surface, width: 3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

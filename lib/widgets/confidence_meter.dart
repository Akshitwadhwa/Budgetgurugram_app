import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Certainty, drawn.
///
/// Confidence is encoded in **four redundant channels** so the meaning survives
/// greyscale, colour-blindness, and a screenshot at 30% size:
///
/// 1. **Quantity** — how many of five segments are filled.
/// 2. **Fill style** — solid, hatched, or hollow.
/// 3. **Colour** — band colour.
/// 4. **Text** — the band name, spelled out.
///
/// A percentage alone would have been easier and worse: "68%" invites the user
/// to do arithmetic about a number they cannot audit. Segments read as
/// *how much was found*, which is what the number actually means.
class ConfidenceMeter extends StatelessWidget {
  const ConfidenceMeter({
    super.key,
    required this.confidence,
    this.showLabel = true,
    this.segmentWidth = 16,
    this.animate = true,
  });

  final double confidence;
  final bool showLabel;
  final double segmentWidth;
  final bool animate;

  static const _segments = 5;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final band = ConfidenceBand.fromScore(confidence);
    final color = p.bandColor(band);
    final filled = (confidence * _segments).round().clamp(
          band == ConfidenceBand.unclear ? 1 : 2,
          _segments,
        );

    final meter = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _segments; i++)
          Padding(
            padding: EdgeInsets.only(right: i == _segments - 1 ? 0 : 3),
            child: _Segment(
              width: segmentWidth,
              color: color,
              track: p.border,
              state: i < filled
                  ? (band == ConfidenceBand.unclear
                      ? _SegState.hollow
                      : band == ConfidenceBand.possibly
                          ? _SegState.hatched
                          : _SegState.solid)
                  : _SegState.empty,
              delay: animate ? Duration(milliseconds: 60 * i) : Duration.zero,
            ),
          ),
      ],
    );

    if (!showLabel) return meter;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        meter,
        const SizedBox(width: Space.s8),
        Text(
          switch (band) {
            ConfidenceBand.likely => 'STRONG SIGNAL',
            ConfidenceBand.possibly => 'MIXED SIGNAL',
            ConfidenceBand.unclear => 'THIN SIGNAL',
          },
          style: AppType.labelS(color: color),
        ),
      ],
    );
  }
}

enum _SegState { solid, hatched, hollow, empty }

class _Segment extends StatelessWidget {
  const _Segment({
    required this.width,
    required this.color,
    required this.track,
    required this.state,
    required this.delay,
  });

  final double width;
  final Color color;
  final Color track;
  final _SegState state;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base + delay,
      curve: Interval(
        delay.inMilliseconds / (Motion.base.inMilliseconds + delay.inMilliseconds),
        1,
        curve: Motion.standard,
      ),
      builder: (context, t, _) {
        return Opacity(
          opacity: state == _SegState.empty ? 1 : t,
          child: Transform.scale(
            scaleY: state == _SegState.empty ? 1 : 0.6 + (0.4 * t),
            child: CustomPaint(
              size: Size(width, 8),
              painter: _SegmentPainter(color: color, track: track, state: state),
            ),
          ),
        );
      },
    );
  }
}

class _SegmentPainter extends CustomPainter {
  const _SegmentPainter({
    required this.color,
    required this.track,
    required this.state,
  });

  final Color color;
  final Color track;
  final _SegState state;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(2),
    );

    switch (state) {
      case _SegState.empty:
        canvas.drawRRect(rect, Paint()..color = track);

      case _SegState.solid:
        canvas.drawRRect(rect, Paint()..color = color);

      case _SegState.hatched:
        // Half-committed: a tinted ground with diagonal ruling. Reads as
        // "partially supported" even with all colour removed.
        canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.22));
        canvas.save();
        canvas.clipRRect(rect);
        final hatch = Paint()
          ..color = color
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke;
        for (double x = -size.height; x < size.width + size.height; x += 4) {
          canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), hatch);
        }
        canvas.restore();

      case _SegState.hollow:
        canvas.drawRRect(
          rect.deflate(0.6),
          Paint()
            ..color = color
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke,
        );
    }
  }

  @override
  bool shouldRepaint(_SegmentPainter old) =>
      old.state != state || old.color != color || old.track != track;
}

/// Draws a dashed rounded rectangle. Used as the border of low-confidence
/// surfaces so that *the container itself* looks provisional.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    this.radius = Radii.lg,
    this.dash = 5,
    this.gap = 4,
    this.strokeWidth = Strokes.hair,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

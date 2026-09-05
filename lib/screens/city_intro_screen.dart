import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// An original miniature-city title sequence for the app's first launch.
///
/// [audioCues] is intentionally public: an audio track can be lined up with
/// the same beats without baking sound into the experience.
class CityIntroScreen extends StatefulWidget {
  const CityIntroScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  static const Duration duration = Duration(milliseconds: 9200);

  static const Map<String, Duration> audioCues = {
    'expressway-enters-frame': Duration(milliseconds: 650),
    'company-district-lights-up': Duration(milliseconds: 2600),
    'delivery-rush': Duration(milliseconds: 4750),
    'title-lands': Duration(milliseconds: 6500),
  };

  @override
  State<CityIntroScreen> createState() => _CityIntroScreenState();
}

class _CityIntroScreenState extends State<CityIntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _scrubbing = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: CityIntroScreen.duration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _finish();
          })
          ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (_leaving) return;
    _leaving = true;
    widget.onComplete();
  }

  void _scrubStart(DragStartDetails _) {
    _scrubbing = true;
    _controller.stop();
  }

  void _scrub(DragUpdateDetails details) {
    final width = context.size?.width ?? 390;
    _controller.value = (_controller.value + details.delta.dx / width).clamp(
      0.0,
      1.0,
    );
  }

  void _scrubEnd(DragEndDetails _) {
    _scrubbing = false;
    if (_controller.value >= .98) {
      _finish();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101A17),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        onHorizontalDragStart: _scrubStart,
        onHorizontalDragUpdate: _scrub,
        onHorizontalDragEnd: _scrubEnd,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(_controller.value);
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _GurugramCityPainter(progress: t)),
                _IntroCopy(progress: t, scrubbing: _scrubbing),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IntroCopy extends StatelessWidget {
  const _IntroCopy({required this.progress, required this.scrubbing});

  final double progress;
  final bool scrubbing;

  @override
  Widget build(BuildContext context) {
    final title = _interval(progress, .67, .86);
    final hint = _interval(progress, .03, .18);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.s16,
          Space.gutter,
          Space.s24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: hint,
              child: Text(
                'NH-48 / GURUGRAM',
                style: AppType.label(color: const Color(0xFFC9D8C9)),
              ),
            ),
            const Spacer(),
            Transform.translate(
              offset: Offset(0, (1 - title) * 38),
              child: Opacity(
                opacity: title,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BUDGET',
                      style: AppType.label(color: const Color(0xFFD7B568)),
                    ),
                    const SizedBox(height: Space.s4),
                    Text(
                      'Gurugram',
                      style: AppType.display(
                        color: const Color(0xFFF7F4ED),
                      ).copyWith(fontSize: 56),
                    ),
                    const SizedBox(height: Space.s8),
                    Text(
                      'Eat, work, pause, or show up — one app.',
                      style: AppType.body(color: const Color(0xFFC9D8C9)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.s24),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2,
                      backgroundColor: const Color(0xFF365048),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFD7B568),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Space.s12),
                Text(
                  scrubbing ? 'SCOUTING' : 'TAP TO ENTER',
                  style: AppType.labelS(color: const Color(0xFFC9D8C9)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GurugramCityPainter extends CustomPainter {
  const _GurugramCityPainter({required this.progress});

  final double progress;

  static const _buildings = <_Building>[
    _Building('GOOGLE', .14, .23, .21, .22, Color(0xFF4F86E8)),
    _Building('AMAZON', .62, .18, .25, .29, Color(0xFFE69A32)),
    _Building('MICROSOFT', .39, .32, .18, .18, Color(0xFF6CBF72)),
    _Building('THREADS', .73, .47, .18, .16, Color(0xFFA982F0)),
    _Building('PAYTM', .15, .52, .22, .17, Color(0xFF4FB8DC)),
    _Building('RAZORPAY', .43, .54, .24, .19, Color(0xFF4B82D2)),
    _Building('ZEPTO', .10, .72, .20, .15, Color(0xFFB284E4)),
    _Building('BLINKIT', .66, .72, .22, .15, Color(0xFFDCC94A)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sky = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF101A17), Color(0xFF19352E), Color(0xFF10231F)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRect(rect, sky);

    _drawDataSnow(canvas, size);
    _drawRoads(canvas, size);
    for (var index = 0; index < _buildings.length; index++) {
      final entry = _interval(progress, .15 + index * .045, .39 + index * .045);
      _drawBuilding(canvas, size, _buildings[index], entry);
    }
    _drawMovingCity(canvas, size);
    _drawForeground(canvas, size);
  }

  void _drawDataSnow(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 86; i++) {
      final seed = i * 19.7;
      final x = ((math.sin(seed) + 1) / 2) * size.width;
      final drift = (progress * (18 + i % 8) + i * 7) % (size.height + 40);
      final y = drift - 20;
      final alpha = 0.13 + ((i % 4) * .04);
      paint.color = Color.lerp(
        const Color(0xFFC8E4D4),
        Colors.transparent,
        1 - alpha,
      )!;
      canvas.drawCircle(Offset(x, y), i % 5 == 0 ? 1.4 : .7, paint);
    }
  }

  void _drawRoads(Canvas canvas, Size size) {
    final road = Paint()
      ..color = const Color(0xFF0A110F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = const Color(0xFFB5AD78).withValues(alpha: .42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..moveTo(-20, size.height * .91)
      ..cubicTo(
        size.width * .2,
        size.height * .68,
        size.width * .68,
        size.height * .69,
        size.width + 20,
        size.height * .33,
      );
    canvas.drawPath(path, road);
    canvas.drawPath(path, line);

    final cross = Paint()
      ..color = const Color(0xFF18362E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawLine(
      Offset(size.width * .05, size.height * .44),
      Offset(size.width * .95, size.height * .63),
      cross,
    );
  }

  void _drawBuilding(
    Canvas canvas,
    Size size,
    _Building building,
    double entry,
  ) {
    if (entry == 0) return;
    final x = building.x * size.width;
    final y = building.y * size.height + (1 - entry) * 100;
    final width = building.width * size.width;
    final height = building.height * size.height * entry;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, width, height),
      const Radius.circular(6),
    );
    final bodyPaint = Paint()
      ..color = const Color(0xFF182A25).withValues(alpha: .96);
    canvas.drawRRect(body, bodyPaint);
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFF527267).withValues(alpha: .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final windowPaint = Paint()..color = building.color.withValues(alpha: .48);
    for (var row = 0; row < math.max(1, height ~/ 18); row++) {
      for (var column = 0; column < math.max(1, width ~/ 19); column++) {
        if ((row + column) % 3 != 0) {
          canvas.drawRect(
            Rect.fromLTWH(x + 8 + column * 19, y + 10 + row * 18, 6, 5),
            windowPaint,
          );
        }
      }
    }

    final sign = Rect.fromLTWH(x + 7, y + 12, width - 14, 20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(sign, const Radius.circular(3)),
      Paint()..color = building.color,
    );
    _label(
      canvas,
      building.name,
      Offset(sign.left + 6, sign.top + 5),
      const Color(0xFF101A17),
      8.5,
    );
  }

  void _drawMovingCity(Canvas canvas, Size size) {
    final carPaint = Paint()..color = const Color(0xFFF4D27A);
    final carCount = 11;
    for (var i = 0; i < carCount; i++) {
      final local = (progress * 1.55 + i / carCount) % 1;
      final x = size.width * local;
      final y =
          size.height *
          (.77 - .38 * local + .055 * math.sin(local * math.pi * 3));
      canvas.drawCircle(Offset(x, y), 2.2, carPaint);
    }

    final delivery = _interval(progress, .48, .72);
    if (delivery > 0) {
      final bike = Offset(
        size.width * (.15 + .68 * delivery),
        size.height * (.67 - .15 * delivery),
      );
      canvas.drawCircle(bike, 5, Paint()..color = const Color(0xFFB284E4));
      canvas.drawCircle(
        bike + const Offset(7, 5),
        5,
        Paint()..color = const Color(0xFFDCC94A),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: bike + const Offset(4, -5),
          width: 13,
          height: 8,
        ),
        Paint()..color = const Color(0xFFE6E5DC),
      );
    }
  }

  void _drawForeground(Canvas canvas, Size size) {
    final horizon = Paint()
      ..color = const Color(0xFF0C1512).withValues(alpha: .65);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .90, size.width, size.height * .1),
      horizon,
    );
    _label(
      canvas,
      'CYBER CITY',
      Offset(size.width * .07, size.height * .87),
      const Color(0xFFAFC4BB),
      8,
    );
    _label(
      canvas,
      'SECTOR 44',
      Offset(size.width * .67, size.height * .67),
      const Color(0xFFAFC4BB),
      8,
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 110);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GurugramCityPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Building {
  const _Building(
    this.name,
    this.x,
    this.y,
    this.width,
    this.height,
    this.color,
  );

  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final Color color;
}

double _interval(double value, double begin, double end) =>
    ((value - begin) / (end - begin)).clamp(0.0, 1.0);

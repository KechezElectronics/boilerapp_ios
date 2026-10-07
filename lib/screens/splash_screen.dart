import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shown immediately after the native launch screen (see
/// flutter_native_splash config in pubspec.yaml) while stores load and
/// cloud connections spin up. Draws the same gauge mark used elsewhere in
/// the app as live vector shapes (not a static image) so it can animate:
/// the ring traces itself, the dial fills in, the needle sweeps into
/// place, then the app name fades in below. Total animation runs ~2s;
/// main.dart holds on this screen at least that long before swapping to
/// Home so the sequence isn't cut short.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Named phases as Intervals within the single 0.0-1.0 controller, each
  // with its own easing -- overlapping slightly so one phase is still
  // settling as the next begins, rather than a rigid step-by-step feel.
  late final Animation<double> _ringTrace;
  late final Animation<double> _discFade;
  late final Animation<double> _arcFill;
  late final Animation<double> _needleDraw;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    _ringTrace = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.35, curve: Curves.easeOut));
    _discFade = CurvedAnimation(parent: _controller, curve: const Interval(0.25, 0.42, curve: Curves.easeIn));
    _arcFill = CurvedAnimation(parent: _controller, curve: const Interval(0.32, 0.66, curve: Curves.easeOutCubic));
    _needleDraw = CurvedAnimation(parent: _controller, curve: const Interval(0.55, 0.80, curve: Curves.easeOutBack));
    _textFade = CurvedAnimation(parent: _controller, curve: const Interval(0.75, 1.0, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _GaugeMarkPainter(
                    ringTrace: _ringTrace.value,
                    discOpacity: _discFade.value,
                    arcFill: _arcFill.value,
                    needleDraw: _needleDraw.value,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: _textFade.value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - _textFade.value)),
                  child: child,
                ),
              ),
              child: const Text(
                'IoT Boiler Monitoring App',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF0F0F2),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugeMarkPainter extends CustomPainter {
  final double ringTrace;   // 0-1: outer ring outline being traced
  final double discOpacity; // 0-1: dark disc fill fading in
  final double arcFill;     // 0-1: teal gauge arc sweeping in
  final double needleDraw;  // 0-1: needle + hub growing in

  static const Color surface = Color(0xFF1C1C1F);
  static const Color track = Color(0xFF2A313A);
  static const Color accent = Color(0xFF4FD1A5);

  const _GaugeMarkPainter({
    required this.ringTrace,
    required this.discOpacity,
    required this.arcFill,
    required this.needleDraw,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 4;

    // 1. Ring trace: the outline draws itself clockwise from the top.
    if (ringTrace > 0) {
      final ringPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: outerR));
      final metrics = ringPath.computeMetrics().first;
      final tracedPath = metrics.extractPath(0, metrics.length * ringTrace);
      canvas.drawPath(
        tracedPath,
        Paint()
          ..color = Colors.white.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // 2. Disc fill fades in behind the gauge face.
    if (discOpacity > 0) {
      canvas.drawCircle(center, outerR, Paint()..color = surface.withOpacity(discOpacity));
    }

    if (discOpacity < 0.5) return; // nothing below is visible yet anyway

    // 3. Gauge arc -- same 240-degree sweep and proportions as the
    // dashboard's own arc gauges, so this reads as the same visual
    // language rather than a one-off splash graphic.
    const startAngleDeg = 150.0;
    const sweepDeg = 240.0;
    const gaugeValueFraction = 0.65; // how "full" the mark shows, purely decorative here
    final strokeW = outerR * 0.24;
    final arcR = outerR - strokeW / 2 - 6;

    final trackRect = Rect.fromCircle(center: center, radius: arcR);
    canvas.drawArc(
      trackRect,
      _deg2rad(startAngleDeg),
      _deg2rad(sweepDeg),
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );

    final sweepNow = sweepDeg * gaugeValueFraction * arcFill;
    if (sweepNow > 0) {
      canvas.drawArc(
        trackRect,
        _deg2rad(startAngleDeg),
        _deg2rad(sweepNow),
        false,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
    }

    // 4. Needle + hub grow in once the arc has mostly filled.
    if (needleDraw > 0) {
      final needleAngleDeg = startAngleDeg + sweepDeg * gaugeValueFraction;
      final needleLen = (outerR * 0.55) * needleDraw;
      final tip = Offset(
        center.dx + needleLen * math.cos(_deg2rad(needleAngleDeg)),
        center.dy + needleLen * math.sin(_deg2rad(needleAngleDeg)),
      );
      canvas.drawLine(
        center,
        tip,
        Paint()
          ..color = accent
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(center, 6 * needleDraw, Paint()..color = accent);
    }
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  @override
  bool shouldRepaint(covariant _GaugeMarkPainter oldDelegate) {
    return oldDelegate.ringTrace != ringTrace ||
        oldDelegate.discOpacity != discOpacity ||
        oldDelegate.arcFill != arcFill ||
        oldDelegate.needleDraw != needleDraw;
  }
}

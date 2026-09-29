import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../channels/battery_channel.dart';
import '../../domain/entities/studio_design_entity.dart';

/// Geometry for the `batteryRing` studio widget.
///
/// Kept as plain numbers in one place so the Flutter preview and the native
/// renderer can draw the same ring: a divergence here would mean the applied
/// wallpaper does not match what the user chose.
class BatteryRingMetrics {
  const BatteryRingMetrics._();

  /// Ring diameter in logical pixels at `scale: 1.0`.
  ///
  /// The dashboard's own composited reference renders this as a small thin
  /// badge, not a dominant circle - closer to a status-bar battery glyph than
  /// a progress ring. 28 (down from an earlier 64) matches that proportion.
  static const double baseDiameter = 28;

  /// Stroke thickness in logical pixels at `scale: 1.0`.
  static const double baseStroke = 2.5;

  /// Alpha applied to the authored colour for the unfilled track.
  static const double trackAlpha = 0.25;

  /// The arc starts at 12 o'clock and sweeps clockwise, so a full battery is a
  /// complete circle and an empty one draws nothing.
  static const double startAngle = -math.pi / 2;

  /// Gap between the ring's own right edge and the percentage label, in
  /// logical pixels at `scale: 1.0`.
  static const double labelGap = 6;

  /// The percentage label's font size relative to [baseDiameter] * `scale`.
  static const double labelSizeRatio = 0.62;
}

/// Draws a ring showing the device's current battery level.
///
/// Polls the level rather than subscribing: battery capacity changes on the
/// order of minutes, so a 30-second poll is far cheaper than a broadcast
/// receiver and is indistinguishable to the eye.
class BatteryRingWidget extends StatefulWidget {
  const BatteryRingWidget({
    super.key,
    required this.config,
    this.displayScale = 1.0,
  });

  final StudioBatteryRing config;

  /// Identity for a full-size render, less than 1.0 for a smaller preview box
  /// - the same convention as `ClockPainter.displayScale`.
  final double displayScale;

  @override
  State<BatteryRingWidget> createState() => _BatteryRingWidgetState();
}

class _BatteryRingWidgetState extends State<BatteryRingWidget> {
  static const Duration _pollInterval = Duration(seconds: 30);

  int? _level;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_read()));
  }

  Future<void> _read() async {
    final level = await BatteryChannel.level();
    if (mounted && level != _level) setState(() => _level = level);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _BatteryRingPainter(
        config: widget.config,
        level: _level,
        displayScale: widget.displayScale,
      ),
    );
  }
}

class _BatteryRingPainter extends CustomPainter {
  _BatteryRingPainter({
    required this.config,
    required this.level,
    required this.displayScale,
  });

  final StudioBatteryRing config;
  final int? level;
  final double displayScale;

  @override
  void paint(Canvas canvas, Size size) {
    // FLUTTER_RENDERING_GUIDE §7.2: base font size W * 0.045 * scale; the
    // ring is about 1.1x that with a border of 0.14x; ring and percentage
    // sit in one row centred on the widget's point.
    final text = size.width * 0.045 * config.scale;
    final diameter = text * 1.1;
    final stroke = diameter * 0.14;
    final radius = (diameter - stroke) / 2;
    if (radius <= 0) return;

    TextPainter? label;
    if (level != null && config.showPercentage) {
      label = TextPainter(
        text: TextSpan(
          text: '$level%',
          style: TextStyle(
            color: Color(config.color),
            fontSize: text,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final gap = diameter * BatteryRingMetrics.labelGap / BatteryRingMetrics.baseDiameter;
    final rowWidth = diameter + (label == null ? 0 : gap + label.width);

    final anchor = _anchor(config.customX, config.customY, config.anchor, size);
    final center = Offset(anchor.dx - rowWidth / 2 + diameter / 2, anchor.dy);

    final color = Color(config.color);

    canvas.save();
    if (config.rotation != 0) {
      canvas.translate(center.dx, center.dy);
      canvas.rotate(config.rotation * math.pi / 180);
      canvas.translate(-center.dx, -center.dy);
    }

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: BatteryRingMetrics.trackAlpha);
    canvas.drawCircle(center, radius, track);

    // An unknown level draws the track only: an empty ring would read as "0%",
    // which would be a lie rather than an absence.
    if (level != null) {
      final sweep = 2 * math.pi * (level! / 100).clamp(0.0, 1.0);
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        BatteryRingMetrics.startAngle,
        sweep,
        false,
        arc,
      );

      if (label != null) {
        label.paint(
          canvas,
          Offset(center.dx + diameter / 2 + gap, center.dy - label.height / 2),
        );
      }
    }

    canvas.restore();
  }

  /// Exact coordinates win when both are set; otherwise the anchor at
  /// 20% / 50% / 82% of the height, centred horizontally.
  static Offset _anchor(double? x, double? y, String anchor, Size size) {
    if (x != null && y != null) return Offset(x * size.width, y * size.height);
    final fy = switch (anchor) {
      'center' => 0.5,
      'bottom' => 0.82,
      _ => 0.2,
    };
    return Offset(size.width / 2, fy * size.height);
  }

  @override
  bool shouldRepaint(_BatteryRingPainter old) =>
      old.level != level ||
      old.config != config ||
      old.displayScale != displayScale;
}

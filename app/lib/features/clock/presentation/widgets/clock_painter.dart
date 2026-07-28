import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/clock_config_entity.dart';

/// Draws the clock (time + optional date) with all configured effects onto a
/// canvas. Must stay visually in sync with the native `ClockRenderer.kt`.
class ClockPainter extends CustomPainter {
  ClockPainter({required this.config, required this.now, this.locale});

  final ClockConfigEntity config;
  final DateTime now;
  final String? locale;

  @override
  void paint(Canvas canvas, Size size) {
    if (config.opacity <= 0) return;

    final timeString = _formatTime(now, config.is24Hour, config.showSeconds);
    final color = Color(config.color).withValues(alpha: config.opacity);

    final timePainter = _buildTimePainter(timeString, color);
    timePainter.layout(maxWidth: size.width);

    TextPainter? datePainter;
    if (config.showDate) {
      datePainter = _buildDatePainter(_formatDate(now), color);
      datePainter.layout(maxWidth: size.width);
    }

    const dateGap = 12.0;
    final blockHeight = timePainter.height +
        (datePainter != null ? dateGap + datePainter.height : 0);

    final topY = _positionTop(size.height, blockHeight);
    final timeX = (size.width - timePainter.width) / 2;

    // Stroke (drawn first, behind the fill).
    if (config.showStroke) {
      final strokePainter = _buildStrokePainter(timeString);
      strokePainter.layout(maxWidth: size.width);
      strokePainter.paint(
          canvas, Offset((size.width - strokePainter.width) / 2, topY));
    }

    timePainter.paint(canvas, Offset(timeX, topY));

    if (datePainter != null) {
      final dateX = (size.width - datePainter.width) / 2;
      datePainter.paint(
          canvas, Offset(dateX, topY + timePainter.height + dateGap));
    }
  }

  double _positionTop(double height, double blockHeight) {
    switch (config.position) {
      case ClockPosition.top:
        return height * 0.16;
      case ClockPosition.center:
        return (height - blockHeight) / 2;
      case ClockPosition.bottom:
        return height * 0.74 - blockHeight;
    }
  }

  TextPainter _buildTimePainter(String text, Color color) {
    return _painter(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: config.sizePx,
        fontFamily: _fontFamily(config.font),
        fontWeight: _weight(config.style),
        fontStyle: config.style == ClockStyle.elegant
            ? FontStyle.italic
            : FontStyle.normal,
        letterSpacing: _letterSpacing(config.style),
        height: 1.0,
        shadows: _shadows(color),
      ),
    );
  }

  TextPainter _buildDatePainter(String text, Color color) {
    return _painter(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: (config.sizePx * 0.22).clamp(14, 24),
        fontFamily: _fontFamily(config.font),
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        shadows: config.showShadow
            ? const [Shadow(blurRadius: 6, offset: Offset(0, 2), color: Colors.black45)]
            : null,
      ),
    );
  }

  TextPainter _buildStrokePainter(String text) {
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black.withValues(alpha: config.opacity);
    return _painter(
      text: text,
      style: TextStyle(
        fontSize: config.sizePx,
        fontFamily: _fontFamily(config.font),
        fontWeight: _weight(config.style),
        fontStyle: config.style == ClockStyle.elegant
            ? FontStyle.italic
            : FontStyle.normal,
        letterSpacing: _letterSpacing(config.style),
        height: 1.0,
        foreground: strokePaint,
      ),
    );
  }

  TextPainter _painter({required String text, required TextStyle style}) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );
  }

  List<Shadow>? _shadows(Color color) {
    final shadows = <Shadow>[];
    if (config.showShadow) {
      shadows.add(const Shadow(
          blurRadius: 8, offset: Offset(0, 4), color: Colors.black54));
    }
    if (config.showGlow) {
      shadows.add(Shadow(blurRadius: 24, color: color.withValues(alpha: 0.9)));
      shadows.add(Shadow(blurRadius: 40, color: color.withValues(alpha: 0.6)));
    }
    return shadows.isEmpty ? null : shadows;
  }

  String _fontFamily(ClockFont font) {
    switch (font) {
      case ClockFont.inter:
        return 'Inter';
      case ClockFont.serif:
        return 'PlayfairDisplay';
      case ClockFont.mono:
        return 'JetBrainsMono';
    }
  }

  FontWeight _weight(ClockStyle style) {
    switch (style) {
      case ClockStyle.modern:
        return FontWeight.w700;
      case ClockStyle.minimal:
        return FontWeight.w300;
      case ClockStyle.elegant:
        return FontWeight.w400;
      case ClockStyle.digital:
        return FontWeight.w700;
    }
  }

  double _letterSpacing(ClockStyle style) {
    switch (style) {
      case ClockStyle.minimal:
        return 3;
      case ClockStyle.digital:
        return 1;
      case ClockStyle.elegant:
        return 0;
      case ClockStyle.modern:
        return -1;
    }
  }

  String _formatTime(DateTime t, bool is24Hour, bool showSeconds) {
    final pattern = is24Hour
        ? (showSeconds ? 'HH:mm:ss' : 'HH:mm')
        : (showSeconds ? 'h:mm:ss' : 'h:mm');
    return DateFormat(pattern, locale).format(t);
  }

  String _formatDate(DateTime t) => DateFormat('EEEE, MMMM d', locale).format(t);

  @override
  bool shouldRepaint(covariant ClockPainter old) =>
      old.config != config || old.now != now || old.locale != locale;
}

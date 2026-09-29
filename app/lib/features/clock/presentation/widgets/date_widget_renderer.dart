import 'package:flutter/material.dart';

import '../../domain/clock_render_spec.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../domain/entities/studio_design_entity.dart';

/// Formatting rules for the `studio.dateWidget` element.
///
/// Kept in one place so the Flutter preview and the native renderer format the
/// same date the same way: a divergence here would mean the applied wallpaper
/// shows a different string from the one the user previewed.
class StudioDateFormats {
  const StudioDateFormats._();

  /// The base font size in logical pixels at `scale: 1.0`.
  static const double baseSizePx = 28;

  /// `format` id -> date pattern. Mirrors `StudioDateFormats.patternFor` in
  /// `StudioDateRenderer.kt`.
  ///
  /// An authored `pattern` overrides these; no production wallpaper sets one
  /// today, but the field exists so it is honoured.
  static String patternFor(String format) => switch (format) {
        'short' => 'MMM d',
        'long' => 'EEEE, MMMM d',
        // `medium` is the documented default.
        _ => 'MMM d, yyyy',
      };

  /// Formats [date] for the authored [config].
  ///
  /// The locale is pinned to the authored one (`en` in all production data)
  /// rather than the device's, for the same reason the clock pins Latin
  /// digits: the wallpaper is artwork, and its date must read as the content
  /// team composed it regardless of the user's locale.
  static String format(StudioDateWidget config, DateTime date) {
    final pattern = config.pattern ?? patternFor(config.format);
    final text = DateFormat(pattern, config.locale).format(date);
    return config.uppercase ? text.toUpperCase() : text;
  }
}

/// Draws the `studio.dateWidget` - a date element positioned independently of
/// the clock, with its own coordinates, font, scale and colour.
///
/// This is NOT the clock's own nested `date` (which sits directly above or
/// below the time and is drawn by `ClockPainter`). The two are separate
/// authored elements; production data enables at most one of them per
/// wallpaper.
class DateWidgetRenderer extends StatelessWidget {
  const DateWidgetRenderer({
    super.key,
    required this.config,
    required this.now,
    this.displayScale = 1.0,
  });

  final StudioDateWidget config;
  final DateTime now;

  /// Identity for a full-size render, less than 1.0 for a smaller preview box
  /// - the same convention as `ClockPainter.displayScale`.
  final double displayScale;

  @override
  Widget build(BuildContext context) {
    if (!config.enabled) return const SizedBox.shrink();
    return CustomPaint(
      size: Size.infinite,
      painter: _DateWidgetPainter(
        config: config,
        now: now,
        displayScale: displayScale,
      ),
    );
  }
}

class _DateWidgetPainter extends CustomPainter {
  _DateWidgetPainter({
    required this.config,
    required this.now,
    required this.displayScale,
  });

  final StudioDateWidget config;
  final DateTime now;
  final double displayScale;

  @override
  void paint(Canvas canvas, Size size) {
    final text = StudioDateFormats.format(config, now);
    if (text.isEmpty) return;

    // FLUTTER_RENDERING_GUIDE §7.1: font size W * 0.05 * scale, letter
    // spacing 0.06em, one line, centred on its point.
    final fontSize = size.width * 0.05 * config.scale;
    final family = ClockRenderSpec.familyFor(config.font);
    final variable = ClockRenderSpec.variableFamilies.contains(family);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Color(config.color),
          fontSize: fontSize,
          fontWeight: variable ? FontWeight.w400 : _weight(config.weight),
          fontVariations: variable ? [FontVariation('wght', config.weight.toDouble())] : null,
          fontFamily: family,
          letterSpacing: 0.06 * fontSize,
          height: 1.0,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final center = anchorFor(config, size);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  /// Exact coordinates win when both are set; otherwise `position` at
  /// 14% / 50% / 78% of the height, centred horizontally.
  static Offset anchorFor(StudioDateWidget config, Size size) {
    final x = config.customX, y = config.customY;
    if (x != null && y != null) return Offset(x * size.width, y * size.height);
    final fy = switch (config.position) {
      'top' => 0.14,
      'center' => 0.5,
      _ => 0.78,
    };
    return Offset(size.width / 2, fy * size.height);
  }

  static FontWeight _weight(int weight) => switch (weight ~/ 100) {
        1 => FontWeight.w100,
        2 => FontWeight.w200,
        3 => FontWeight.w300,
        4 => FontWeight.w400,
        5 => FontWeight.w500,
        6 => FontWeight.w600,
        7 => FontWeight.w700,
        8 => FontWeight.w800,
        _ => FontWeight.w900,
      };

  @override
  bool shouldRepaint(_DateWidgetPainter old) =>
      old.config != config ||
      old.displayScale != displayScale ||
      // Only the calendar day matters; repainting every second would be waste.
      old.now.day != now.day ||
      old.now.month != now.month ||
      old.now.year != now.year;
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/clock_render_spec.dart';
import '../../domain/entities/clock_config_entity.dart';

/// One run of text on a clock line (hours, colon, minutes, AM/PM).
class ClockSegment {
  ClockSegment({
    required this.role,
    required this.painter,
    required this.rect,
    required this.baselineY,
  });

  final ClockSegmentRole role;
  final TextPainter painter;

  /// Where the painter's own box is drawn, in viewport pixels (before the
  /// clock's rotation/scale transform).
  final Rect rect;
  final double baselineY;
}

enum ClockSegmentRole { hours, colon, minutes, amPm }

/// The resolved geometry of one clock, in viewport pixels, before rotation
/// and `horizontalScale`/`stretchY` (which are applied about [center]).
class ClockLayout {
  ClockLayout({
    required this.size,
    required this.center,
    required this.timeRect,
    required this.lineRects,
    required this.segments,
    required this.dateRect,
    required this.datePainter,
    required this.pieceRect,
  });

  /// The digits' font size (`W * 0.14 * scale * sizePx / 65`).
  final double size;
  final Offset center;
  final Rect timeRect;

  /// One em-tall box per time line.
  final List<Rect> lineRects;
  final List<ClockSegment> segments;
  final Rect? dateRect;
  final TextPainter? datePainter;

  /// Time block plus the carried date - the piece centred on [center].
  final Rect pieceRect;

  ClockSegment? segment(ClockSegmentRole role) {
    for (final s in segments) {
      if (s.role == role) return s;
    }
    return null;
  }
}

/// Draws the authored clock exactly as the dashboard does
/// (FLUTTER_RENDERING_GUIDE.md §3). All numbers come from [ClockRenderSpec];
/// the native `ClockRenderer.kt` mirrors the same spec for the applied
/// wallpaper.
///
/// The canvas is the phone-screen viewport: Details passes the full screen,
/// the Apply sheet a small box with the same proportions. Because every size
/// derives from the canvas width, both show the same composition.
class ClockPainter extends CustomPainter {
  ClockPainter({
    required this.config,
    required this.now,
    this.locale,
    this.deviceIs24Hour = false,
    // Kept for callers that still pass it. Sizes derive from the canvas
    // width, so a smaller preview box is already scaled.
    this.displayScale = 1.0,
  });

  final ClockConfigEntity config;
  final DateTime now;

  /// Overrides the digits/AM-PM locale. The time is artwork, so it defaults
  /// to `en_US` (Latin digits on every phone).
  final String? locale;

  /// The phone's 12/24 hour setting, for `hourFormat: auto`.
  final bool deviceIs24Hour;
  final double displayScale;

  static const String _artworkLocale = 'en_US';

  @override
  void paint(Canvas canvas, Size size) {
    if (!config.enabled || config.opacity <= 0) return;
    final layout = computeLayout(size);
    if (layout == null) return;

    final c = layout.center;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (config.rotation != 0) canvas.rotate(config.rotation * math.pi / 180);
    if (config.horizontalScale != 1 || config.stretchY != 1) {
      canvas.scale(config.horizontalScale, config.stretchY);
    }
    canvas.translate(-c.dx, -c.dy);

    final wholeLayer = config.opacity < 1;
    if (wholeLayer) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, config.opacity),
      );
    }

    _paintTime(canvas, layout);

    final date = layout.datePainter;
    if (date != null) date.paint(canvas, layout.dateRect!.topLeft);

    if (wholeLayer) canvas.restore();
    canvas.restore();
  }

  /// The resolved geometry for a [viewport]. Null when nothing is drawn.
  @visibleForTesting
  ClockLayout? computeLayout(Size viewport) {
    if (!config.enabled) return null;
    final s = ClockRenderSpec.clockSize(viewport.width, config);
    if (!(s > 0)) return null;

    final is24 = ClockRenderSpec.uses24Hour(config, deviceIs24Hour: deviceIs24Hour);
    final time = _formatTime(now, is24, config.showSeconds);
    final colon = time.indexOf(':');
    final hourText = colon < 0 ? time : time.substring(0, colon);
    final minuteText = colon < 0 ? '' : time.substring(colon + 1);
    final amPm = ClockRenderSpec.showsAmPm(config, is24Hour: is24)
        ? DateFormat('a', locale ?? _artworkLocale).format(now)
        : null;

    final hoursTf = ClockRenderSpec.typeface(config, half: ClockHalf.hours);
    final minutesTf = ClockRenderSpec.typeface(config, half: ClockHalf.minutes);
    final clockTf = ClockRenderSpec.typeface(config);

    final inline = config.timeLayout == ClockTimeLayout.inline;
    final lines = <List<_Run>>[];
    final hours = _Run(ClockSegmentRole.hours, hourText, hoursTf, s);
    final minutes = _Run(ClockSegmentRole.minutes, minuteText, minutesTf, s);
    final amPmRun = amPm == null
        ? null
        : _Run(
            ClockSegmentRole.amPm,
            amPm,
            ClockTypeface(minutesTf.family, minutesTf.weight, ClockRenderSpec.amPmLetterSpacingEm, italic: minutesTf.italic),
            ClockRenderSpec.amPmFontSize(s),
            leadingGap: ClockRenderSpec.amPmGap(s),
          );
    if (inline) {
      lines.add([
        hours,
        if (ClockRenderSpec.drawsColon(config)) _Run(ClockSegmentRole.colon, ':', clockTf, s),
        minutes,
        ?amPmRun,
      ]);
    } else {
      lines.add([hours]);
      lines.add([minutes, ?amPmRun]);
    }

    final gap = ClockRenderSpec.rowGap(config.timeLayout, s, config.lineSpacing);
    final shift = ClockRenderSpec.minuteShift(config, s);

    // Measure every run, and each line's width.
    final measured = [
      for (final line in lines) [for (final r in line) (run: r, painter: _measure(r))],
    ];
    double lineWidth(List<({_Run run, TextPainter painter})> line) =>
        line.fold(0.0, (w, e) => w + e.run.leadingGap + e.painter.width);
    final timeW = measured.map(lineWidth).fold(0.0, math.max);
    final timeH = lines.length * s + (lines.length - 1) * gap;

    TextPainter? datePainter;
    double dateH = 0;
    if (config.showDate) {
      final d = ClockRenderSpec.dateFontSize(s, config.dateScale);
      datePainter = TextPainter(
        text: TextSpan(
          text: _formatDate(now),
          // The dashboard draws the carried date in the clock's own face.
          style: _style(
            ClockTypeface(
              clockTf.family,
              clockTf.weight,
              ClockRenderSpec.dateLetterSpacingEm,
              italic: clockTf.italic,
            ),
            d,
          ).copyWith(
            color: Color(config.dateColor ?? config.color),
            shadows: config.showShadow ? [_shadow(s)] : null,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout();
      dateH = d;
    }

    final pieceW = math.max(timeW, datePainter?.width ?? 0);
    final pieceH = timeH + dateH;
    final p = ClockRenderSpec.center(config, viewport.width, viewport.height);
    final center = Offset(p.x, p.y);
    final pieceTop = center.dy - pieceH / 2;
    final dateAbove = datePainter != null && config.datePosition == ClockDatePosition.above;
    final timeTop = pieceTop + (dateAbove ? dateH : 0);
    final timeRect = Rect.fromLTWH(center.dx - timeW / 2, timeTop, timeW, timeH);

    final segments = <ClockSegment>[];
    final lineRects = <Rect>[];
    for (var i = 0; i < measured.length; i++) {
      final line = measured[i];
      final top = timeTop + i * (s + gap);
      final isMinutesLine = !inline && i == 1;
      final w = lineWidth(line);
      var x = center.dx - w / 2 + (isMinutesLine ? shift : 0);
      lineRects.add(Rect.fromLTWH(x, top, w, s));
      // The line's baseline is its em box's own baseline (the digit run);
      // smaller runs (AM/PM) sit on that same baseline.
      final main = line.first.painter;
      final baseline = top + main.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      for (final e in line) {
        x += e.run.leadingGap;
        final segBaseline = e.painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
        segments.add(ClockSegment(
          role: e.run.role,
          painter: e.painter,
          rect: Rect.fromLTWH(x, baseline - segBaseline, e.painter.width, e.painter.height),
          baselineY: baseline,
        ));
        x += e.painter.width;
      }
    }

    final dateRect = datePainter == null
        ? null
        : Rect.fromLTWH(
            center.dx - datePainter.width / 2,
            dateAbove ? pieceTop : timeTop + timeH,
            datePainter.width,
            dateH,
          );

    return ClockLayout(
      size: s,
      center: center,
      timeRect: timeRect,
      lineRects: lineRects,
      segments: segments,
      dateRect: dateRect,
      datePainter: datePainter,
      pieceRect: Rect.fromCenter(center: center, width: pieceW, height: pieceH),
    );
  }

  void _paintTime(Canvas canvas, ClockLayout layout) {
    final s = layout.size;
    final sigma = ClockRenderSpec.blurSigma(config, s);
    final fading = config.fadeAmount > 0;
    final layered = sigma > 0 || fading;
    if (layered) {
      final paint = Paint();
      if (sigma > 0) paint.imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
      canvas.saveLayer(layout.timeRect.inflate(s), paint);
    }

    final gradient = config.colorMode == ClockColorMode.gradient ? _gradientShader(layout.timeRect) : null;
    final strokeW = config.showStroke ? ClockRenderSpec.strokeWidth(config, s) : 0.0;

    for (final seg in layout.segments) {
      final isDigits = seg.role != ClockSegmentRole.amPm;
      final text = seg.painter.text!.toPlainText();
      final base = (seg.painter.text as TextSpan).style!;
      final offset = seg.rect.topLeft;

      if (isDigits && strokeW > 0 && config.strokeOrder == ClockStrokeOrder.behind) {
        _strokePainter(text, base, strokeW * 2).paint(canvas, offset);
      }
      final fillColor = _fillColor(seg.role);
      final fillPaint = Paint()..color = fillColor.withValues(alpha: fillColor.a * config.fillOpacity);
      if (gradient != null) fillPaint.shader = gradient;
      final fill = TextPainter(
        text: TextSpan(
          text: text,
          style: base.copyWith(foreground: fillPaint, shadows: _timeShadows(s)),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      fill.paint(canvas, offset);
      if (isDigits && strokeW > 0 && config.strokeOrder == ClockStrokeOrder.front) {
        _strokePainter(text, base, strokeW).paint(canvas, offset);
      }
    }

    if (fading) {
      final r = layout.timeRect;
      final stops = ClockRenderSpec.fadeStops(config.fadeDirection, config.fadeAmount);
      canvas.drawRect(
        r.inflate(s),
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            r.topCenter,
            r.bottomCenter,
            [for (final st in stops) Color.fromRGBO(0, 0, 0, st.alpha)],
            [for (final st in stops) st.offset],
          ),
      );
    }
    if (layered) canvas.restore();
  }

  Color _fillColor(ClockSegmentRole role) {
    final base = Color(config.color);
    if (config.colorMode != ClockColorMode.split) return base;
    final hours = Color(config.hoursColor ?? config.color);
    final minutes = Color(config.minutesColor ?? config.color);
    return switch (role) {
      ClockSegmentRole.hours => hours,
      ClockSegmentRole.minutes || ClockSegmentRole.amPm => minutes,
      ClockSegmentRole.colon => switch (config.colonColor) {
        ClockColonColor.hours => hours,
        ClockColonColor.minutes => minutes,
        ClockColonColor.custom => Color(config.colonColorCustom ?? config.color),
      },
    };
  }

  Shader _gradientShader(Rect r) {
    final line = ClockRenderSpec.gradientLine(config.gradientAngleDeg, r.width, r.height);
    return ui.Gradient.linear(
      Offset(r.left + line.x0, r.top + line.y0),
      Offset(r.left + line.x1, r.top + line.y1),
      [Color(config.gradientFrom ?? config.color), Color(config.gradientTo ?? config.color)],
    );
  }

  List<Shadow>? _timeShadows(double s) {
    final list = <Shadow>[
      if (config.showShadow) _shadow(s),
      if (config.showGlow) ...[
        Shadow(color: Color(config.color), blurRadius: ClockRenderSpec.glowInnerBlur(s)),
        Shadow(color: Color(config.color), blurRadius: ClockRenderSpec.glowOuterBlur(s)),
      ],
    ];
    return list.isEmpty ? null : list;
  }

  Shadow _shadow(double s) => Shadow(
    color: Color.fromRGBO(0, 0, 0, config.shadowStrength),
    offset: Offset(0, ClockRenderSpec.shadowOffsetY(s)),
    blurRadius: ClockRenderSpec.shadowBlur(s),
  );

  TextPainter _strokePainter(String text, TextStyle base, double width) => TextPainter(
    text: TextSpan(
      text: text,
      style: base.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..color = Color(config.strokeColor),
      ),
    ),
    textDirection: ui.TextDirection.ltr,
  )..layout();

  TextPainter _measure(_Run r) => TextPainter(
    text: TextSpan(text: r.text, style: _style(r.face, r.fontSize)),
    textDirection: ui.TextDirection.ltr,
    maxLines: 1,
  )..layout();

  /// One em-tall line box with CSS `line-height: 1` leading.
  static TextStyle _style(ClockTypeface t, double fontSize) {
    final variable = ClockRenderSpec.variableFamilies.contains(t.family);
    return TextStyle(
      fontFamily: t.family,
      fontSize: fontSize,
      // A variable face takes its weight from the `wght` axis; asking for a
      // bold FontWeight on top would also synthesize bold.
      fontWeight: variable ? FontWeight.w400 : _fontWeight(t.weight),
      fontVariations: variable ? [FontVariation('wght', t.weight.toDouble())] : null,
      fontStyle: t.italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: t.letterSpacingEm * fontSize,
      height: 1.0,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  static FontWeight _fontWeight(int w) =>
      FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

  @visibleForTesting
  String formatTimeForTest(DateTime t, bool is24Hour, bool showSeconds) =>
      _formatTime(t, is24Hour, showSeconds);

  /// Hours and minutes are two digits; seconds stay with the minutes.
  String _formatTime(DateTime t, bool is24Hour, bool showSeconds) {
    final pattern = is24Hour
        ? (showSeconds ? 'HH:mm:ss' : 'HH:mm')
        : (showSeconds ? 'hh:mm:ss' : 'hh:mm');
    return DateFormat(pattern, locale ?? _artworkLocale).format(t);
  }

  /// Weekday, month and day ("Sunday, September 27").
  ///
  /// Kept in the artwork locale like the time. The guide says "in the phone's
  /// language", but that would put Arabic-Indic digits into the applied
  /// wallpaper on an Arabic phone - the regression the pinned artwork locale
  /// exists to prevent. `clock_native_locale_pinned_test` guards the native
  /// side of the same rule.
  String _formatDate(DateTime t) =>
      DateFormat.MMMMEEEEd(locale ?? _artworkLocale).format(t);

  @override
  bool shouldRepaint(covariant ClockPainter old) =>
      old.config != config ||
      old.now != now ||
      old.locale != locale ||
      old.deviceIs24Hour != deviceIs24Hour;
}

class _Run {
  _Run(this.role, this.text, this.face, this.fontSize, {this.leadingGap = 0});

  final ClockSegmentRole role;
  final String text;
  final ClockTypeface face;
  final double fontSize;
  final double leadingGap;
}

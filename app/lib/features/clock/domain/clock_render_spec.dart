import 'dart:math' as math;

import 'entities/clock_config_entity.dart';

/// The dashboard's clock drawing rules (FLUTTER_RENDERING_GUIDE.md §1, §3),
/// as pure functions of the config and the viewport.
///
/// Every renderer - `ClockPainter` (Details, Apply preview) and the native
/// `ClockSpec.kt` / `ClockRenderer.kt` (the applied wallpaper) - takes its
/// numbers from here or from that Kotlin mirror. `clock_render_spec_test.dart`
/// pins both to the same fixtures, so the two cannot drift apart silently.
class ClockRenderSpec {
  const ClockRenderSpec._();

  /// The digits' font size: `W * 0.14 * scale * (sizePx / 65)`, where `W` is
  /// the width of the phone-screen viewport being drawn into. Every other
  /// clock measurement is a multiple of this.
  static double clockSize(double viewportWidth, ClockConfigEntity c) =>
      viewportWidth * 0.14 * c.scale * (c.sizePx / 65);

  /// Gap between the bottom of the hours line box and the top of the minutes
  /// line box. Each line box is exactly one em tall (CSS `line-height: 1`).
  static double rowGap(ClockTimeLayout layout, double size, double lineSpacing) =>
      switch (layout) {
        ClockTimeLayout.inline => 0,
        ClockTimeLayout.stacked => 0.08 * size * lineSpacing,
        ClockTimeLayout.stackedCompact => 0.02 * size * lineSpacing,
        ClockTimeLayout.offsetStack => 0.08 * size * lineSpacing,
        ClockTimeLayout.verticalPoster => 0,
      };

  /// Horizontal shift of the minutes line in [ClockTimeLayout.offsetStack].
  static double minuteShift(ClockConfigEntity c, double size) =>
      c.timeLayout == ClockTimeLayout.offsetStack ? c.minuteOffsetX * size : 0;

  static double amPmFontSize(double size) => 0.3 * size;
  static double amPmGap(double size) => 0.08 * size;
  static const double amPmLetterSpacingEm = 0.04;

  static double dateFontSize(double size, double dateScale) =>
      0.2 * size * dateScale;
  static const double dateLetterSpacingEm = 0.06;

  static double strokeWidth(ClockConfigEntity c, double size) =>
      c.strokeWidth * (size / 65);

  static double shadowOffsetY(double size) => 0.04 * size;
  static double shadowBlur(double size) => 0.05 * size;
  static double glowInnerBlur(double size) => 0.18 * size;
  static double glowOuterBlur(double size) => 0.30 * size;
  static double blurSigma(ClockConfigEntity c, double size) =>
      c.blur * (size / 65);

  /// 12 or 24 hour. A studio clock's `hourFormat` wins; a depth clock (no
  /// `hourFormat`) uses `is24Hour`.
  static bool uses24Hour(ClockConfigEntity c, {required bool deviceIs24Hour}) =>
      switch (c.hourFormat) {
        ClockHourFormat.h24 => true,
        ClockHourFormat.h12 => false,
        ClockHourFormat.auto => deviceIs24Hour,
        null => c.is24Hour,
      };

  static bool showsAmPm(ClockConfigEntity c, {required bool is24Hour}) =>
      c.showAmPm && !is24Hour;

  /// Inline: the colon is always drawn, except in split colour mode where
  /// `showColon` decides. Stacked layouts never draw one.
  static bool drawsColon(ClockConfigEntity c) {
    if (c.timeLayout != ClockTimeLayout.inline) return false;
    return c.colorMode == ClockColorMode.split ? c.showColon : true;
  }

  /// The centre of the whole clock piece, in viewport pixels. Exact
  /// coordinates win when both are set; otherwise the anchor's height.
  static ({double x, double y}) center(
    ClockConfigEntity c,
    double viewportWidth,
    double viewportHeight,
  ) {
    if (c.customX != null && c.customY != null) {
      return (x: c.customX! * viewportWidth, y: c.customY! * viewportHeight);
    }
    final y = switch (c.position) {
      ClockPosition.top => 0.14,
      ClockPosition.center => 0.5,
      ClockPosition.bottom => 0.78,
    };
    return (x: viewportWidth / 2, y: y * viewportHeight);
  }

  /// Family, weight, tracking and italic for one half of the time (§3.2).
  static ClockTypeface typeface(ClockConfigEntity c, {ClockHalf? half}) {
    final style = (c.remoteStyle ?? c.style.name).trim().toLowerCase();
    final halfFont = switch (half) {
      ClockHalf.hours => c.hoursFont,
      ClockHalf.minutes => c.minutesFont,
      null => null,
    };
    final own = halfFont != null
        ? familyFor(halfFont)
        : (c.remoteFont != null ? familyFor(c.remoteFont!) : bundledFamily(c.font));
    final w = c.weight;
    final t = switch (style) {
      'modern' => ClockTypeface(own, w, -0.03),
      'minimal' => ClockTypeface(own, 300, 0.12),
      'elegant' => ClockTypeface(_serif, w, 0, italic: true),
      'digital' => ClockTypeface(_mono, 700, 0.04),
      'condensed' => ClockTypeface(_oswald, 600, -0.02),
      'poster' => ClockTypeface(_archivo, 900, -0.03),
      'outline' => ClockTypeface(own, 900, 0),
      'split' => ClockTypeface(own, 800, -0.02),
      'futuristic' => ClockTypeface(_anton, w, 0.05),
      'editorial' => ClockTypeface(_archivo, 900, -0.02),
      'monument' => ClockTypeface(_oswald, 700, -0.03),
      'stencil' => ClockTypeface(_anton, w, 0.08),
      'soft' => ClockTypeface(own, 500, 0),
      'thin' => ClockTypeface(own, 200, 0),
      'bold' => ClockTypeface(own, 800, 0),
      'classic' => ClockTypeface(_serif, w, 0),
      _ => ClockTypeface(own, w, 0), // rounded, outlined, solid, unknown
    };
    // A per-half font replaces the family for that half only - including
    // over a style's own family.
    return halfFont == null ? t : ClockTypeface(own, t.weight, t.letterSpacingEm, italic: t.italic);
  }

  static const _inter = 'Inter';
  static const _serif = 'PlayfairDisplay';
  static const _mono = 'JetBrainsMono';
  static const _oswald = 'Oswald';
  static const _archivo = 'ArchivoBlack';
  static const _anton = 'Anton';

  static String bundledFamily(ClockFont f) => switch (f) {
    ClockFont.inter => _inter,
    ClockFont.serif => _serif,
    ClockFont.mono => _mono,
    ClockFont.oswald => _oswald,
    ClockFont.archivoBlack => _archivo,
    ClockFont.anton => _anton,
  };

  /// Resolves a dashboard font name to a bundled family. The six faces the
  /// dashboard offers (`GET /config` → `studio.fonts`) are all bundled; any
  /// other name falls back by keyword, then to Inter.
  static String familyFor(String name) {
    final n = name.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    if (n.contains('archivo')) return _archivo;
    if (n.contains('anton')) return _anton;
    if (n.contains('oswald')) return _oswald;
    if (const ['playfair', 'serif', 'georgia', 'times', 'merriweather'].any(n.contains)) {
      return _serif;
    }
    if (const ['mono', 'jetbrains', 'courier', 'code'].any(n.contains)) return _mono;
    return _inter;
  }

  /// Families shipped as variable fonts, whose weight is the `wght` axis.
  static const variableFamilies = {_inter, _serif, _mono, _oswald};

  /// CSS `linear-gradient` angle convention: 0 runs bottom→top, 90 left→right,
  /// 180 top→bottom. Returns the start and end points across [w]×[h]
  /// (origin top-left) such that the gradient line spans the box's corners
  /// exactly as CSS computes it.
  static ({double x0, double y0, double x1, double y1}) gradientLine(
    double angleDeg,
    double w,
    double h,
  ) {
    final rad = angleDeg * math.pi / 180;
    final dx = math.sin(rad);
    final dy = -math.cos(rad);
    final half = (w * dx.abs() + h * dy.abs()) / 2;
    final cx = w / 2, cy = h / 2;
    return (
      x0: cx - dx * half,
      y0: cy - dy * half,
      x1: cx + dx * half,
      y1: cy + dy * half,
    );
  }

  /// Opacity stops for the fade mask, as `(offset, alpha)` pairs from top to
  /// bottom of the time block. Solid until `(1 - fadeAmount)` of the way from
  /// the far edge, then a linear ramp to transparent at the named edge.
  static List<({double offset, double alpha})> fadeStops(
    ClockFadeDirection dir,
    double amount,
  ) {
    final a = amount.clamp(0.0, 1.0);
    switch (dir) {
      case ClockFadeDirection.bottom:
        return [(offset: 0, alpha: 1), (offset: 1 - a, alpha: 1), (offset: 1, alpha: 0)];
      case ClockFadeDirection.top:
        return [(offset: 0, alpha: 0), (offset: a, alpha: 1), (offset: 1, alpha: 1)];
      case ClockFadeDirection.both:
        // A full ramp at each end; where they overlap the lower alpha wins,
        // which peaks at the middle at 0.5 / amount.
        if (a <= 0.5) {
          return [
            (offset: 0, alpha: 0),
            (offset: a, alpha: 1),
            (offset: 1 - a, alpha: 1),
            (offset: 1, alpha: 0),
          ];
        }
        return [(offset: 0, alpha: 0), (offset: 0.5, alpha: 0.5 / a), (offset: 1, alpha: 0)];
    }
  }
}

enum ClockHalf { hours, minutes }

class ClockTypeface {
  const ClockTypeface(this.family, this.weight, this.letterSpacingEm, {this.italic = false});

  final String family;
  final int weight;
  final double letterSpacingEm;
  final bool italic;
}

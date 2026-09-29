import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// Root-cause regression test for the applied-wallpaper "black strip at the
/// top of the home screen" bug.
///
/// `LiveWallpaperService.drawFrame()` (the STANDARD/DEPTH engine - VIDEO was
/// never affected, see the contrast test below) drew its background layer
/// with `DepthCompositor.drawFitBitmap`: a FIT/letterbox scale
/// (`scale = min(targetW/bmpW, targetH/bmpH)`) that deliberately left any
/// margin where the source's aspect ratio didn't match the viewport's
/// unpainted - and `drawFrame()` clears the canvas to solid black first.
/// Whenever a source was proportionally TALLER/NARROWER than the visible
/// viewport (e.g. a 896x1593 source against a 1080x2400 viewport), FIT
/// scaled to match width, leaving equal top+bottom margins painted black -
/// exactly the reported strip.
///
/// `VideoWallpaperService`'s poster and `GLVideoClockCompositor`'s live
/// video frames already used COVER, which is why only some wallpapers
/// (specifically STANDARD/DEPTH stills with a mismatched aspect ratio, never
/// VIDEO) showed the bug.
///
/// The fix switches the background to `drawCoverBitmap` (COVER: `scale =
/// max(...)`, guaranteeing the destination rect always at least covers the
/// target) and changes `drawForeground`'s own scale from `minOf` to the same
/// `maxOf` formula, so a DEPTH wallpaper's cut-out subject stays
/// pixel-registered against its (now COVER-scaled) background rather than
/// drifting out of alignment.
///
/// There is no Kotlin test harness in this project (no JUnit dependency, no
/// `android/app/src/test/`) - these are source-guard tests (the established
/// pattern from `clock_hour_zero_padding_test.dart` /
/// `wallpaper_only_no_default_clock_test.dart`) plus a pure-Dart
/// re-implementation of the identical COVER scale/destination-rect formula,
/// numerically verified against the required test matrix so the "always
/// fully covered, aspect ratio preserved, no stretch" contract is proven
/// with real numbers, not just a source-text match.
void main() {
  group('native source: background switched from FIT to COVER', () {
    late String liveWallpaperServiceSource;
    late String depthCompositorSource;

    setUpAll(() {
      liveWallpaperServiceSource = File(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/LiveWallpaperService.kt',
      ).readAsStringSync();
      depthCompositorSource = File(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/DepthCompositor.kt',
      ).readAsStringSync();
    });

    test(
        'LiveWallpaperService.drawFrame draws the background with '
        'drawCoverBitmap, not drawFitBitmap', () {
      expect(
        liveWallpaperServiceSource.contains('DepthCompositor.drawCoverBitmap('),
        isTrue,
        reason: 'the background layer must cover the visible viewport - '
            'FIT is what left the black strip unpainted',
      );
      expect(
        liveWallpaperServiceSource.contains('DepthCompositor.drawFitBitmap('),
        isFalse,
        reason: 'no call site in the live-wallpaper engine should still use '
            'the letterboxing draw mode for its own background',
      );
    });

    test(
        'DepthCompositor.drawForeground scales with maxOf (COVER), matching '
        'the background, so the cut-out subject stays pixel-registered '
        'rather than drifting once the background switched to COVER', () {
      final fgFn = _extractFunction(depthCompositorSource, 'drawForeground');
      expect(
        fgFn.contains('maxOf('),
        isTrue,
        reason: 'drawForeground must use the same COVER scale formula as '
            'drawCoverBitmap now that the background uses it',
      );
      expect(
        fgFn.contains('minOf('),
        isFalse,
        reason: 'the old FIT scale must be fully gone from drawForeground, '
            'not left alongside a new one',
      );
    });

    test(
        'drawCoverBitmap supports the same offsetX/offsetY centering '
        'drawFitBitmap did, so an oversized (parallax) ColorOS surface '
        'still centers the covered background within the visible viewport',
        () {
      final coverFn =
          _extractFunction(depthCompositorSource, 'drawCoverBitmap');
      expect(coverFn.contains('offsetX'), isTrue);
      expect(coverFn.contains('offsetY'), isTrue);
    });
  });

  group('native source: VIDEO path untouched (contrast case)', () {
    test(
        'VideoWallpaperService already used drawCoverBitmap for its poster - '
        'unaffected by this fix, confirming VIDEO was never the buggy path',
        () {
      final source = File(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/VideoWallpaperService.kt',
      ).readAsStringSync();
      expect(source.contains('DepthCompositor.drawCoverBitmap('), isTrue);
    });

    test(
        'GLVideoClockCompositor documents itself as already matching '
        'drawCoverBitmap\'s center-crop behaviour for live video frames', () {
      final source = File(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/GLVideoClockCompositor.kt',
      ).readAsStringSync();
      expect(source.contains('drawCoverBitmap'), isTrue);
    });
  });

  group('COVER destination-rect contract - numeric proof across the '
      'required test matrix', () {
    // Mirrors DepthCompositor.drawCoverBitmap exactly:
    //   scale = max(targetW/bmpW, targetH/bmpH)
    //   scaledW/H = bmp * scale; left/top = (target - scaled) / 2
    _DestRect cover(int bmpW, int bmpH, int targetW, int targetH) {
      final scale = math.max(targetW / bmpW, targetH / bmpH);
      final scaledW = (bmpW * scale).toInt();
      final scaledH = (bmpH * scale).toInt();
      final left = (targetW - scaledW) ~/ 2;
      final top = (targetH - scaledH) ~/ 2;
      return _DestRect(left, top, left + scaledW, top + scaledH, scale);
    }

    const sources = [
      (941, 1672),
      (896, 1593),
      (1080, 1920),
      (1080, 2400),
      (1440, 3200),
    ];
    const viewports = [
      (1080, 1920),
      (1080, 2340),
      (1080, 2400),
      (1440, 3200),
    ];

    for (final source in sources) {
      for (final viewport in viewports) {
        final (srcW, srcH) = source;
        final (vpW, vpH) = viewport;
        test(
            'source ${srcW}x$srcH into viewport ${vpW}x$vpH: fully covered, '
            'aspect ratio preserved, minimal centered crop', () {
          final dst = cover(srcW, srcH, vpW, vpH);

          // No uncovered top/left/right/bottom, within rounding tolerance -
          // this is the exact contract the black strip violated.
          expect(dst.left, lessThanOrEqualTo(0),
              reason: 'no uncovered left edge');
          expect(dst.top, lessThanOrEqualTo(0),
              reason: 'no uncovered top edge - this is the reported bug');
          expect(dst.right, greaterThanOrEqualTo(vpW),
              reason: 'no uncovered right edge');
          expect(dst.bottom, greaterThanOrEqualTo(vpH),
              reason: 'no uncovered bottom edge');

          // Aspect ratio preserved: the SAME scale factor was applied to
          // both dimensions (uniform scale, never stretched).
          final scaledW = dst.right - dst.left;
          final scaledH = dst.bottom - dst.top;
          final renderedRatio = scaledW / scaledH;
          final sourceRatio = srcW / srcH;
          expect(
            renderedRatio,
            closeTo(sourceRatio, 0.01),
            reason: 'COVER must preserve the source aspect ratio - no '
                'stretching/distortion',
          );

          // Minimal crop: the rendered size must not exceed the viewport by
          // more than what a single-axis cover naturally produces (i.e. one
          // axis exactly matches the viewport, the other overshoots only as
          // much as the aspect mismatch requires).
          final widthMatches = (scaledW - vpW).abs() <= 1;
          final heightMatches = (scaledH - vpH).abs() <= 1;
          expect(
            widthMatches || heightMatches,
            isTrue,
            reason: 'COVER scale must exactly fill one axis (the minimal '
                'crop needed), not both overshoot',
          );
        });
      }
    }

    test(
        'regression case from the bug report: a portrait source narrower '
        'than a taller device viewport no longer leaves a top gap', () {
      // 896x1593 (~0.5625 ratio) into a 1080x2400 (~0.45 ratio) viewport -
      // representative of the reported screenshots: source is relatively
      // WIDER than the viewport, so FIT used to scale to match width and
      // leave top+bottom margins unpainted.
      final dst = cover(896, 1593, 1080, 2400);
      expect(dst.top, lessThanOrEqualTo(0));
      expect(dst.bottom, greaterThanOrEqualTo(2400));
    });

    test(
        'an oversized ColorOS parallax surface still fully covers the '
        'centered visible viewport once offsetX/offsetY are added back',
        () {
      // Surface is 2340 wide (parallax) but the visible viewport is the
      // centered 1080x2400 region, exactly as LiveWallpaperService's own
      // visibleViewport() computes it.
      const viewportLeft = (2340 - 1080) ~/ 2;
      const viewportTop = 0;
      final dst = cover(896, 1593, 1080, 2400);
      final absoluteLeft = viewportLeft + dst.left;
      final absoluteTop = viewportTop + dst.top;
      final absoluteRight = viewportLeft + dst.right;
      final absoluteBottom = viewportTop + dst.bottom;
      expect(absoluteLeft, lessThanOrEqualTo(viewportLeft));
      expect(absoluteTop, lessThanOrEqualTo(viewportTop));
      expect(absoluteRight, greaterThanOrEqualTo(viewportLeft + 1080));
      expect(absoluteBottom, greaterThanOrEqualTo(viewportTop + 2400));
    });
  });
}

class _DestRect {
  _DestRect(this.left, this.top, this.right, this.bottom, this.scale);
  final int left;
  final int top;
  final int right;
  final int bottom;
  final double scale;
}

/// Extracts the source text of a single named Kotlin function by simple
/// brace-depth counting - sufficient for this file's straightforward control
/// flow, matching the helper already used by
/// `wallpaper_only_no_default_clock_test.dart`.
String _extractFunction(String source, String name) {
  final startMatch = RegExp('fun $name\\(').firstMatch(source);
  expect(startMatch, isNotNull, reason: 'expected a `fun $name(` in the source');
  final start = startMatch!.start;
  var depth = 0;
  var seenOpenBrace = false;
  for (var i = start; i < source.length; i++) {
    final ch = source[i];
    if (ch == '{') {
      depth++;
      seenOpenBrace = true;
    } else if (ch == '}') {
      depth--;
      if (seenOpenBrace && depth == 0) {
        return source.substring(start, i + 1);
      }
    }
  }
  fail('unterminated function body for $name');
}

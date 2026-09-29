import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/explore/data/models/wallpaper_model.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_assets.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the two reported Bunny/DEPTH parity bugs, driven
/// entirely by the REAL production payloads for `bunny-25m3g7`
/// (`bunny_real_feed_row.json` = the list row the user taps,
/// `bunny_real_detail.json` = the detail response that follows).
///
/// Ground truth for every number asserted here was measured directly off the
/// backend's own server-rendered composite, `preview.webp` (941x1672):
///
///   * white hours "10" ink spans y = 255..603  (349 px tall)
///   * orange minutes "12" ink spans y = 621..973 (353 px tall)
///   * => 17 px of background between them, i.e. 17/349 = 0.0487 of the ink
///   * the date "10 NOV 2025" is baked in too, at y = 181..222
///   * `background.webp` is a 2.8 kB PURE BLACK plate - it contains no
///     subject, no clock and no date
void main() {
  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  group('BUG 1 - DEPTH Details renders the design LIVE, never the frozen '
      'server composite, whenever it has enough to reconstruct it', () {
    test(
      'opened straight from a FEED row, live composition engages IMMEDIATELY '
      '- no flash between a baked-looking first frame and a live one, '
      'because Bunny\'s feed row already carries background/foreground/'
      'clockConfig (the backend echoes all three there, unlike `assets`)',
      () {
        // The feed row carries no `assets` map and no full-resolution URL -
        // `fromApiFeedItem` deliberately points `fullUrl` at the thumbnail so
        // a list never pulls a multi-megabyte image. But `background`,
        // `foreground` and the legacy `clockConfig` are NOT part of `assets`
        // - they are top-level fields the backend echoes on every row - so
        // `supportsDepth` and `hasDesign` are already both true on this very
        // first, pre-detail-fetch frame. Verified directly against the real
        // production feed row: this is the concrete, known outcome, not a
        // hypothetical - see the loading-behaviour requirement this proves.
        final row = fixture('bunny_real_feed_row');
        final w = WallpaperModel.fromApiFeedItem(row).toEntity();
        final visual = w.resolveDetailsVisual();

        expect(w.type, WallpaperType.depth);
        expect(w.assets, isEmpty, reason: 'a feed row carries no assets map');
        expect(w.supportsDepth, isTrue);
        expect(w.hasDesign, isTrue);
        expect(
          visual.useDepthLiveComposition,
          isTrue,
          reason: 'the KNOWN wallpaper (shown before the detail response '
              'even lands) already renders live - there is no frozen-then-'
              'live flash for Bunny specifically',
        );
      },
    );

    test(
      'a depth wallpaper whose feed row genuinely lacks layer info (a '
      'hypothetical case Bunny\'s own row does not exercise) safely falls '
      'back to the thumbnail rather than crashing on a null layer',
      () {
        final row = Map<String, dynamic>.from(fixture('bunny_real_feed_row'))
          ..['background'] = null
          ..['foreground'] = null
          ..['clockConfig'] = null;
        final w = WallpaperModel.fromApiFeedItem(row).toEntity();
        final visual = w.resolveDetailsVisual();

        expect(w.supportsDepth, isFalse);
        expect(visual.useDepthLiveComposition, isFalse);
        expect(visual.imageUrl, w.thumbnailUrl);
      },
    );

    test(
      'once the detail response lands with BOTH layers and an authored '
      'design, Details renders LIVE from BACKGROUND, never the baked '
      'PREVIEW composite',
      () {
        final w = WallpaperModel.fromApiDetail(fixture('bunny_real_detail'))
            .toEntity();
        final visual = w.resolveDetailsVisual();

        expect(w.supportsDepth, isTrue);
        expect(w.hasDesign, isTrue);
        expect(visual.useDepthLiveComposition, isTrue);
        expect(visual.imageUrl, w.assets[AssetKind.background]!.url);
        expect(visual.foregroundUrl, w.assets[AssetKind.foreground]!.url);
        expect(
          visual.imageUrl,
          isNot(w.assets[AssetKind.preview]!.url),
          reason: 'the frozen "10:12" composite must never be the final '
              'paint when the live layers are available',
        );
      },
    );

    test('the live path draws the clock/date, and nothing is baked in to '
        'double it against', () {
      final w = WallpaperModel.fromApiDetail(fixture('bunny_real_detail'))
          .toEntity();
      final visual = w.resolveDetailsVisual();

      expect(visual.containsBakedClockAndDate, isFalse);
      expect(visual.drawClockAndDate, isTrue,
          reason: 'the raw BACKGROUND plate has nothing baked in - the '
              'design must be drawn live to be visible at all');
      expect(visual.drawWidgets, isFalse,
          reason: 'bunny authors no studio widgets');
    });

    test('the background plate really is the pure-black plate - proof '
        'the OLD composite is not silently smuggled back in as '
        '"the background"', () {
      final w = WallpaperModel.fromApiDetail(fixture('bunny_real_detail'))
          .toEntity();
      final visual = w.resolveDetailsVisual();

      // The BACKGROUND asset (2.8 kB, pure black) is exactly what
      // DepthLiveComposition paints as its base layer - the design being
      // drawn live on top of it is what makes it a real, non-empty picture,
      // not the PREVIEW's already-flattened pixels.
      expect(visual.imageUrl, w.backgroundUrl);
      expect(visual.imageUrl, isNot(w.assets[AssetKind.preview]!.url));
    });

    test('FALLBACK: a depth wallpaper missing ONLY the foreground (but with '
        'a real background and a real PREVIEW - it genuinely went through '
        'the depth pipeline) falls back to the BAKED PREVIEW, overlay '
        'suppressed', () {
      final detail = fixture('bunny_real_detail');
      final stripped = Map<String, dynamic>.from(detail)
        ..['foreground'] = null
        ..['assets'] = {
          'BACKGROUND': detail['assets']['BACKGROUND'],
          'PREVIEW': detail['assets']['PREVIEW'],
        };
      final w = WallpaperModel.fromApiDetail(stripped).toEntity();
      final visual = w.resolveDetailsVisual();

      expect(w.supportsDepth, isFalse,
          reason: 'supportsDepth requires BOTH layers');
      expect(visual.useDepthLiveComposition, isFalse);
      expect(visual.imageUrl, w.assets[AssetKind.preview]!.url);
      expect(visual.containsBakedClockAndDate, isTrue,
          reason: 'a real background WAS published - this wallpaper went '
              'through the depth pipeline, so its composite is genuinely '
              'baked by the same legacy compositor as a fully-formed one');
      expect(visual.drawClockAndDate, isFalse);
    });

    test('FALLBACK: a depth-typed wallpaper with NEITHER layer published at '
        'all has no evidence its fallback asset is actually baked, so the '
        'overlay stays ON rather than risking a silently missing clock', () {
      final detail = fixture('bunny_real_detail');
      final stripped = Map<String, dynamic>.from(detail)
        ..['background'] = null
        ..['foreground'] = null
        ..['assets'] = <String, dynamic>{};
      final w = WallpaperModel.fromApiDetail(stripped).toEntity();
      final visual = w.resolveDetailsVisual();

      expect(w.supportsDepth, isFalse);
      expect(w.backgroundUrl, isNull);
      expect(w.foregroundMaskUrl, isNull);
      expect(visual.useDepthLiveComposition, isFalse);
      expect(visual.containsBakedClockAndDate, isFalse,
          reason: 'no depth layer was ever published for this wallpaper - '
              'there is no evidence the fallback asset is a real baked '
              'composite, so it must not be treated as one');
      expect(visual.drawClockAndDate, isTrue);
    });

    test('FALLBACK: a depth wallpaper missing the background safely falls '
        'back rather than crashing on a null layer', () {
      final detail = fixture('bunny_real_detail');
      final stripped = Map<String, dynamic>.from(detail)
        ..['background'] = null
        ..['assets'] = {'FOREGROUND': detail['assets']['FOREGROUND']};
      final w = WallpaperModel.fromApiDetail(stripped).toEntity();
      final visual = w.resolveDetailsVisual();

      expect(w.supportsDepth, isFalse);
      expect(visual.useDepthLiveComposition, isFalse);
    });

    test('FALLBACK: a depth wallpaper with both layers but NO authored '
        'design falls back to the composed PREVIEW - there is no design '
        'to render live', () {
      final detail = fixture('bunny_real_detail');
      final stripped = Map<String, dynamic>.from(detail)
        ..['clockConfig'] = null
        ..['studio'] = null;
      final w = WallpaperModel.fromApiDetail(stripped).toEntity();
      final visual = w.resolveDetailsVisual();

      expect(w.supportsDepth, isTrue, reason: 'both layers are still present');
      expect(w.hasDesign, isFalse);
      expect(visual.useDepthLiveComposition, isFalse);
      expect(visual.imageUrl, w.assets[AssetKind.preview]!.url);
    });

    test('if a depth payload resolves to the raw BACKGROUND plate via the '
        'flattened-asset fallback (no live composition, no PREVIEW either), '
        'the overlay is NOT suppressed - a black plate has nothing baked '
        'in', () {
      // The dangerous shape this guards: no design (so live composition is
      // off), no PREVIEW, no ORIGINAL and an empty thumbnail, which makes
      // `fullUrl` fall through to the BACKGROUND plate. The overlay must
      // stay off only when something is genuinely baked in.
      final detail = fixture('bunny_real_detail');
      final stripped = Map<String, dynamic>.from(detail)
        ..['clockConfig'] = null
        ..['studio'] = null
        ..['thumbnail'] = ''
        ..['assets'] = {
          'BACKGROUND': detail['assets']['BACKGROUND'],
          'FOREGROUND': detail['assets']['FOREGROUND'],
        };
      final w = WallpaperModel.fromApiDetail(stripped).toEntity();
      final visual = w.resolveDetailsVisual();

      expect(visual.useDepthLiveComposition, isFalse,
          reason: 'no design was authored');
      expect(visual.imageUrl, w.backgroundUrl);
      expect(visual.containsBakedClockAndDate, isFalse);
      expect(visual.drawClockAndDate, isFalse,
          reason: 'hasDesign is false, so there is nothing TO draw');
    });

    test('APPLY still takes the separate depth layers directly (never '
        'through resolveDetailsVisual), so the real depth effect and '
        'foreground occlusion survive unaffected by this Details change',
        () {
      final w = WallpaperModel.fromApiDetail(fixture('bunny_real_detail'))
          .toEntity();

      expect(w.compositeBackgroundUrl, w.assets[AssetKind.background]!.url);
      expect(w.foregroundMaskUrl, w.assets[AssetKind.foreground]!.url);
      expect(w.supportsDepth, isTrue);
      // No studio scene exists here, so the scene-grade resolver must stay
      // out of the way entirely.
      expect(w.design?.styledPreviewUrl, isNull);
      expect(w.applyBackgroundUrl, w.fullUrl);
    });

    test('the authored clock config survives the round trip unchanged - '
        'this is what Details now renders LIVE instead of the baked pixels',
        () {
      final w = WallpaperModel.fromApiDetail(fixture('bunny_real_detail'))
          .toEntity();
      final clock = w.design!.clock!;

      expect(clock.sizePx, 208);
      expect(clock.font, ClockFont.oswald);
      expect(clock.timeLayout, ClockTimeLayout.stackedCompact);
      expect(clock.minutesColor, 0xFFE65100, reason: 'the orange minutes');
      expect(clock.colorMode, ClockColorMode.split);
      expect(clock.customX, closeTo(0.348, 1e-9));
      expect(clock.customY, closeTo(0.274, 1e-9));
    });
  });

}

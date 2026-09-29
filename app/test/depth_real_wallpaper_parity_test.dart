import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/features/explore/data/models/wallpaper_model.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_assets.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Closure pass, DEPTH verification: `bunny-25m3g7` is, as of this session,
/// the ONLY depth-type wallpaper that exists in production - confirmed via
/// an exhaustive `GET /wallpapers?type=depth&limit=50` survey (1 result,
/// `hasMore: false`). It carries `studio: null` - it is a LEGACY depth
/// wallpaper, authored entirely through the old top-level `clockConfig`,
/// never migrated to `studio`. A second depth wallpaper referenced in an
/// earlier pass's test fixture (`chatgpt-image-14-...`) no longer exists in
/// production (`RESOURCE_NOT_FOUND`) - it was unpublished/deleted between
/// sessions.
///
/// Net effect: there is currently NO production wallpaper that combines
/// `type: depth` with an authored `studio.scene` grade. The
/// `applyBackgroundUrl` scene-grade fix added this session is therefore
/// verified here to correctly NOT engage for this real payload (no
/// `STYLED_PREVIEW` exists to prefer), while depth's own layering,
/// z-order and legacy-clock behaviour keep working exactly as before -
/// this is the full, honest extent of what "DEPTH parity" can mean against
/// today's actual backend data.
///
/// A later pass corrected `resolveDetailsVisual`'s DEPTH behaviour: Bunny has
/// both raw layers AND an authored design, so Details now reconstructs it
/// LIVE (background -> DesignOverlay -> foreground) instead of painting the
/// server's flattened `PREVIEW`, which is baked once at publish time and
/// would otherwise show a permanently frozen "10:12". See
/// `bunny_depth_parity_test.dart` for the full live/fallback matrix; this
/// file's own resolver test is updated below to match.
void main() {
  late Map<String, dynamic> json;

  setUpAll(() {
    json = jsonDecode(
      File('test/fixtures/bunny_real_detail.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  test('bunny is a legacy depth wallpaper with no studio at all', () {
    final w = WallpaperModel.fromApiDetail(json).toEntity();
    expect(w.type, WallpaperType.depth);
    expect(w.supportsDepth, isTrue, reason: 'both layers are present');
    // `studio: null` in the payload - the design comes entirely from the
    // legacy `clockConfig` container, which `WallpaperModel.toEntity`
    // synthesizes into a `StudioDesign` when `studio` itself is absent.
    expect(w.hasDesign, isTrue);
    expect(w.design?.styledPreviewUrl, isNull);
  });

  test(
    'resolveDetailsVisual renders the design LIVE from the raw BACKGROUND '
    'plate, never the baked PREVIEW composite - the composite is frozen at '
    'publish time and would show a permanently stuck "10:12" otherwise',
    () {
      final w = WallpaperModel.fromApiDetail(json).toEntity();
      final visual = w.resolveDetailsVisual();

      expect(w.assets.containsKey(AssetKind.styledPreview), isFalse);
      expect(visual.useDepthLiveComposition, isTrue);
      expect(visual.imageUrl, w.assets[AssetKind.background]?.url);
      expect(visual.foregroundUrl, w.assets[AssetKind.foreground]?.url);
      expect(
        visual.imageUrl,
        isNot(w.assets[AssetKind.preview]?.url),
        reason: 'the frozen server composite must never be the final paint '
            'once the live layers are available',
      );
      expect(
        visual.drawClockAndDate,
        isTrue,
        reason: 'the raw background plate has nothing baked in, so the '
            'clock must be drawn live to be visible at all',
      );
      expect(
        visual.drawWidgets,
        isFalse,
        reason: 'bunny authors no studio widgets at all',
      );
    },
  );

  test(
    'applyBackgroundUrl correctly does NOT engage - there is no '
    'STYLED_PREVIEW to prefer, so it falls back to fullUrl exactly like '
    'before this session\'s scene-grade fix',
    () {
      final w = WallpaperModel.fromApiDetail(json).toEntity();
      expect(w.applyBackgroundUrl, w.fullUrl);
      expect(w.design?.styledPreviewUrl, isNull);
    },
  );

  test(
    'the depth layers themselves are untouched by any scene-grade '
    'resolution - background/foreground stay the raw plates the compositor '
    'needs, never a flattened composite',
    () {
      final w = WallpaperModel.fromApiDetail(json).toEntity();
      expect(w.backgroundUrl, w.assets[AssetKind.background]?.url);
      expect(w.foregroundMaskUrl, w.assets[AssetKind.foreground]?.url);
      expect(w.compositeBackgroundUrl, w.backgroundUrl);
    },
  );

  test('the legacy clockConfig carries real authored values, not defaults',
      () {
    final w = WallpaperModel.fromApiDetail(json).toEntity();
    final clock = w.design?.clock;
    expect(clock, isNotNull);
    expect(clock!.sizePx, 208);
    expect(clock.timeLayout.name, 'stackedCompact');
    expect(clock.minutesColor, 0xFFE65100);
    expect(clock.style.name, 'monument');
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/features/explore/data/models/wallpaper_model.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Section 4's audit: what Details must show for a VIDEO wallpaper that
/// carries an authored `studio` design.
///
/// `nature-ua1ub9` (fixture: `studio_video_nature.json`) is the one
/// production wallpaper found with `type: "video"` AND a non-null `studio` -
/// surveyed directly against the live public API (`GET
/// /api/v1/public/wallpapers?type=video`, then the detail for each result).
/// Every other video wallpaper in production today has `studio: null`.
///
/// The finding this fixture proves: unlike DEPTH, a VIDEO wallpaper's
/// `styledPreviewUrl` is `null` here even though `clock.enabled` and
/// `dateWidget.enabled` are both `true` - the backend has never queued (or
/// cannot queue) a `STUDIO_RENDER` bake for this generation, because there is
/// no single flattened frame to bake into: the wallpaper IS the moving clip.
/// So Details must play the real loop (`LiveWallpaperPlayer`, matching what
/// Apply ultimately sets) and draw the clock/date live on top via
/// `DesignOverlay`, exactly as it already does for a STANDARD wallpaper whose
/// `PREVIEW` is scene-only. `resolveDetailsVisual()` already produces this
/// correctly because `supportsDepth` is unconditionally `false` for
/// `type == video`, so `clockAndDateAlreadyBaked` can never be true for this
/// type - this test locks that in against a real payload rather than a
/// synthetic one.
void main() {
  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  test(
    'a VIDEO wallpaper with an authored studio design has no baked preview',
    () {
      final json = fixture('studio_video_nature');
      final w = WallpaperModel.fromApiDetail(json).toEntity();

      expect(w.type, WallpaperType.live);
      expect(w.hasDesign, isTrue, reason: 'clock and dateWidget are enabled');
      expect(
        w.design?.styledPreviewUrl,
        isNull,
        reason: 'production has never baked a STYLED_PREVIEW for this video',
      );
      expect(w.video?.url, isNotEmpty);
    },
  );

  test(
    'resolveDetailsVisual says the clock/date must still be drawn live',
    () {
      final json = fixture('studio_video_nature');
      final w = WallpaperModel.fromApiDetail(json).toEntity();

      final visual = w.resolveDetailsVisual();
      expect(
        visual.drawClockAndDate,
        isTrue,
        reason:
            'a video never bakes the clock into any asset - Details must '
            'still compose it live over the playing clip, the same way '
            'Apply eventually will',
      );
      // No `widgets` are authored on this wallpaper (`widgets: []`).
      expect(visual.drawWidgets, isFalse);
    },
  );

  test(
    'a VIDEO wallpaper design is dynamic, so it needs the live apply engine',
    () {
      final json = fixture('studio_video_nature');
      final w = WallpaperModel.fromApiDetail(json).toEntity();

      expect(
        w.hasDynamicDesign,
        isTrue,
        reason: 'a ticking clock cannot be baked into a static apply',
      );
    },
  );

  test(
    'scene grading is absent for video, not merely undetermined - option C '
    'from the closure pass\'s three-way trace (baked into the actual video / '
    'baked only into poster / absent during playback)',
    () {
      final json = fixture('studio_video_nature');
      final w = WallpaperModel.fromApiDetail(json).toEntity();

      // `nature-ua1ub9`'s own scene happens to be fully neutral (every
      // numeric field 0, every toggle off) - an exhaustive survey of ALL 6
      // production video wallpapers (`GET /wallpapers?type=video`) found
      // this is the ONLY one with non-null `studio` at all, so there is no
      // video wallpaper anywhere in production with a REAL grade to observe
      // visually. What settles this precisely instead is architectural:
      // `styledPreviewUrl` is null here regardless of the grade being
      // trivial, confirming the backend's STUDIO_RENDER job has never
      // produced ANY output for a video-type wallpaper - not "sometimes
      // baked into the poster", never. And a full source sweep of every
      // native file that touches video frames (`GLVideoClockCompositor.kt`,
      // `WallpaperApplyService.kt`, `VideoWallpaperService`) contains no
      // brightness/contrast/saturation/warmth/vignette/grain application
      // anywhere - the one `ColorMatrix` in `WallpaperApplyService.kt` is an
      // unrelated fixed lock-screen dim filter, not `studio.scene`. So the
      // answer is (C): scene grading is architecturally absent during video
      // playback, not merely unobserved.
      expect(w.design?.styledPreviewUrl, isNull);
      // `StudioDesignMapper._scene` deliberately collapses an all-neutral
      // scene to `null` (`scene.hasVisibleEffect ? scene : null`) so
      // `hasDesign` stays honest about what was actually authored - this
      // payload's raw JSON scene has every field at its identity value, so
      // it correctly parses to `null` here rather than a no-op StudioScene.
      expect(w.design?.scene, isNull);
      final rawScene = json['studio']['scene'] as Map<String, dynamic>;
      expect(rawScene['brightness'], 0);
      expect(rawScene['contrast'], 0);
      expect(rawScene['saturation'], 0);
      expect(rawScene['warmth'], 0);
    },
  );
}

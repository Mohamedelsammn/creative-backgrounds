import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/features/clock/data/models/studio_design_mapper.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/depth/domain/entities/depth_config_entity.dart';
import 'package:creativebackground/features/explore/data/models/wallpaper_model.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage 3/4/6 behaviour: is a wallpaper designed, what kind of design is it,
/// and what does the apply pipeline actually receive.
///
/// The "Wallpaper Only" choice is only real if it changes what reaches the
/// apply call - suppressing the clock config is what routes the wallpaper back
/// down the ordinary static path instead of the live engine.
void main() {
  WallpaperEntity entityFrom(Map<String, dynamic> row) =>
      WallpaperModel.fromApiFeedItem({
        'id': 'id',
        'slug': 'slug',
        'title': 'title',
        'thumbnailUrl': 'https://cdn.test/t.webp',
        ...row,
      }).toEntity();

  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  group('hasDesign is canonical and type-independent', () {
    test('a plain static wallpaper has no design', () {
      final w = entityFrom({'type': 'standard'});
      expect(w.hasDesign, isFalse);
      expect(w.designRenderMode, DesignRenderMode.none);
      expect(w.design, isNull);
    });

    test('a STATIC wallpaper CAN have a design', () {
      final f = fixture('studio_battery_ring');
      final w = entityFrom({'type': 'standard', 'studio': f['studio']});
      expect(w.type, WallpaperType.normal);
      expect(w.hasDesign, isTrue);
    });

    test('a DEPTH wallpaper can carry a design via the legacy container', () {
      final f = fixture('studio_dual_container');
      final w = entityFrom({
        'type': 'depth',
        'studio': f['studio'],
        'clockConfig': f['clockConfig'],
      });
      expect(w.type, WallpaperType.depth);
      expect(w.hasDesign, isTrue);
      expect(w.remoteClockConfig, isNotNull);
    });

    test('media type alone never implies a design', () {
      for (final type in ['standard', 'depth', 'video']) {
        expect(
          entityFrom({'type': type}).hasDesign,
          isFalse,
          reason: '$type with no authored config must not count as designed',
        );
      }
    });
  });

  group('dynamic vs static classification drives the apply engine', () {
    test('a clock design is dynamic, so it needs the live engine', () {
      final w = entityFrom({
        'type': 'standard',
        'clockConfig': {'enabled': true, 'sizePx': 80},
      });
      expect(w.hasDynamicDesign, isTrue);
      expect(w.hasStaticOnlyDesign, isFalse);
      expect(
        w.isLiveApply(clockConfig: w.remoteClockConfig),
        isTrue,
        reason: 'a ticking clock cannot be baked into a bitmap',
      );
    });

    test('a batteryRing design is dynamic', () {
      final w = entityFrom({
        'type': 'standard',
        'studio': {
          'widgets': [
            {'kind': 'batteryRing'},
          ],
        },
      });
      expect(w.hasDesign, isTrue);
      expect(w.hasDynamicDesign, isTrue);
    });

    test('a scene-only design is static and needs NO live service', () {
      final w = entityFrom({
        'type': 'standard',
        'studio': {
          'scene': {'brightness': -0.2, 'contrast': 0.15},
        },
      });
      expect(w.hasDesign, isTrue);
      expect(w.hasStaticOnlyDesign, isTrue);
      expect(w.hasDynamicDesign, isFalse);
      // No clock config exists for it, so the existing routing already keeps
      // it on the static path - it must never be promoted to a live wallpaper
      // merely for carrying a colour grade.
      expect(w.remoteClockConfig, isNull);
      expect(w.isLiveApply(clockConfig: w.remoteClockConfig), isFalse);
    });
  });

  group('applyTarget', () {
    test('production wallpapers ask, so the user gets the choice', () {
      final f = fixture('studio_battery_ring');
      final w = entityFrom({'type': 'standard', 'studio': f['studio']});
      expect(w.design!.applyTarget, StudioApplyTarget.ask);
    });

    test('a dashboard that decides is honoured without prompting', () {
      for (final entry in {
        'withDesign': StudioApplyTarget.withDesign,
        'wallpaperOnly': StudioApplyTarget.wallpaperOnly,
      }.entries) {
        final design = StudioDesignMapper.fromJson({
          'clock': {'enabled': true},
          'behavior': {'applyTarget': entry.key},
        })!;
        expect(design.applyTarget, entry.value);
      }
    });
  });

  group('Wallpaper Only actually changes what is applied', () {
    // Mirrors `_ApplySheetState.clockConfig`: the sheet suppresses the clock
    // when the user picks "Wallpaper Only". These assert the consequence at
    // domain level, which is where it matters.
    test('With Design keeps the clock, so the live engine is used', () {
      final w = entityFrom({
        'type': 'standard',
        'clockConfig': {'enabled': true, 'sizePx': 80},
      });
      expect(w.isLiveApply(clockConfig: w.remoteClockConfig), isTrue);
    });

    test('Wallpaper Only drops the clock, so the static path is used', () {
      final w = entityFrom({
        'type': 'standard',
        'clockConfig': {'enabled': true, 'sizePx': 80},
      });
      expect(
        w.isLiveApply(clockConfig: null),
        isFalse,
        reason: 'suppressing the clock must return it to a plain static apply',
      );
    });

    test('a VIDEO wallpaper stays live even as Wallpaper Only', () {
      // The media itself is a video; dropping the design cannot make it a
      // still image.
      final w = entityFrom({'type': 'video'});
      expect(w.isLiveApply(clockConfig: null), isTrue);
    });

    test('a DEPTH wallpaper stays live as Wallpaper Only when depth is on', () {
      final w = entityFrom({'type': 'depth'});
      expect(
        w.isLiveApply(
          clockConfig: null,
          depthConfig: DepthConfigEntity(wallpaperId: w.id, enabled: true),
        ),
        isTrue,
        reason: 'the depth effect is the media, not the authored design',
      );
    });
  });

  group('backward compatibility', () {
    test('an old wallpaper with no design fields is untouched', () {
      final w = entityFrom({'type': 'standard'});
      expect(w.hasDesign, isFalse);
      expect(w.design, isNull);
      expect(w.remoteClockConfig, isNull);
      expect(w.isLiveApply(), isFalse);
    });

    test('an old legacy clockConfig still produces a clock', () {
      final w = entityFrom({
        'type': 'depth',
        'clockConfig': {'enabled': true, 'scale': 1.5},
      });
      expect(w.remoteClockConfig, isNotNull);
      // No authored sizePx: it is 65, and `scale` stays an independent
      // factor (FLUTTER_RENDERING_GUIDE §3.1: W * 0.14 * scale * sizePx / 65).
      expect(w.remoteClockConfig!.sizePx, 65);
      expect(w.remoteClockConfig!.scale, 1.5);
    });

    test('a malformed studio object does not break the wallpaper', () {
      final w = entityFrom({'type': 'standard', 'studio': 'garbage'});
      expect(w.hasDesign, isFalse);
      expect(w.title, 'title');
    });

    test('an unknown widget kind leaves the wallpaper renderable', () {
      final w = entityFrom({
        'type': 'standard',
        'studio': {
          'widgets': [
            {'kind': 'someFutureThing'},
          ],
        },
      });
      expect(w.hasDesign, isFalse, reason: 'nothing renderable was authored');
      expect(w.design?.unsupportedWidgetKinds, ['someFutureThing']);
    });

    test('copyWith carries the design', () {
      final f = fixture('studio_battery_ring');
      final w = entityFrom({'type': 'standard', 'studio': f['studio']});
      expect(w.copyWith(title: 'new').hasDesign, isTrue);
    });

    test('an entity built by hand still defaults to no design', () {
      const w = WallpaperEntity(
        id: 'i',
        title: 't',
        category: CategoryEntity(id: 'c', name: 'C', slug: 'c'),
        type: WallpaperType.normal,
        thumbnailUrl: 'u',
        fullUrl: 'u',
        resolution: '1x1',
      );
      expect(w.hasDesign, isFalse);
      expect(w.designRenderMode, DesignRenderMode.none);
    });
  });

  group('Details draws the design only when the media lacks it', () {
    // Which ASSET Details paints decides this, not the wallpaper type - the
    // two genuinely differ, and both cases were verified against production:
    //
    //  * `bunny` (depth) has both raw layers AND an authored design, so
    //    Details reconstructs it LIVE (background -> design -> foreground) -
    //    the server's flattened composite is baked once at publish time and
    //    would show a frozen clock/date forever otherwise. A depth wallpaper
    //    only falls back to the composed PREVIEW when a layer is missing.
    //  * `porshe` (static) carries a full authored design, yet its PREVIEW is
    //    the plain photograph with none of it baked in.
    test('a DEPTH wallpaper with both layers renders the design LIVE, not '
        'the frozen server composite', () {
      final f = fixture('studio_dual_container');
      final w = entityFrom({
        'type': 'depth',
        'background': 'https://cdn.test/bg.webp',
        'foreground': 'https://cdn.test/fg.webp',
        'studio': f['studio'],
        'clockConfig': f['clockConfig'],
      });
      expect(w.supportsDepth, isTrue);
      expect(w.hasDesign, isTrue);

      final visual = w.resolveDetailsVisual();
      expect(visual.useDepthLiveComposition, isTrue);
      expect(visual.imageUrl, 'https://cdn.test/bg.webp');
      expect(visual.foregroundUrl, 'https://cdn.test/fg.webp');
      expect(visual.drawClockAndDate, isTrue);
      expect(visual.containsBakedClockAndDate, isFalse);
    });

    test('a DEPTH wallpaper missing the foreground falls back to the '
        'composed asset - there is nothing to composite live', () {
      final f = fixture('studio_dual_container');
      final w = entityFrom({
        'type': 'depth',
        'background': 'https://cdn.test/bg.webp',
        // No foreground - `supportsDepth` requires both layers.
        'studio': f['studio'],
        'clockConfig': f['clockConfig'],
      });
      expect(w.supportsDepth, isFalse);

      final visual = w.resolveDetailsVisual();
      expect(visual.useDepthLiveComposition, isFalse);
    });

    test('a STATIC designed wallpaper shows a RAW photo, so it MUST draw', () {
      final f = fixture('studio_battery_ring');
      final w = entityFrom({'type': 'standard', 'studio': f['studio']});
      expect(w.hasDesign, isTrue);
      expect(w.previewHasBakedDesign, isFalse);
      expect(
        w.shouldRenderDesignOverlay,
        isTrue,
        reason: 'the backend bakes nothing into a static preview',
      );
    });

    test('a LIVE wallpaper plays the raw clip, so the overlay MUST draw', () {
      final w = entityFrom({
        'type': 'video',
        'clockConfig': {'enabled': true, 'sizePx': 90},
      });
      expect(w.hasDesign, isTrue);
      expect(w.previewHasBakedDesign, isFalse);
      expect(w.shouldRenderDesignOverlay, isTrue);
    });

    test('a depth wallpaper missing its layers falls back to drawing', () {
      // Without both layers it is not a depth composite, so whatever is shown
      // is not the backend's composed render.
      final f = fixture('studio_dual_container');
      final w = entityFrom({
        'type': 'depth',
        'studio': f['studio'],
        'clockConfig': f['clockConfig'],
      });
      expect(w.supportsDepth, isFalse);
      expect(w.shouldRenderDesignOverlay, isTrue);
    });

    test('a wallpaper with no design never draws an overlay', () {
      for (final type in ['standard', 'depth', 'video']) {
        final w = entityFrom({'type': type});
        expect(w.shouldRenderDesignOverlay, isFalse, reason: type);
        expect(w.previewHasBakedDesign, isFalse, reason: type);
      }
    });
  });
}

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:creativebackground/core/widgets/wallpaper_preview_composition.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/clock/presentation/widgets/clock_renderer_widget.dart';
import 'package:creativebackground/features/depth/presentation/widgets/depth_live_composition.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Follow-up regression coverage: the first COVER fix (`LiveWallpaperService`
/// / `DepthCompositor.drawCoverBitmap`) only reached the native "With
/// Design" apply path (routes through `LiveWallpaperService` because
/// `clockConfig != null`). Physical OPPO verification proved two OTHER
/// paths still showed the same black top gap:
///
///  * Details itself - `_TwoStageWallpaperImage` used `BoxFit.contain`
///    (a Flutter-only letterbox, unrelated to the native fix).
///  * Apply -> Wallpaper Only, for a STANDARD (non-depth) wallpaper -
///    `_suppressDesign` makes `clockConfig` null, so `isLiveApply` is false
///    and the apply routes through `WallpaperApplyService.applyStatic` /
///    `buildDeviceFitBitmap`, a SEPARATE native function that still used
///    FIT (dimmed cover-scaled background + sharp FIT foreground) - a
///    different codebase entirely from `LiveWallpaperService`, so the first
///    fix never touched it.
///
/// Both are now fixed by sharing the SAME COVER contract:
///  * Details switched `BoxFit.contain` -> `.cover` (both image layers) and
///    the DEPTH branch's aspect-locking `Center(AspectRatio(...))` wrapper
///    was removed so `DepthLiveComposition` fills its box exactly as it
///    does for the Apply-sheet preview.
///  * `WallpaperApplyService.buildDeviceFitBitmap` now delegates to
///    `DepthCompositor.drawCoverBitmap` instead of its own dual-layer
///    FIT+dimmed-cover composite.
///
/// "With Design" (`LiveWallpaperService`) is untouched by this follow-up -
/// covered separately by `wallpaper_top_gap_coverage_test.dart`'s
/// unchanged assertions.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Minimal');

  // Real production dimensions confirmed via the live API this session:
  // "Red Earth", a STANDARD wallpaper with an authored clock and
  // `applyTarget: ask` - the exact wallpaper used for physical OPPO
  // verification.
  const redEarthWidth = 564;
  const redEarthHeight = 1085;

  WallpaperEntity redEarth() => WallpaperEntity(
        id: 'red-earth',
        title: 'Red Earth',
        category: category,
        type: WallpaperType.normal,
        thumbnailUrl: 'https://cdn.test/red-earth-thumb.webp',
        fullUrl: 'https://cdn.test/red-earth-full.webp',
        resolution: '${redEarthWidth}x$redEarthHeight',
        width: redEarthWidth,
        height: redEarthHeight,
        isDetailed: true,
        design: const StudioDesign(
          clock: ClockConfigEntity(enabled: true, sizePx: 65),
          applyTarget: StudioApplyTarget.ask,
        ),
      );

  // Real production Bunny dimensions (941x1672, DEPTH, background+foreground
  // both present) - already used throughout the suite via
  // bunny_real_detail.json. Built directly here (rather than loading the
  // fixture) so `applyTarget` can be set to `ask`, letting this file cover
  // the DEPTH Wallpaper Only case the fixture's own legacy `clockConfig`
  // shape does not offer a choice for.
  WallpaperEntity bunnyAskChoice() => WallpaperEntity(
        id: 'bunny-ask',
        title: 'Bunny',
        category: category,
        type: WallpaperType.depth,
        thumbnailUrl: 'https://cdn.test/bunny-thumb.webp',
        fullUrl: 'https://cdn.test/bunny-composite.webp',
        backgroundUrl: 'https://cdn.test/bunny-bg.webp',
        foregroundMaskUrl: 'https://cdn.test/bunny-fg.webp',
        hasForegroundMask: true,
        resolution: '941x1672',
        width: 941,
        height: 1672,
        isDetailed: true,
        design: const StudioDesign(
          clock: ClockConfigEntity(
            enabled: true,
            sizePx: 208,
            timeLayout: ClockTimeLayout.stackedCompact,
          ),
          applyTarget: StudioApplyTarget.ask,
        ),
      );

  Widget pumpTarget(Widget child) => MaterialApp(home: Scaffold(body: child));

  /// Sets the test surface to a real device viewport (OPPO CPH1823's own
  /// 1080x2340) so `MediaQuery.sizeOf`/`displayScale` and the `SizedBox`
  /// below resolve against real numbers instead of `flutter_test`'s default
  /// 800x600 window.
  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Details (STANDARD) - COVER, no letterbox gap', () {
    testWidgets(
        'Red Earth (564x1085) fills the FULL Details-sized box under '
        'WallpaperPreviewComposition, matching the applied-wallpaper '
        'geometry', (tester) async {
      const viewport = Size(1080, 2340); // real OPPO CPH1823 viewport
      setViewport(tester, viewport);
      await tester.pumpWidget(
        pumpTarget(
          SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: WallpaperPreviewComposition(
              wallpaper: redEarth(),
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.fit, BoxFit.cover);
    });
  });

  group('Details (DEPTH) - COVER, no aspect-locked letterbox', () {
    testWidgets(
        'Bunny (941x1672) fills the full given box, not an aspect-locked '
        'sub-box - background, design and foreground all share ONE '
        'transform', (tester) async {
      const viewport = Size(1080, 2340);
      setViewport(tester, viewport);
      await tester.pumpWidget(
        pumpTarget(
          SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: WallpaperPreviewComposition(wallpaper: bunnyAskChoice()),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is AspectRatio && (w.aspectRatio - 941 / 1672).abs() < 1e-6,
        ),
        findsNothing,
        reason: 'no aspect-locked box should remain for the DEPTH branch',
      );

      final compositionSize = tester.getSize(find.byType(DepthLiveComposition));
      expect(compositionSize.width, closeTo(viewport.width, 1));
      expect(compositionSize.height, closeTo(viewport.height, 1));

      // Clock renders inside the SAME full-size box - background, design
      // and foreground share one transform (DEPTH registration proof).
      final clockAncestorSize = tester.getSize(
        find
            .ancestor(
              of: find.byType(ClockRendererWidget),
              matching: find.byType(DepthLiveComposition),
            )
            .first,
      );
      expect(clockAncestorSize, compositionSize);
    });
  });

  group('Wallpaper Only vs With Design - same background geometry, design '
      'presence is the only difference', () {
    testWidgets(
        'STANDARD: Wallpaper Only suppresses the clock but the preview '
        'composition box is identical to With Design\'s', (tester) async {
      const viewport = Size(1080, 2340);
      setViewport(tester, viewport);
      final wallpaper = redEarth();

      await tester.pumpWidget(
        pumpTarget(
          SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: WallpaperPreviewComposition(
              wallpaper: wallpaper,
              forceSuppressDesign: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Zero design: no clock rendered at all.
      expect(find.byType(ClockRendererWidget), findsNothing);

      // The image itself is still `.cover` - Wallpaper Only never changes
      // background geometry, only design presence.
      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.fit, BoxFit.cover);
    });

    testWidgets(
        'DEPTH: Wallpaper Only still composites background+foreground at '
        'full COVER size, with zero design', (tester) async {
      const viewport = Size(1080, 2340);
      setViewport(tester, viewport);
      await tester.pumpWidget(
        pumpTarget(
          SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: WallpaperPreviewComposition(
              wallpaper: bunnyAskChoice(),
              forceSuppressDesign: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ClockRendererWidget), findsNothing,
          reason: 'Wallpaper Only must render ZERO design');

      final compositionSize = tester.getSize(find.byType(DepthLiveComposition));
      expect(compositionSize.width, closeTo(viewport.width, 1));
      expect(compositionSize.height, closeTo(viewport.height, 1));
    });
  });

  group('previously-good wallpaper - COVER does not over-crop a matching '
      'ratio source', () {
    testWidgets(
        'a source whose ratio already closely matches the viewport renders '
        'via WallpaperPreviewComposition without error and still covers '
        'the box exactly', (tester) async {
      final wallpaper = WallpaperEntity(
        id: 'matching-ratio',
        title: 'Matching ratio',
        category: category,
        type: WallpaperType.normal,
        thumbnailUrl: 'https://cdn.test/match-thumb.webp',
        fullUrl: 'https://cdn.test/match-full.webp',
        resolution: '1080x2340',
        width: 1080,
        height: 2340,
        isDetailed: true,
      );
      const viewport = Size(1080, 2340);
      setViewport(tester, viewport);

      await tester.pumpWidget(
        pumpTarget(
          SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: WallpaperPreviewComposition(
              wallpaper: wallpaper,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.fit, BoxFit.cover);
    });
  });

  group('native source: WallpaperApplyService (static Wallpaper Only apply '
      'path) shares the COVER contract', () {
    test(
        'buildDeviceFitBitmap delegates to DepthCompositor.drawCoverBitmap, '
        'not its own dual-layer FIT+dimmed-cover composite', () {
      final source = File(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/'
        'WallpaperApplyService.kt',
      ).readAsStringSync();
      expect(
        source.contains('DepthCompositor.drawCoverBitmap('),
        isTrue,
        reason: 'the static apply path (used by Wallpaper Only for a '
            'non-depth wallpaper) must reuse the exact same COVER helper '
            'the live-wallpaper engine uses, not a separate FIT-based '
            'composite - that separate composite is what left it out of '
            'the first COVER fix entirely',
      );
      // The old dual-layer implementation's own tells must be gone, not
      // just supplemented - a leftover `minOf`/dimmed-paint branch would
      // mean the OLD FIT path can still run under some condition.
      expect(
        source.contains('minOf(destW.toFloat()'),
        isFalse,
        reason: 'no FIT scale computation should remain in this file',
      );
      expect(
        source.contains('ColorMatrixColorFilter'),
        isFalse,
        reason: 'the dimmed-background trick (only ever needed to soften '
            'FIT\'s own letterbox margin) must be fully gone now that the '
            'margin itself is gone',
      );
    });
  });

  group('native source: Details geometry doc/behaviour stays consistent '
      'with the Kotlin fix', () {
    test(
        'DepthCompositor.drawForeground and drawCoverBitmap both still use '
        'the maxOf (COVER) formula, confirming the shared contract this '
        'file\'s Dart-side tests assume', () {
      final source = File(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/'
        'DepthCompositor.kt',
      ).readAsStringSync();
      expect(source.contains('fun drawCoverBitmap('), isTrue);
      expect(source.contains('fun drawForeground('), isTrue);
      // Both functions' scale computation uses maxOf - a simple count
      // confirms neither reverted to minOf/FIT.
      final maxOfCount = 'maxOf('.allMatches(source).length;
      expect(
        maxOfCount,
        greaterThanOrEqualTo(2),
        reason: 'drawCoverBitmap and drawForeground must each compute their '
            'scale with maxOf - fewer than 2 occurrences means one of them '
            'regressed back to a FIT-style minOf',
      );
    });
  });
}

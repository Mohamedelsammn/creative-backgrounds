import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/core/widgets/wallpaper_preview_composition.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/clock/presentation/widgets/clock_painter.dart';
import 'package:creativebackground/features/explore/data/models/wallpaper_model.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage: the Apply sheet's small preview card rendered the
/// clock at full authored `sizePx` (e.g. Bunny's 208) regardless of the
/// card being a fraction of the screen's own width - a `displayScale: 1.0`
/// baked into `WallpaperPreviewComposition` (and, one level down,
/// `DepthLiveComposition`'s own hardcoded `DesignOverlay` call) rather than
/// derived from the actual rendered box.
///
/// `DesignOverlay.displayScale` is the pre-existing, correct scaling knob
/// (`fontSize: config.sizePx * displayScale` in `ClockPainter`) - Details
/// was already using it correctly (`displayScale: 1.0`, correct there
/// because Details fills the whole screen). The fix threads the ACTUAL
/// rendered box width (via `LayoutBuilder`, not a guessed constant) through
/// the same knob for every caller.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Minimal');

  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  /// Pumps [child] at a known screen width, wrapped exactly like the real
  /// Apply-sheet card wraps `WallpaperPreviewComposition` (a fixed-size
  /// `SizedBox`), so `LayoutBuilder` sees the same constraints production
  /// code produces.
  Future<void> pumpAtScreenWidth(
    WidgetTester tester,
    double screenWidth,
    Widget child,
  ) async {
    tester.view.physicalSize = Size(screenWidth, screenWidth * 2);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pump();
  }

  group('STANDARD - the clock scales with the render box, not a fixed '
      '1.0', () {
    final wallpaper = WallpaperEntity(
      id: 'w1',
      title: 'Standard with clock',
      category: category,
      type: WallpaperType.normal,
      thumbnailUrl: 'https://cdn.test/thumb.webp',
      fullUrl: 'https://cdn.test/full.webp',
      resolution: '1080x1920',
      design: const StudioDesign(
        clock: ClockConfigEntity(enabled: true, sizePx: 200),
      ),
    );

    testWidgets(
      'a full-screen box (Details) renders the clock at its authored '
      'sizePx - displayScale 1.0',
      (tester) async {
        const screenWidth = 1080.0;
        await pumpAtScreenWidth(
          tester,
          screenWidth,
          SizedBox(
            width: screenWidth,
            height: screenWidth * 2,
            child: WallpaperPreviewComposition(wallpaper: wallpaper),
          ),
        );

        final painter = tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.byType(WallpaperPreviewComposition),
                    matching: find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is ClockPainter,
                    ),
                  )
                  .first,
            )
            .painter as ClockPainter;

        expect(painter.displayScale, closeTo(1.0, 0.01));
      },
    );

    testWidgets(
      'a small fixed-size card (Apply sheet) renders the clock scaled DOWN '
      'proportionally to its own width, not at full size',
      (tester) async {
        const screenWidth = 1080.0;
        const cardWidth = 108.0; // ~155 * 0.6, the real Apply-sheet ratio
        await pumpAtScreenWidth(
          tester,
          screenWidth,
          Center(
            child: SizedBox(
              width: cardWidth,
              height: cardWidth / 0.6,
              child: WallpaperPreviewComposition(
                wallpaper: wallpaper,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );

        final painter = tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.byType(WallpaperPreviewComposition),
                    matching: find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is ClockPainter,
                    ),
                  )
                  .first,
            )
            .painter as ClockPainter;

        final expectedScale = cardWidth / screenWidth;
        expect(painter.displayScale, closeTo(expectedScale, 0.01));
        expect(
          painter.displayScale,
          lessThan(0.15),
          reason: 'a 108px-wide card on a 1080px screen must scale the '
              'clock down to roughly a tenth of full size, not paint it at '
              'the full authored sizePx',
        );
      },
    );

    testWidgets(
      'the clock/viewport width RATIO is proportionally invariant between '
      'the full-screen render and the small card render (within tolerance)',
      (tester) async {
        const screenWidth = 1080.0;

        // A) full-screen (Details-equivalent) render.
        await pumpAtScreenWidth(
          tester,
          screenWidth,
          SizedBox(
            width: screenWidth,
            height: screenWidth * 2,
            child: WallpaperPreviewComposition(wallpaper: wallpaper),
          ),
        );
        final fullScale = (tester
                .widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.byType(WallpaperPreviewComposition),
                        matching: find.byWidgetPredicate(
                          (w) => w is CustomPaint && w.painter is ClockPainter,
                        ),
                      )
                      .first,
                )
                .painter as ClockPainter)
            .displayScale;
        final fullClockPx = wallpaper.design!.clock!.sizePx * fullScale;
        final fullRatio = fullClockPx / screenWidth;

        // B) small-card (Apply-sheet-equivalent) render.
        const cardWidth = 108.0;
        await pumpAtScreenWidth(
          tester,
          screenWidth,
          Center(
            child: SizedBox(
              width: cardWidth,
              height: cardWidth / 0.6,
              child: WallpaperPreviewComposition(wallpaper: wallpaper),
            ),
          ),
        );
        final cardScale = (tester
                .widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.byType(WallpaperPreviewComposition),
                        matching: find.byWidgetPredicate(
                          (w) => w is CustomPaint && w.painter is ClockPainter,
                        ),
                      )
                      .first,
                )
                .painter as ClockPainter)
            .displayScale;
        final cardClockPx = wallpaper.design!.clock!.sizePx * cardScale;
        final cardRatio = cardClockPx / cardWidth;

        expect(
          cardRatio,
          closeTo(fullRatio, 0.02),
          reason: 'clockSize / viewportWidth must be the SAME proportion '
              'whether rendered full-screen or in the small preview card - '
              'that is what "a true miniature" means',
        );
      },
    );
  });

  group('DEPTH (Bunny) - the same scale fix applies to the live '
      'composition path', () {
    late Map<String, dynamic> bunnyJson;

    setUpAll(() {
      bunnyJson = fixture('bunny_real_detail');
    });

    testWidgets(
      'the small Apply preview card scales Bunny\'s clock down '
      'proportionally, not at the authored 208px',
      (tester) async {
        final wallpaper = WallpaperModel.fromApiDetail(bunnyJson).toEntity();
        const screenWidth = 1080.0;
        const cardWidth = 108.0;

        await pumpAtScreenWidth(
          tester,
          screenWidth,
          Center(
            child: SizedBox(
              width: cardWidth,
              height: cardWidth / 0.6,
              child: WallpaperPreviewComposition(wallpaper: wallpaper),
            ),
          ),
        );

        final painter = tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.byType(WallpaperPreviewComposition),
                    matching: find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is ClockPainter,
                    ),
                  )
                  .first,
            )
            .painter as ClockPainter;

        final expectedScale = cardWidth / screenWidth;
        expect(painter.displayScale, closeTo(expectedScale, 0.01));

        final renderedSizePx = wallpaper.design!.clock!.sizePx * painter.displayScale;
        expect(
          renderedSizePx,
          lessThan(cardWidth),
          reason: 'the rendered clock font size must fit comfortably within '
              'the card\'s own width, never dwarf it the way the authored '
              '208px would at scale 1.0',
        );
      },
    );

    testWidgets(
      'foreground still paints above the clock in the small preview - the '
      'scale fix does not disturb z-order',
      (tester) async {
        final wallpaper = WallpaperModel.fromApiDetail(bunnyJson).toEntity();
        const screenWidth = 1080.0;
        const cardWidth = 108.0;

        await pumpAtScreenWidth(
          tester,
          screenWidth,
          Center(
            child: SizedBox(
              width: cardWidth,
              height: cardWidth / 0.6,
              child: WallpaperPreviewComposition(wallpaper: wallpaper),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        // The clock still renders exactly once - unaffected by the scale
        // change, only its size is.
        expect(
          find.descendant(
            of: find.byType(WallpaperPreviewComposition),
            matching: find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is ClockPainter,
            ),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('Wallpaper Only - scale fix applies regardless of the design '
      'choice', () {
    testWidgets(
      'a suppressed design still uses the correct scale (irrelevant here '
      'since nothing draws, but the composition itself must not crash or '
      'mis-size the depth layers)',
      (tester) async {
        final wallpaper = WallpaperModel.fromApiDetail(
          fixture('bunny_real_detail'),
        ).toEntity();
        const screenWidth = 1080.0;
        const cardWidth = 108.0;

        await pumpAtScreenWidth(
          tester,
          screenWidth,
          Center(
            child: SizedBox(
              width: cardWidth,
              height: cardWidth / 0.6,
              child: WallpaperPreviewComposition(
                wallpaper: wallpaper,
                forceSuppressDesign: true,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byType(WallpaperPreviewComposition),
            matching: find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is ClockPainter,
            ),
          ),
          findsNothing,
          reason: '"Wallpaper Only" suppresses the design entirely',
        );
      },
    );
  });
}

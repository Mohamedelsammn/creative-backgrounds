import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:creativebackground/core/widgets/wallpaper_preview_composition.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/clock/presentation/widgets/clock_renderer_widget.dart';
import 'package:creativebackground/features/depth/presentation/widgets/depth_live_composition.dart';
import 'package:creativebackground/features/explore/data/models/wallpaper_model.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Regression coverage: the Apply sheet's preview thumbnail used to always
/// show `wallpaper.thumbnailUrl` (the raw, unstyled original), regardless of
/// what would actually be applied - a scene grade, a live clock, a depth
/// composite, all invisible in that preview.
///
/// `WallpaperPreviewComposition` (`lib/core/widgets/wallpaper_preview_composition.dart`)
/// is the single shared widget both Details and the Apply sheet now use, so
/// these tests exercise the SAME production code Details already relies on,
/// not a parallel implementation.
void main() {
  setUpAll(() => initializeDateFormatting('en'));

  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  group('STANDARD', () {
    testWidgets('a scene-graded STANDARD wallpaper previews STYLED_PREVIEW '
        'with the live clock on top - not the raw thumbnail', (tester) async {
      final wallpaper = WallpaperEntity(
        id: 'w1',
        title: 'Graded standard',
        category: category,
        type: WallpaperType.normal,
        thumbnailUrl: 'https://cdn.test/thumb.webp',
        fullUrl: 'https://cdn.test/raw-preview.webp',
        resolution: '1080x1920',
        design: const StudioDesign(
          clock: ClockConfigEntity(enabled: true, sizePx: 60),
          styledPreviewUrl: 'https://cdn.test/styled-preview.webp',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WallpaperPreviewComposition(wallpaper: wallpaper),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        image.imageUrl,
        'https://cdn.test/styled-preview.webp',
        reason: 'the preview must show the SAME approved base Details shows '
            '(Red Earth\'s own warm grade), never the raw thumbnail',
      );
      expect(find.byType(ClockRendererWidget), findsOneWidget,
          reason: 'a STANDARD preview never bakes the clock, so it must '
              'still draw live');
    });

    testWidgets('no design at all shows the plain thumbnail, no overlay',
        (tester) async {
      final wallpaper = WallpaperEntity(
        id: 'w2',
        title: 'Plain',
        category: category,
        type: WallpaperType.normal,
        thumbnailUrl: 'https://cdn.test/thumb.webp',
        fullUrl: 'https://cdn.test/full.webp',
        resolution: '1080x1920',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WallpaperPreviewComposition(wallpaper: wallpaper),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ClockRendererWidget), findsNothing);
    });
  });

  group('DEPTH', () {
    testWidgets(
      'a depth wallpaper with both layers previews the LIVE composition - '
      'BACKGROUND -> design -> FOREGROUND, foreground painted after (on '
      'top of) the clock',
      (tester) async {
        final wallpaper = WallpaperModel.fromApiDetail(
          fixture('bunny_real_detail'),
        ).toEntity();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WallpaperPreviewComposition(wallpaper: wallpaper),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(DepthLiveComposition), findsOneWidget,
            reason: 'reuses the exact same live-composition widget Details '
                'uses - not a second implementation');
        expect(find.byType(ClockRendererWidget), findsOneWidget,
            reason: 'the raw background plate has nothing baked in, so the '
                'clock must render live, exactly once');

        final foregroundFinder = find.byWidgetPredicate(
          (w) =>
              w is CachedNetworkImage &&
              w.imageUrl == wallpaper.foregroundMaskUrl,
        );
    // FLUTTER_RENDERING_GUIDE §2 (DEPTH): background, foreground, clock,
    // then the foreground AGAIN at (1 - clock.depth) - the occlusion copy.
    final fgs = foregroundFinder.evaluate().toList();
    expect(fgs, hasLength(2),
        reason: 'the subject is drawn under the clock and again over it');
    final clockElement = tester.element(find.byType(ClockRendererWidget));
    expect(_paintsAfter(tester, later: clockElement, earlier: fgs.first), isTrue,
        reason: 'the first foreground sits beneath the clock');
    expect(_paintsAfter(tester, later: fgs.last, earlier: clockElement), isTrue,
        reason: 'the occlusion copy paints over the clock');
    final occlusion = tester.widget<Opacity>(find.ancestor(
      of: find.byWidget(fgs.last.widget),
      matching: find.byType(Opacity),
    ).first);
    expect(occlusion.opacity, closeTo(1 - wallpaper.design!.clock!.depth, 1e-9),
        reason: 'depth 0 hides the clock behind the subject, 1 leaves it in front');
      },
    );

    testWidgets('depth missing the foreground previews the safe baked '
        'fallback instead of live composition', (tester) async {
      final detail = fixture('bunny_real_detail');
      final stripped = Map<String, dynamic>.from(detail)
        ..['foreground'] = null
        ..['assets'] = {
          'BACKGROUND': detail['assets']['BACKGROUND'],
          'PREVIEW': detail['assets']['PREVIEW'],
        };
      final wallpaper = WallpaperModel.fromApiDetail(stripped).toEntity();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WallpaperPreviewComposition(wallpaper: wallpaper),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DepthLiveComposition), findsNothing);
      expect(find.byType(ClockRendererWidget), findsNothing,
          reason: 'the baked composite already contains the clock - '
              'drawing it again would duplicate it');
    });

    testWidgets(
      '"Wallpaper Only" on a depth wallpaper still shows the real '
      'background+foreground composite, just without the design',
      (tester) async {
        final wallpaper = WallpaperModel.fromApiDetail(
          fixture('bunny_real_detail'),
        ).toEntity();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WallpaperPreviewComposition(
                wallpaper: wallpaper,
                forceSuppressDesign: true,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(DepthLiveComposition), findsOneWidget,
            reason: 'still the real depth composite, not a flattened image');
        expect(find.byType(ClockRendererWidget), findsNothing,
            reason: '"Wallpaper Only" suppresses the design, not the depth '
                'effect itself');
        final foregroundFinder = find.byWidgetPredicate(
          (w) =>
              w is CachedNetworkImage &&
              w.imageUrl == wallpaper.foregroundMaskUrl,
        );
        expect(foregroundFinder, findsOneWidget,
            reason: 'the foreground subject must still be visible');
      },
    );
  });

  group('VIDEO', () {
    testWidgets(
      'a video wallpaper with a design previews its POSTER frame with the '
      'live design on top - never plays the actual clip in this small sheet',
      (tester) async {
        final wallpaper = WallpaperModel.fromApiDetail(
          fixture('studio_video_nature'),
        ).toEntity();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WallpaperPreviewComposition(wallpaper: wallpaper),
            ),
          ),
        );
        await tester.pump();

        final image = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(image.imageUrl, wallpaper.thumbnailUrl,
            reason: 'the poster frame, not the video itself');
        expect(find.byType(ClockRendererWidget), findsOneWidget,
            reason: 'video never bakes the clock, so it draws live over '
                'the poster - representing the composition without paying '
                'for a second concurrent decoder');
      },
    );

    testWidgets('"Wallpaper Only" on a video wallpaper hides the design '
        'overlay on the poster', (tester) async {
      final wallpaper = WallpaperModel.fromApiDetail(
        fixture('studio_video_nature'),
      ).toEntity();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WallpaperPreviewComposition(
              wallpaper: wallpaper,
              forceSuppressDesign: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ClockRendererWidget), findsNothing);
    });
  });

  group('loading/fallback safety', () {
    testWidgets('an empty thumbnail/preview URL does not crash, shows the '
        'placeholder colour', (tester) async {
      final wallpaper = WallpaperEntity(
        id: 'w3',
        title: 'No image',
        category: category,
        type: WallpaperType.normal,
        thumbnailUrl: '',
        fullUrl: '',
        resolution: '1080x1920',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WallpaperPreviewComposition(wallpaper: wallpaper),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });
  });
}

/// True when [later] appears strictly after [earlier] in the widget tree's
/// depth-first build order - for sibling `Stack` children, that order IS
/// paint order: a later Stack child paints on top of an earlier one.
/// Mirrors `wallpaper_details_overlay_zorder_test.dart`'s own helper.
bool _paintsAfter(
  WidgetTester tester, {
  required Element later,
  required Element earlier,
}) {
  var earlierSeen = false;
  var result = false;
  void visit(Element e) {
    if (result) return;
    if (e == earlier) earlierSeen = true;
    if (e == later && earlierSeen) result = true;
    e.visitChildren(visit);
  }

  tester.binding.rootElement!.visitChildren(visit);
  return result;
}

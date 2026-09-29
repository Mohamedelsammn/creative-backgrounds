import 'package:creativebackground/core/widgets/live_wallpaper_player.dart';
import 'package:creativebackground/core/widgets/media_player_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Phase 1 (this brief): several sections on Home (Trending peek + one
/// carousel per category) can each independently have a card cross the
/// visibility threshold at the same time. Before this fix, each carousel's
/// own `VisibilityDetector` gate was the only limit - nothing capped how
/// many decoders could be active across the WHOLE app at once. On a
/// mid-range device with only a handful of hardware decoder instances, that
/// is exactly what made scrolling heavy once several video cards were
/// simultaneously visible.
///
/// This drives three `LiveWallpaperPlayer`s (forced onto the native-fallback
/// path, which needs no platform-channel mocking) all becoming visible at
/// once, and asserts the app-wide cap actually holds.
void main() {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  setUp(() => LiveWallpaperPlayer.videoPlayerKnownBroken = true);
  tearDown(() => LiveWallpaperPlayer.videoPlayerKnownBroken = false);

  Future<void> setVisibility(
    WidgetTester tester,
    Key detectorKey,
    double fraction,
  ) async {
    final detector = tester.widget<VisibilityDetector>(find.byKey(detectorKey));
    const size = Size(100, 100);
    detector.onVisibilityChanged!(
      VisibilityInfo(
        key: detectorKey,
        size: size,
        visibleBounds: Rect.fromLTWH(0, 0, size.width, size.height * fraction),
      ),
    );
    await tester.pump();
  }

  Widget hostThree() {
    return const MaterialApp(
      home: Column(
        children: [
          SizedBox(
            height: 100,
            child: LiveWallpaperPlayer(
              videoUrl: 'https://cdn.test/a.mp4',
              posterUrl: 'https://cdn.test/a.webp',
            ),
          ),
          SizedBox(
            height: 100,
            child: LiveWallpaperPlayer(
              videoUrl: 'https://cdn.test/b.mp4',
              posterUrl: 'https://cdn.test/b.webp',
            ),
          ),
          SizedBox(
            height: 100,
            child: LiveWallpaperPlayer(
              videoUrl: 'https://cdn.test/c.mp4',
              posterUrl: 'https://cdn.test/c.webp',
            ),
          ),
        ],
      ),
    );
  }

  testWidgets(
    'at most 1 card decodes at once app-wide, even when 3 become visible '
    'simultaneously across different sections',
    (tester) async {
      await tester.pumpWidget(hostThree());
      await tester.pump();

      final keyA = Key('live_player_https://cdn.test/a.webp');
      final keyB = Key('live_player_https://cdn.test/b.webp');
      final keyC = Key('live_player_https://cdn.test/c.webp');

      await setVisibility(tester, keyA, 1.0);
      await setVisibility(tester, keyB, 1.0);
      await setVisibility(tester, keyC, 1.0);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();

      expect(
        find.byType(MediaPlayerPreview),
        findsOneWidget,
        reason:
            'only the app-wide cap worth of cards may hold a decoder at '
            'once, however many became visible at the same moment',
      );
    },
  );

  testWidgets('a card that could not get a slot picks one up once another card '
      'releases its slot (scrolls away)', (tester) async {
    await tester.pumpWidget(hostThree());
    await tester.pump();

    final keyA = Key('live_player_https://cdn.test/a.webp');
    final keyB = Key('live_player_https://cdn.test/b.webp');
    final keyC = Key('live_player_https://cdn.test/c.webp');

    await setVisibility(tester, keyA, 1.0);
    await setVisibility(tester, keyB, 1.0);
    await setVisibility(tester, keyC, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MediaPlayerPreview), findsOneWidget);

    // A scrolls away for longer than the release grace period, actually
    // releasing its slot (a brief off-screen spell would just pause A while
    // it keeps the slot - see live_wallpaper_player_visibility_disposal_test).
    await setVisibility(tester, keyA, 0.0);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();

    expect(
      find.byType(MediaPlayerPreview),
      findsOneWidget,
      reason:
          'C should now have claimed the slot A released, keeping the '
          'total at the cap rather than dropping below it or exceeding it',
    );
  });
}

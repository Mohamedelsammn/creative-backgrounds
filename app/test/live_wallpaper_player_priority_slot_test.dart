import 'package:creativebackground/core/widgets/live_wallpaper_player.dart';
import 'package:creativebackground/core/widgets/media_player_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Phase 5 (this brief): the Wallpaper Details screen's video must not sit
/// queued behind Home's background cards for the app-wide decoder slot cap.
/// `VisibilityDetector`'s 500ms throttle can leave a Home card reporting
/// itself as still visible for a short window after a route transition has
/// already covered it - without priority, Details' video would wait in the
/// same FIFO queue behind decoders nobody is actually watching anymore.
///
/// `priority: true` (used only by Details) makes a card evict the oldest
/// slot holder immediately instead of waiting, and an evicted card that is
/// still genuinely visible rejoins the waiter queue so it is not left
/// stranded on its poster once a slot frees up again.
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

  testWidgets(
    'a priority player evicts the oldest holder immediately instead of '
    'queuing when the cap is already full',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
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
                  videoUrl: 'https://cdn.test/details.mp4',
                  posterUrl: 'https://cdn.test/details.webp',
                  priority: true,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      final keyA = Key('live_player_https://cdn.test/a.webp');
      final keyB = Key('live_player_https://cdn.test/b.webp');
      final keyDetails = Key('live_player_https://cdn.test/details.webp');

      // A regular Home card takes the one conservative decoder slot first.
      await setVisibility(tester, keyA, 1.0);
      await setVisibility(tester, keyB, 1.0);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();
      expect(find.byType(MediaPlayerPreview), findsOneWidget);

      // The priority card becomes visible while the cap is already full.
      await setVisibility(tester, keyDetails, 1.0);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();

      // It must be playing NOW, not queued - the priority card replaces the
      // one ordinary holder rather than increasing the decoder cap.
      expect(
        find.byType(MediaPlayerPreview),
        findsOneWidget,
        reason:
            'the cap itself is unchanged - eviction swaps who holds a '
            'slot, it does not raise the limit',
      );

      final detailsIsPlaying = tester
          .widgetList<MediaPlayerPreview>(find.byType(MediaPlayerPreview))
          .any((w) => w.videoUrl.contains('details'));
      expect(
        detailsIsPlaying,
        isTrue,
        reason:
            'the priority player must be playing immediately, not '
            'waiting in the FIFO queue behind cards that may simply not '
            'have reported their own invisibility yet',
      );
    },
  );

  testWidgets(
    'an evicted card that is still visible rejoins the queue and resumes '
    'once a slot frees up again',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
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
                  videoUrl: 'https://cdn.test/details.mp4',
                  posterUrl: 'https://cdn.test/details.webp',
                  priority: true,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      final keyA = Key('live_player_https://cdn.test/a.webp');
      final keyB = Key('live_player_https://cdn.test/b.webp');
      final keyDetails = Key('live_player_https://cdn.test/details.webp');

      await setVisibility(tester, keyA, 1.0);
      await setVisibility(tester, keyB, 1.0);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();

      // Priority eviction takes A's (the oldest holder's) slot, but A is
      // still "visible" the whole time (this test never tells it otherwise).
      await setVisibility(tester, keyDetails, 1.0);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();

      // B was waiting, not decoding, so remove it from the waiter queue before
      // Details releases the one slot back to A. Outlast the release grace
      // period so B's own (never-started) eligibility fully clears.
      await setVisibility(tester, keyB, 0.0);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();
      await tester.pump();

      await setVisibility(tester, keyDetails, 0.0);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();

      // A, evicted earlier but still visible, must have reclaimed the slot B
      // just freed rather than being left stranded on its poster forever.
      final aIsPlaying = tester
          .widgetList<MediaPlayerPreview>(find.byType(MediaPlayerPreview))
          .any((w) => w.videoUrl.contains('/a.mp4'));
      expect(
        aIsPlaying,
        isTrue,
        reason:
            'an evicted-but-still-visible card must resume once a slot '
            'is available again, not sit on its poster indefinitely',
      );
    },
  );
}

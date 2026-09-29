import 'package:creativebackground/core/widgets/live_wallpaper_player.dart';
import 'package:creativebackground/core/widgets/live_preview_playback_gate.dart';
import 'package:creativebackground/core/widgets/media_player_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Decoder-churn fix: a video card that scrolls off-screen (or is paused by
/// the feed's scroll gate) must NOT immediately tear down its active
/// playback resource - it pauses and keeps the decoder/native view retained
/// for a grace period (`_releaseGraceDuration`, 1000ms), so a quick
/// direction reversal resumes the SAME resource instead of paying a fresh
/// `MediaCodec.configure()`/native-view-recreate cost. Only once the grace
/// period elapses with the card still ineligible does the resource actually
/// release; a genuine off-screen/paused spell that outlasts the grace period
/// must still fully release, so the leak this used to be a regression test
/// for is still covered - just after the grace window rather than
/// immediately.
///
/// This drives the native-fallback path specifically (`_fellBackToNative`),
/// since it needs no real decoder/platform channel to exercise - unlike the
/// `video_player` path, which would require mocking
/// `VideoPlayerPlatform.instance` for a footprint disproportionate to what
/// this test needs to prove.
void main() {
  // VisibilityDetector normally batches notifications on a periodic timer;
  // a widget test drives visibility explicitly, and a pending timer at test
  // teardown would otherwise fail the test on its own.
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  // Force the known-broken flag so every attempt skips straight to the
  // native fallback - deterministic across CI, and exercises exactly the
  // path this device-observed bug lives on.
  setUp(() => LiveWallpaperPlayer.videoPlayerKnownBroken = true);
  tearDown(() => LiveWallpaperPlayer.videoPlayerKnownBroken = false);

  Future<void> setVisibility(WidgetTester tester, double fraction) async {
    // VisibilityDetector's own controller normally drives this from real
    // layout; in a widget test the update method is invoked directly with a
    // synthetic bounds/size pair matching the requested visible fraction.
    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );
    const size = Size(100, 100);
    final visibleHeight = size.height * fraction;
    detector.onVisibilityChanged!(
      VisibilityInfo(
        key: detector.key!,
        size: size,
        visibleBounds: Rect.fromLTWH(0, 0, size.width, visibleHeight),
      ),
    );
    await tester.pump();
  }

  testWidgets(
      'going invisible for longer than the release grace period unmounts '
      'the native MediaPlayerPreview fallback rather than leaving it '
      'decoding off-screen indefinitely', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LiveWallpaperPlayer(
          videoUrl: 'https://cdn.test/clip.mp4',
          posterUrl: 'https://cdn.test/poster.webp',
        ),
      ),
    );
    await tester.pump();

    await setVisibility(tester, 1.0);
    // Settle the resume debounce, then let the async resolve/fallback chain
    // complete.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();

    expect(
      find.byType(MediaPlayerPreview),
      findsOneWidget,
      reason:
          'the known-broken flag forces the native fallback while '
          'visible',
    );

    await setVisibility(tester, 0.0);
    // Within the grace period, the resource must still be retained.
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byType(MediaPlayerPreview),
      findsOneWidget,
      reason:
          'a brief off-screen spell within the release grace period must '
          'keep the retained resource alive so a quick reversal can reuse it',
    );

    // Grace period elapses with the card still off-screen.
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byType(MediaPlayerPreview),
      findsNothing,
      reason:
          'once the grace period elapses while still off-screen, the '
          'native platform view must be unmounted (torn down), not left '
          'running indefinitely',
    );
  });

  testWidgets(
      'a feed scroll gate pauses playback but retains the decoder through '
      'the grace period, resuming once scrolling has settled', (tester) async {
    final gate = LivePreviewPlaybackGate();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveWallpaperPlayer(
          videoUrl: 'https://cdn.test/clip.mp4',
          posterUrl: 'https://cdn.test/poster.webp',
          playbackGate: gate,
        ),
      ),
    );
    await tester.pump();

    await setVisibility(tester, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MediaPlayerPreview), findsOneWidget);

    gate.pause();
    await tester.pump();
    // Still within the grace period - the retained native view stays
    // mounted (see class docs: it has no real pause primitive, so staying
    // mounted through the grace window is the intended tradeoff).
    expect(find.byType(MediaPlayerPreview), findsOneWidget);

    gate.resume();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(MediaPlayerPreview), findsOneWidget);
    gate.dispose();
  });

  testWidgets('becoming visible again restarts native playback without needing '
      'resolveVideoUrl to be called a second time', (tester) async {
    var resolveCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LiveWallpaperPlayer(
          resolveVideoUrl: () async {
            resolveCalls++;
            return 'https://cdn.test/clip.mp4';
          },
          posterUrl: 'https://cdn.test/poster.webp',
        ),
      ),
    );
    await tester.pump();

    await setVisibility(tester, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MediaPlayerPreview), findsOneWidget);
    expect(resolveCalls, 1);

    await setVisibility(tester, 0.0);
    // Outlast the release grace period so the resource actually tears down.
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.byType(MediaPlayerPreview), findsNothing);

    await setVisibility(tester, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();

    expect(
      find.byType(MediaPlayerPreview),
      findsOneWidget,
      reason: 'must restart from the remembered URL on return to view',
    );
    expect(
      resolveCalls,
      1,
      reason: 'the already-resolved URL must be reused, not re-fetched',
    );
  });
}

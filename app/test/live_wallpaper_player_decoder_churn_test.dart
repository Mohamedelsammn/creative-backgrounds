import 'dart:async';

import 'package:creativebackground/core/widgets/live_preview_playback_gate.dart';
import 'package:creativebackground/core/widgets/live_wallpaper_player.dart';
import 'package:creativebackground/core/widgets/media_player_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Decoder-churn fix: rapid scroll-direction reversal on Home used to cause
/// repeated live-preview decoder teardown/reinitialization
/// (`MediaCodec.configure()` -> `start()` -> `release()` in a tight loop),
/// because the scroll gate pausing playback was treated identically to
/// fully disposing the decoder. These tests cover the two-level state
/// machine (playback state vs. resource lifetime) that fixes it: pausing
/// keeps the resource retained for a grace period, and only a release that
/// outlasts the grace period (or a genuine app-background/dispose) actually
/// tears the resource down.
void main() {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  setUp(() => LiveWallpaperPlayer.videoPlayerKnownBroken = true);
  tearDown(() => LiveWallpaperPlayer.videoPlayerKnownBroken = false);

  Future<void> setVisibility(WidgetTester tester, double fraction) async {
    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );
    const size = Size(100, 100);
    detector.onVisibilityChanged!(VisibilityInfo(
      key: detector.key!,
      size: size,
      visibleBounds: Rect.fromLTWH(0, 0, size.width, size.height * fraction),
    ));
    await tester.pump();
  }

  testWidgets(
      'scroll gate pause does not immediately dispose the retained resource',
      (tester) async {
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

    // Immediately after pausing (a scroll starting), the resource must
    // still exist - it is paused, not disposed. The visual layer for the
    // native fallback stays mounted through the grace period (see class
    // docs), which is exactly what "not disposed" looks like for that path.
    expect(
      find.byType(MediaPlayerPreview),
      findsOneWidget,
      reason: 'a scroll-start pause must not immediately tear down the '
          'decoder/native view - only a release that outlasts the grace '
          'period does that',
    );
    gate.dispose();
  });

  testWidgets(
      'a quick scroll-direction reversal within the grace period reuses the '
      'same resource instead of re-initializing', (tester) async {
    final gate = LivePreviewPlaybackGate();
    var resolveCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LiveWallpaperPlayer(
          resolveVideoUrl: () async {
            resolveCalls++;
            return 'https://cdn.test/clip.mp4';
          },
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
    expect(resolveCalls, 1);

    // Simulate several quick direction reversals, each well within the
    // ~1000ms release grace period.
    for (var i = 0; i < 3; i++) {
      gate.pause();
      await tester.pump(const Duration(milliseconds: 100));
      gate.resume();
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(
      resolveCalls,
      1,
      reason: 'a quick reversal must resume the already-retained resource, '
          'never re-resolve/re-initialize a fresh one',
    );
  });

  testWidgets(
      'release only happens after the grace period elapses while still '
      'ineligible', (tester) async {
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
    // Just under the grace period - still retained.
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byType(MediaPlayerPreview), findsOneWidget);

    // Now past it.
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byType(MediaPlayerPreview),
      findsNothing,
      reason: 'ineligibility that outlasts the grace period must release '
          'the resource',
    );
    gate.dispose();
  });

  testWidgets(
      'eligibility returning before the grace timer fires cancels the '
      'pending release', (tester) async {
    final gate = LivePreviewPlaybackGate();
    var resolveCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LiveWallpaperPlayer(
          resolveVideoUrl: () async {
            resolveCalls++;
            return 'https://cdn.test/clip.mp4';
          },
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
    expect(resolveCalls, 1);

    gate.pause();
    await tester.pump(const Duration(milliseconds: 950));
    // Resume just before the 1000ms release timer would have fired.
    gate.resume();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    // Let any (incorrectly still-pending) release timer's original deadline
    // pass, to prove it was actually cancelled rather than merely racing.
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byType(MediaPlayerPreview),
      findsOneWidget,
      reason: 'resuming before the release timer fires must cancel it, '
          'leaving the resource intact',
    );
    expect(resolveCalls, 1, reason: 'no re-initialization should have run');
  });

  testWidgets(
      'going off-screen beyond the grace period eventually releases the '
      'resource', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MediaPlayerPreview), findsOneWidget);

    await setVisibility(tester, 0.0);
    await tester.pump(const Duration(milliseconds: 1100));

    expect(find.byType(MediaPlayerPreview), findsNothing);
  });

  testWidgets(
      'the app entering background releases the resource immediately, '
      'bypassing the grace period', (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
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
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MediaPlayerPreview), findsOneWidget);

    // The engine itself does not schedule/draw frames while the app is
    // paused (by design - there is nothing on screen to draw), so the
    // widget's own setState-triggered rebuild only becomes visible once a
    // frame actually runs, which happens on resume. What matters here is
    // that the underlying resource was actually released THE MOMENT the app
    // backgrounded, not deferred behind any grace-period timer - proven by
    // resuming immediately afterwards (well within what would have been the
    // grace window) and confirming a fresh initialization is required, i.e.
    // the resource is genuinely gone rather than merely paused-and-retained.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(
      find.byType(MediaPlayerPreview),
      findsNothing,
      reason: 'app backgrounding must release the active resource '
          'promptly - the grace period is only for brief foreground '
          'scroll gestures, so resuming immediately after must not find a '
          'still-retained decoder',
    );
  });

  testWidgets(
      'a stale async initialization that completes after eligibility '
      'changed does not start playback or steal the slot', (tester) async {
    final resolveCompleter = Completer<String?>();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveWallpaperPlayer(
          resolveVideoUrl: () => resolveCompleter.future,
          posterUrl: 'https://cdn.test/poster.webp',
        ),
      ),
    );
    await tester.pump();

    await setVisibility(tester, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    // Goes ineligible (off-screen) and stays that way long enough to
    // actually release, while the resolve is still in flight.
    await setVisibility(tester, 0.0);
    await tester.pump(const Duration(milliseconds: 1100));

    // The stale resolve now completes.
    resolveCompleter.complete('https://cdn.test/clip.mp4');
    await tester.pump();
    await tester.pump();

    expect(
      find.byType(MediaPlayerPreview),
      findsNothing,
      reason: 'a late-completing stale initialization must not start '
          'playback for a card that is no longer eligible',
    );
  });

  testWidgets(
      'deferUntil delays initialization until it resolves, keeping only the '
      'poster visible in the meantime - used by Details to wait for its '
      'route transition to finish', (tester) async {
    final gateFuture = Completer<void>();
    var resolveCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LiveWallpaperPlayer(
          resolveVideoUrl: () async {
            resolveCalls++;
            return 'https://cdn.test/clip.mp4';
          },
          posterUrl: 'https://cdn.test/poster.webp',
          priority: true,
          deferUntil: gateFuture.future,
        ),
      ),
    );
    await tester.pump();
    await setVisibility(tester, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();

    expect(
      resolveCalls,
      0,
      reason: 'initialization must not start before deferUntil resolves, '
          'even though the card is visible and eligible',
    );
    expect(find.byType(MediaPlayerPreview), findsNothing);

    // The route transition "completes".
    gateFuture.complete();
    await tester.pump();
    await tester.pump();

    expect(
      resolveCalls,
      1,
      reason: 'initialization proceeds once deferUntil resolves',
    );
    expect(find.byType(MediaPlayerPreview), findsOneWidget);
  });

  testWidgets(
      'only one decoder is retained at a time even across paused-but-held '
      'cards', (tester) async {
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
          ],
        ),
      ),
    );
    await tester.pump();

    final keyA = Key('live_player_https://cdn.test/a.webp');
    final keyB = Key('live_player_https://cdn.test/b.webp');
    Future<void> setKeyVisibility(Key key, double fraction) async {
      final detector = tester.widget<VisibilityDetector>(find.byKey(key));
      const size = Size(100, 100);
      detector.onVisibilityChanged!(VisibilityInfo(
        key: key,
        size: size,
        visibleBounds: Rect.fromLTWH(0, 0, size.width, size.height * fraction),
      ));
      await tester.pump();
    }

    await setKeyVisibility(keyA, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MediaPlayerPreview), findsOneWidget);

    // A is paused (still holding its slot, mid-grace-period) while B
    // becomes visible - B must not get a second concurrent decoder.
    await setKeyVisibility(keyA, 0.0);
    await setKeyVisibility(keyB, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();

    expect(
      find.byType(MediaPlayerPreview),
      findsOneWidget,
      reason: 'at most one decoder may be retained at once, even with '
          'another card paused mid-grace-period',
    );
  });
}

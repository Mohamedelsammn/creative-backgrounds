import 'package:creativebackground/core/widgets/live_wallpaper_player.dart';
import 'package:creativebackground/core/widgets/media_player_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Regression test for "setState() or markNeedsBuild() called when widget
/// tree was locked" on `LiveWallpaperPlayer`.
///
/// Root cause: `_ActiveVideoRegistry.release()` (called from a disposing
/// card's `State.dispose()`) and `_ActiveVideoRegistry.acquirePriority()`
/// (called from a newly-visible priority card's `_ensureInitialised`, itself
/// reachable during another widget's build) both used to invoke another
/// holder's callback SYNCHRONOUSLY - and that callback ends in `setState()`.
/// `dispose()` and `build()` can both run while Flutter's element tree is
/// locked (mid-rebuild, tearing down a replaced subtree), so a synchronous
/// `setState()` on a DIFFERENT, still-mounted widget triggered from inside
/// that window throws exactly this error. Both call sites now defer the
/// evicted/waiting holder's callback to the next frame via
/// `WidgetsBinding.instance.addPostFrameCallback`.
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
    detector.onVisibilityChanged!(VisibilityInfo(
      key: detectorKey,
      size: size,
      visibleBounds: Rect.fromLTWH(0, 0, size.width, size.height * fraction),
    ));
    await tester.pump();
  }

  testWidgets(
      'replacing a holder card with a brand-new widget tree in the same '
      'frame (disposing the old holder while the new tree builds) does not '
      'throw "widget tree was locked"', (tester) async {
    Widget buildTree({required bool showA}) {
      return MaterialApp(
        home: Column(
          children: [
            if (showA)
              const SizedBox(
                height: 100,
                child: LiveWallpaperPlayer(
                  videoUrl: 'https://cdn.test/a.mp4',
                  posterUrl: 'https://cdn.test/a.webp',
                ),
              ),
            const SizedBox(
              height: 100,
              child: LiveWallpaperPlayer(
                videoUrl: 'https://cdn.test/b.mp4',
                posterUrl: 'https://cdn.test/b.webp',
              ),
            ),
          ],
        ),
      );
    }

    await tester.pumpWidget(buildTree(showA: true));
    await tester.pump();

    final keyA = Key('live_player_https://cdn.test/a.webp');
    final keyB = Key('live_player_https://cdn.test/b.webp');
    await setVisibility(tester, keyA, 1.0);
    await setVisibility(tester, keyB, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MediaPlayerPreview), findsOneWidget,
        reason: 'the replacement lifecycle test must respect the production '
            'one-decoder cap');

    // Removing A from the tree disposes its State mid-rebuild - exactly the
    // "framework locked" window release()'s waiter notification must not
    // synchronously setState() into during this same pumpWidget call.
    await tester.pumpWidget(buildTree(showA: false));

    expect(tester.takeException(), isNull);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a priority card evicting a holder while it first builds does not '
      'throw "widget tree was locked" even under a fresh pumpWidget',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
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
    ));
    await tester.pump();

    final keyA = Key('live_player_https://cdn.test/a.webp');
    final keyB = Key('live_player_https://cdn.test/b.webp');
    await setVisibility(tester, keyA, 1.0);
    await setVisibility(tester, keyB, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MediaPlayerPreview), findsOneWidget,
        reason: 'the priority lifecycle test must respect the production '
            'one-decoder cap');

    // Mount a brand-new priority card (Details opening) in the SAME
    // pumpWidget call that also keeps A/B around - this is the shape that
    // used to trigger a synchronous eviction -> setState() while the new
    // tree's build was still in progress.
    await tester.pumpWidget(const MaterialApp(
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
    ));
    expect(tester.takeException(), isNull);

    final keyDetails = Key('live_player_https://cdn.test/details.webp');
    await setVisibility(tester, keyDetails, 1.0);
    expect(tester.takeException(), isNull);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

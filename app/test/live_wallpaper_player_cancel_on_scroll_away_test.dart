import 'dart:async';

import 'package:creativebackground/core/widgets/live_wallpaper_player.dart';
import 'package:creativebackground/core/widgets/media_player_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Phase 2 (this brief): "cancel video preparation when the card leaves the
/// viewport" - not just pause/dispose whatever already started, but actually
/// abandon an in-flight resolve/prepare instead of letting it complete and
/// start playback for a card nobody is looking at anymore.
///
/// A card can go invisible while `resolveVideoUrl()` (a real network call in
/// production) is still awaited. Before this fix, that call would complete
/// after the card scrolled away and still set `_fallbackUrl`/mount the
/// native preview - decoding a clip for a card with nothing on screen.
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
      'a card that scrolls away while resolveVideoUrl is still in flight '
      'never mounts the native preview once that call finally resolves',
      (tester) async {
    final resolveCompleter = Completer<String?>();

    await tester.pumpWidget(MaterialApp(
      home: LiveWallpaperPlayer(
        resolveVideoUrl: () => resolveCompleter.future,
        posterUrl: 'https://cdn.test/poster.webp',
      ),
    ));
    await tester.pump();

    // Becomes visible; the resume debounce settles and kicks off
    // resolveVideoUrl() - which does not complete yet.
    await setVisibility(tester, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    // Scrolls away before the network call returns.
    await setVisibility(tester, 0.0);
    await tester.pump();

    // The slow network call finally resolves, long after the card left.
    resolveCompleter.complete('https://cdn.test/clip.mp4');
    await tester.pump();
    await tester.pump();

    expect(find.byType(MediaPlayerPreview), findsNothing,
        reason: 'a resolve that completes after the card scrolled away must '
            'not start playback for a card nobody is looking at');
  });

  testWidgets(
      'if the card becomes visible again before the stale resolve completes, '
      'the LATEST visible spell still gets to play once resolved',
      (tester) async {
    final resolveCompleter = Completer<String?>();
    var resolveCalls = 0;

    await tester.pumpWidget(MaterialApp(
      home: LiveWallpaperPlayer(
        resolveVideoUrl: () {
          resolveCalls++;
          return resolveCompleter.future;
        },
        posterUrl: 'https://cdn.test/poster.webp',
      ),
    ));
    await tester.pump();

    await setVisibility(tester, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await setVisibility(tester, 0.0);
    await tester.pump();
    // Comes back into view before the first resolve ever completes - well
    // within the release grace period, so the same in-flight attempt is
    // still relevant (this is a resolve delay, not a torn-down resource).
    await setVisibility(tester, 1.0);
    await tester.pump();

    resolveCompleter.complete('https://cdn.test/clip.mp4');
    await tester.pump();
    await tester.pump();

    expect(find.byType(MediaPlayerPreview), findsOneWidget,
        reason: 'the card is visible again by the time the URL resolved, so '
            'playback should still start');
    expect(resolveCalls, greaterThanOrEqualTo(1));
  });
}

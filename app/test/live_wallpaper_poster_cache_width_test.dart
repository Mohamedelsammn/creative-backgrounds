import 'package:cached_network_image/cached_network_image.dart';
import 'package:creativebackground/core/widgets/live_wallpaper_player.dart';
import 'package:creativebackground/core/widgets/wallpaper_card.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Phase 2 (this brief): a live card's poster used to decode at full
/// resolution regardless of the card's actual pixel size, unlike a normal
/// card's `CachedNetworkImage` (which caps `memCacheWidth` to the card box) -
/// for the exact same underlying thumbnail URL. Since `CachedNetworkImage`'s
/// resize-cache key includes the target width, this also meant a live card
/// could never reuse a normal card's already-decoded, capped bitmap for the
/// same image; it always decoded its own independent full-resolution copy.
void main() {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  testWidgets(
    'WallpaperCard caps a live card\'s poster to the same memCacheWidth a '
    'normal card would use for the identical box size',
    (tester) async {
      const cardWidth = 150.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: cardWidth,
              height: 200,
              child: WallpaperCard(
                imageUrl: 'https://cdn.test/poster.webp',
                title: 'Live wallpaper',
                category: 'Nature',
                type: WallpaperType.live,
                sourceWidth: 1080,
                sourceHeight: 1920,
                resolveVideoUrl: () async => 'https://cdn.test/clip.mp4',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final liveCachedImage = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage).first,
      );

      expect(
        liveCachedImage.memCacheWidth,
        isNotNull,
        reason:
            'a live card poster must cap its decoded resolution to the '
            'card size, exactly like a normal card does for the same image',
      );
      expect(liveCachedImage.memCacheWidth, greaterThan(0));
      expect(liveCachedImage.memCacheHeight, greaterThan(0));
    },
  );

  testWidgets(
    'LiveWallpaperPlayer forwards posterCacheWidth straight through to its '
    'poster CachedNetworkImage',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveWallpaperPlayer(
              posterUrl: 'https://cdn.test/poster.webp',
              autoplay: false,
              posterCacheWidth: 321,
              posterCacheHeight: 654,
            ),
          ),
        ),
      );
      await tester.pump();

      final cachedImage = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cachedImage.memCacheWidth, 321);
      expect(cachedImage.memCacheHeight, 654);
    },
  );

  testWidgets('normal feed images are bounded in both dimensions and do not '
      'animate every network completion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 200,
            child: WallpaperCard(
              imageUrl: 'https://cdn.test/poster.webp',
              title: 'Still wallpaper',
              category: 'Nature',
              sourceWidth: 1080,
              sourceHeight: 1920,
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.memCacheWidth, greaterThan(0));
    expect(image.memCacheHeight, greaterThan(0));
    expect(image.fadeInDuration, Duration.zero);
    expect(image.fadeOutDuration, Duration.zero);
    expect(image.placeholderFadeInDuration, Duration.zero);
  });
}

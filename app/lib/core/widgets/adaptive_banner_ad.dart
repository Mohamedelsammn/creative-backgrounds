import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/adaptive_banner_manager.dart';

/// Displays the banner [manager] owns, reactively.
///
/// Reserves one standard banner slot while the native ad surface loads. This
/// keeps an asynchronous banner arrival from shifting the feed beneath a
/// scrolling finger, then swaps in the surface only after it is ready.
///
/// Height comes ONLY from [AdaptiveBannerManager.adSize] - the adaptive size
/// AdMob returned for this device/orientation - deliberately not wrapped in
/// Expanded/Flexible/AspectRatio or anything else that could stretch it
/// taller than that.
class AdaptiveBannerAd extends StatelessWidget {
  const AdaptiveBannerAd({super.key, required this.manager});

  final AdaptiveBannerManager manager;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdSize?>(
      valueListenable: manager.size,
      builder: (context, adSize, _) => ValueListenableBuilder<bool>(
        valueListenable: manager.loaded,
        builder: (context, isLoaded, _) {
          final ad = manager.ad;
          // `adSize` is null only for the very first banner slot of the
          // session, before any manager has ever resolved a real adaptive
          // height for this device - every later slot's manager reserves the
          // cached real height from its very first frame (see
          // AdaptiveBannerManager's `_cachedHeightByWidth`), so this
          // fallback to the generic 50dp `AdSize.banner` height is now only
          // ever a same-session, once-only placeholder rather than something
          // every single slot momentarily shows and then visibly grows out
          // of, which is what previously shifted the whole feed below it.
          final height = (adSize?.height ?? AdSize.banner.height).toDouble();
          final child = !isLoaded || ad == null || adSize == null
              ? const SizedBox.expand()
              : RepaintBoundary(
                  // Isolate native-driven ad repaints from the scroll content.
                  child: AdWidget(ad: ad),
                );
          return SizedBox(width: double.infinity, height: height, child: child);
        },
      ),
    );
  }
}

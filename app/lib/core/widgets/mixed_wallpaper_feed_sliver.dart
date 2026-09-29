import 'package:flutter/material.dart';

import '../../features/explore/domain/entities/wallpaper_entity.dart';
import '../../injection.dart';
import '../../features/explore/domain/usecases/resolve_video_url_usecase.dart';
import '../ads/adaptive_banner_manager.dart';
import '../l10n/l10n.dart';
import '../theme/app_spacing.dart';
import 'adaptive_banner_ad.dart';
import 'live_preview_playback_gate.dart';
import 'wallpaper_card.dart';

/// Fixed portrait aspect ratio every Home/Category-Details wallpaper card
/// uses - a strict uniform grid, never a masonry/staggered layout where
/// cards vary in height by source image aspect ratio.
///
/// 9:16 - the same ratio the backend's own source wallpapers are actually
/// authored at (2160x3840, 1080x1920 - confirmed in the API/fixture data).
/// The previous 0.72 read as too short/square for portrait phone wallpaper
/// assets; matching the real source ratio makes a card visually communicate
/// "this is a phone wallpaper" rather than an arbitrary rectangle.
const double kWallpaperCardAspectRatio = 9 / 16;

/// Builds the slivers for one continuous, ad-interleaved, paginated mixed
/// wallpaper feed (normal + depth + live together) - Explore's "New
/// Wallpapers" section, and (via the same function) Category Details.
///
/// An ad is inserted after every [adInterval]th wallpaper, counted globally
/// across pages (position 6, 12, 18, ... regardless of which API page a
/// given item came from) - not reset per page. [bannerManagerAt] lets the
/// caller keep one [AdaptiveBannerManager] per slot for the widget's whole
/// lifetime, the same pattern already used for Explore's other banners, so a
/// scroll-driven rebuild never tears down and reloads an already-loaded ad.
///
/// ## Stable sliver identity across pagination
///
/// Every group's grid sliver and every ad's adapter carries a [Key] derived
/// from its slot number (`grid_group_N` / `mixed_feed_ad_slot_N`), not its
/// position in the returned list. Earlier groups/ads never change once
/// emitted - appending a page only ever adds a new trailing group (and,
/// where a group that was previously the last, partial one just became
/// full, one new ad slot immediately after it). Keying by slot number
/// means Flutter's element reconciliation matches every already-laid-out
/// sliver to itself again by identity, never by re-guessing position, so an
/// insertion earlier in a longer list can never be mistaken for a change to
/// a sliver the user has already scrolled past.
List<Widget> buildMixedWallpaperFeedSlivers(
  BuildContext context, {
  required List<WallpaperEntity> wallpapers,
  required bool hasMore,
  required bool isLoadingMore,
  required void Function(WallpaperEntity wallpaper, String heroTag) onTap,
  String? adUnitId,
  AdaptiveBannerManager Function(int slot, String adUnitId)? bannerManagerAt,
  LivePreviewPlaybackGate? livePreviewPlaybackGate,
  String heroPrefix = 'explore',
  EdgeInsets padding = const EdgeInsets.symmetric(
    horizontal: AppSpacing.screenH,
  ),
  int adInterval = 6,
}) {
  assert(
    adUnitId == null || bannerManagerAt != null,
    'bannerManagerAt is required whenever adUnitId is provided',
  );
  final slivers = <Widget>[];
  final insertsAds = adUnitId != null && bannerManagerAt != null;

  // Without ads there is nothing to interleave, so the whole feed is ONE
  // grid. Splitting it into groups of `adInterval` regardless (which this
  // used to do) meant every group re-applied `padding` - including its
  // VERTICAL padding - so a caller passing a bottom inset to clear a
  // persistent banner got that inset repeated in the middle of the feed:
  // the large empty band Category Details showed after wallpaper #6. Home is
  // unaffected either way, since it passes horizontal-only padding, and its
  // ad path below is untouched.
  if (!insertsAds) {
    slivers.add(
      SliverPadding(
        key: const ValueKey('grid_group_0'),
        padding: padding,
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.grid,
            crossAxisSpacing: AppSpacing.grid,
            childAspectRatio: kWallpaperCardAspectRatio,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _card(
              context,
              wallpaper: wallpapers[index],
              heroPrefix: heroPrefix,
              livePreviewPlaybackGate: livePreviewPlaybackGate,
              onTap: onTap,
            ),
            childCount: wallpapers.length,
            findChildIndexCallback: (key) {
              final valueKey = key as ValueKey<String>;
              final id = valueKey.value.replaceFirst('wallpaper_', '');
              final index = wallpapers.indexWhere((w) => w.id == id);
              return index == -1 ? null : index;
            },
          ),
        ),
      ),
    );
    if (isLoadingMore) slivers.add(_loadingMoreSliver());
    return slivers;
  }

  var groupStart = 0;
  var groupIndex = 0;
  var adSlot = 0;
  while (groupStart < wallpapers.length) {
    final groupEnd = (groupStart + adInterval).clamp(0, wallpapers.length);
    final group = wallpapers.sublist(groupStart, groupEnd);
    final thisGroupIndex = groupIndex++;
    slivers.add(
      SliverPadding(
        key: ValueKey('grid_group_$thisGroupIndex'),
        padding: padding,
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.grid,
            crossAxisSpacing: AppSpacing.grid,
            childAspectRatio: kWallpaperCardAspectRatio,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _card(
              context,
              wallpaper: group[index],
              heroPrefix: heroPrefix,
              livePreviewPlaybackGate: livePreviewPlaybackGate,
              onTap: onTap,
            ),
            childCount: group.length,
            findChildIndexCallback: (key) {
              final valueKey = key as ValueKey<String>;
              final id = valueKey.value.replaceFirst('wallpaper_', '');
              final index = group.indexWhere((w) => w.id == id);
              return index == -1 ? null : index;
            },
          ),
        ),
      ),
    );

    // Only insert an ad after a FULL group of `adInterval` items - a trailing
    // partial group (the last page, or the very end of the catalog) never
    // gets an ad appended after it.
    if (group.length == adInterval && groupEnd < wallpapers.length) {
      final slot = adSlot++;
      final manager = bannerManagerAt(slot, adUnitId);
      slivers.add(
        SliverToBoxAdapter(
          key: ValueKey('mixed_feed_ad_slot_$slot'),
          child: Padding(
            // Symmetric section gap both above AND below the banner - it
            // previously had none below, so the next group's grid sat flush
            // against the banner while the gap above it looked intentional.
            // `AdaptiveBannerAd` always reserves its fixed height even while
            // loading/on failure (see its own doc), so this vertical rhythm
            // never collapses or stacks with anything else - the grid slivers
            // on either side apply no vertical padding of their own.
            padding: EdgeInsets.fromLTRB(
              padding.left,
              AppSpacing.section,
              padding.right,
              AppSpacing.section,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                manager.load(constraints.maxWidth.truncate());
                return AdaptiveBannerAd(manager: manager);
              },
            ),
          ),
        ),
      );
    }
    groupStart = groupEnd;
  }

  if (isLoadingMore) slivers.add(_loadingMoreSliver());

  return slivers;
}

/// One wallpaper cell. Shared by the ad-free single-grid path and the
/// ad-interleaved grouped path so both render identical cards.
Widget _card(
  BuildContext context, {
  required WallpaperEntity wallpaper,
  required String heroPrefix,
  required LivePreviewPlaybackGate? livePreviewPlaybackGate,
  required void Function(WallpaperEntity wallpaper, String heroTag) onTap,
}) {
  final heroTag = '${heroPrefix}_${wallpaper.id}';
  return WallpaperCard(
    key: ValueKey('wallpaper_${wallpaper.id}'),
    imageUrl: wallpaper.thumbnailUrl,
    title: wallpaper.title,
    category: wallpaper.category.displayName(context.languageCode),
    placeholderColor: wallpaper.dominantColor == null
        ? null
        : Color(wallpaper.dominantColor!),
    type: wallpaper.type,
    resolveVideoUrl: () => sl<ResolveVideoUrlUseCase>()(wallpaper),
    isPremium: wallpaper.isPremium,
    livePreviewPlaybackGate: livePreviewPlaybackGate,
    sourceWidth: wallpaper.width,
    sourceHeight: wallpaper.height,
    onTap: () => onTap(wallpaper, heroTag),
  );
}

Widget _loadingMoreSliver() => const SliverToBoxAdapter(
      key: ValueKey('mixed_feed_loading_more'),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );

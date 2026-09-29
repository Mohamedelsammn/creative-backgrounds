import 'package:flutter/material.dart';

import '../../features/explore/domain/entities/wallpaper_entity.dart';
import '../ads/adaptive_banner_manager.dart';
import '../theme/app_spacing.dart';
import 'live_preview_playback_gate.dart';
import 'mixed_wallpaper_feed_sliver.dart';

/// Reusable 2-column UNIFORM wallpaper grid with infinite scroll - every
/// card has the exact same portrait dimensions (see
/// [kWallpaperCardAspectRatio]), never a masonry/staggered layout. Shared by
/// Search and Category Details. Triggers [onLoadMore] when scrolled within
/// 400px of the bottom.
///
/// Internally reuses [buildMixedWallpaperFeedSlivers] - the same grid+ad
/// sliver composition Explore uses - so all four wallpaper-listing surfaces
/// (Explore, Category Details, Favorites, Search) render from one
/// implementation rather than duplicated grid/ad logic. Pass [adUnitId] +
/// [bannerManagerAt] to enable the same "ad after every 6 wallpapers" policy
/// Explore already has; omit both to render a plain ad-free grid (Search,
/// Favorites).
class WallpaperGrid extends StatefulWidget {
  const WallpaperGrid({
    super.key,
    required this.wallpapers,
    required this.onTap,
    required this.heroPrefix,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.screenH,
      8,
      AppSpacing.screenH,
      120,
    ),
    this.adUnitId,
    this.bannerManagerAt,
    this.livePreviewPlaybackGate,
  });

  final List<WallpaperEntity> wallpapers;
  final void Function(WallpaperEntity wallpaper, String heroTag) onTap;
  final String heroPrefix;
  final bool hasMore;

  /// True while a next-page request is already in flight - shows the
  /// trailing loading indicator without implying [hasMore] changed.
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final EdgeInsets padding;

  /// Enables the "ad after every 6 wallpapers" policy when both this and
  /// [bannerManagerAt] are provided - omit both for an ad-free grid.
  final String? adUnitId;
  final AdaptiveBannerManager Function(int slot, String adUnitId)?
      bannerManagerAt;

  final LivePreviewPlaybackGate? livePreviewPlaybackGate;

  @override
  State<WallpaperGrid> createState() => _WallpaperGridState();
}

class _WallpaperGridState extends State<WallpaperGrid> {
  final ScrollController _controller = ScrollController();

  // Guards against firing load-more repeatedly for the same page: only fires
  // again once the item count grows (i.e. the previous page arrived).
  int _requestedAt = -1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!widget.hasMore || widget.onLoadMore == null) return;
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 400) {
      if (widget.wallpapers.length != _requestedAt) {
        _requestedAt = widget.wallpapers.length;
        widget.onLoadMore!();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _controller,
      slivers: buildMixedWallpaperFeedSlivers(
        context,
        wallpapers: widget.wallpapers,
        hasMore: widget.hasMore,
        isLoadingMore: widget.isLoadingMore,
        onTap: widget.onTap,
        adUnitId: widget.adUnitId,
        bannerManagerAt: widget.bannerManagerAt,
        livePreviewPlaybackGate: widget.livePreviewPlaybackGate,
        heroPrefix: widget.heroPrefix,
        padding: widget.padding,
      ),
    );
  }
}

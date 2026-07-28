import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../features/explore/domain/entities/wallpaper_entity.dart';
import '../theme/app_spacing.dart';
import 'wallpaper_card.dart';

/// Reusable 2-column masonry grid with infinite scroll. Shared by Search and
/// View All. Triggers [onLoadMore] when scrolled within 400px of the bottom.
class WallpaperGrid extends StatefulWidget {
  const WallpaperGrid({
    super.key,
    required this.wallpapers,
    required this.onTap,
    required this.heroPrefix,
    this.hasMore = false,
    this.onLoadMore,
    this.padding = const EdgeInsets.fromLTRB(
        AppSpacing.screenH, 8, AppSpacing.screenH, 120),
  });

  final List<WallpaperEntity> wallpapers;
  final void Function(WallpaperEntity wallpaper, String heroTag) onTap;
  final String heroPrefix;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final EdgeInsets padding;

  @override
  State<WallpaperGrid> createState() => _WallpaperGridState();
}

class _WallpaperGridState extends State<WallpaperGrid> {
  final ScrollController _controller = ScrollController();
  static const _aspectRatios = [0.72, 0.9, 0.82, 0.68];

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
      slivers: [
        SliverPadding(
          padding: widget.padding,
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.grid,
            crossAxisSpacing: AppSpacing.grid,
            childCount: widget.wallpapers.length,
            itemBuilder: (context, index) {
              final wallpaper = widget.wallpapers[index];
              final heroTag = '${widget.heroPrefix}_${wallpaper.id}';
              return AspectRatio(
                aspectRatio: _aspectRatios[index % _aspectRatios.length],
                child: WallpaperCard(
                  imageUrl: wallpaper.thumbnailUrl,
                  title: wallpaper.title,
                  category: wallpaper.category.name,
                  isPremium: wallpaper.isPremium,
                  heroTag: heroTag,
                  onTap: () => widget.onTap(wallpaper, heroTag),
                ),
              );
            },
          ),
        ),
        if (widget.hasMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

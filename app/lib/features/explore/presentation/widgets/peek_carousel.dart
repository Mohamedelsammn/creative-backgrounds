import 'package:flutter/material.dart';

import '../../../../core/theme/app_shapes.dart';
import '../../../../core/widgets/wallpaper_card.dart';
import '../../domain/entities/wallpaper_entity.dart';

/// Horizontal snap carousel with peek (partial neighbours) and a centered card
/// scaled up relative to its neighbours. Shared by Trending and Latest.
class PeekCarousel extends StatefulWidget {
  const PeekCarousel({
    super.key,
    required this.wallpapers,
    required this.onTap,
    this.height,
    this.heroPrefix = 'wallpaper_hero',
    this.viewportFraction = 0.78,
  });

  final List<WallpaperEntity> wallpapers;

  /// Fixed height override. When null, the height is derived responsively from
  /// the viewport so cards never overflow on small screens (320dp) yet stay
  /// generous on large ones (up to ~800dp).
  final double? height;
  final void Function(WallpaperEntity wallpaper, String heroTag) onTap;
  final String heroPrefix;
  final double viewportFraction;

  /// Responsive card-strip height: portrait card sized from the visible card
  /// width, clamped so it fits the screen height with room for the header.
  static double resolveHeight(BuildContext context, double viewportFraction) {
    final size = MediaQuery.sizeOf(context);
    final cardWidth = size.width * viewportFraction - 12; // minus card padding
    final byWidth = cardWidth * 1.55; // portrait ~2:3
    return byWidth.clamp(300.0, size.height * 0.55);
  }

  @override
  State<PeekCarousel> createState() => _PeekCarouselState();
}

class _PeekCarouselState extends State<PeekCarousel> {
  late final int _count = widget.wallpapers.length;
  late final bool _loop = _count > 1;

  // Start on a large base page so there is a peek card on both sides and the
  // list can scroll continuously in either direction (infinite looping).
  late final int _initialPage = _loop ? _count * 1000 : 0;

  late final PageController _controller = PageController(
    viewportFraction: widget.viewportFraction,
    initialPage: _initialPage,
  );
  late double _page = _initialPage.toDouble();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    setState(() => _page = _controller.page ?? _page);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.height ??
        PeekCarousel.resolveHeight(context, widget.viewportFraction);
    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: _controller,
        padEnds: true,
        itemCount: _loop ? null : _count,
        itemBuilder: (context, index) {
          final wallpaper = widget.wallpapers[index % _count];
          final heroTag = '${widget.heroPrefix}_${wallpaper.id}';
          final distance = (_page - index).abs().clamp(0.0, 1.0);
          final scale = 1 - (distance * 0.11);
          return Transform.scale(
            scale: scale,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: WallpaperCard(
                imageUrl: wallpaper.thumbnailUrl,
                title: wallpaper.title,
                category: wallpaper.category.name,
                isPremium: wallpaper.isPremium,
                heroTag: heroTag,
                borderRadius: AppShapes.cardLarge,
                onTap: () => widget.onTap(wallpaper, heroTag),
              ),
            ),
          );
        },
      ),
    );
  }
}

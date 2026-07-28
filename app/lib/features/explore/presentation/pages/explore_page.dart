import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../../core/widgets/nav_visibility.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../injection.dart';
import '../../../transparent_wallpaper/presentation/widgets/transparent_feature_card.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../bloc/explore_bloc.dart';
import '../widgets/category_carousel.dart';
import '../widgets/greeting_header.dart';
import '../widgets/latest_carousel.dart';
import '../widgets/peek_carousel.dart';
import '../widgets/trending_carousel.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ExploreBloc>()..add(const ExploreStarted()),
      child: const _ExploreView(),
    );
  }
}

class _ExploreView extends StatefulWidget {
  const _ExploreView();

  @override
  State<_ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<_ExploreView> {
  final ScrollController _scroll = ScrollController();
  NavVisibilityController? _nav;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Bottom nav is always visible (no scroll gating).
    _nav = NavVisibility.maybeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _nav?.show());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openDetails(WallpaperEntity w, String heroTag) {
    // Warm the full-res image into the cache before navigating so Details can
    // show it without a black flash or spinner. Fire-and-forget.
    precacheImage(CachedNetworkImageProvider(w.fullUrl), context);
    context.push(RouteNames.wallpaperDetailsPath(w.id), extra: heroTag);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          final bloc = context.read<ExploreBloc>();
          bloc.add(const ExploreRefreshRequested());
          // Complete when a terminal state arrives; fall back after a short
          // window so the indicator never hangs if the refreshed state is
          // identical (flutter_bloc suppresses duplicate emissions).
          await bloc.stream
              .firstWhere((s) => s is ExploreLoaded || s is ExploreError)
              .timeout(const Duration(seconds: 1), onTimeout: () => bloc.state);
        },
        child: BlocBuilder<ExploreBloc, ExploreState>(
          builder: (context, state) {
            return CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Greeting fades out as the list scrolls up.
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _scroll,
                    builder: (context, child) {
                      final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                      final opacity = (1 - offset / 90).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: opacity,
                        child: IgnorePointer(ignoring: opacity < 0.1, child: child),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(
                          AppSpacing.screenH, 8, AppSpacing.screenH, 16),
                      child: GreetingHeader(),
                    ),
                  ),
                ),
                // Search bar pins to the top and floats.
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedSearchHeader(
                    onTap: () => context.push(RouteNames.search),
                  ),
                ),
                ..._buildStateSlivers(context, state),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildStateSlivers(BuildContext context, ExploreState state) {
    switch (state) {
      case ExploreLoading():
      case ExploreInitial():
        return [_loadingSliver(context)];
      case ExploreError(:final message):
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorView(
              message: message,
              onRetry: () =>
                  context.read<ExploreBloc>().add(const ExploreStarted()),
            ),
          ),
        ];
      case ExploreLoaded(:final trending, :final latest, :final categories):
        return _loadedSlivers(context, trending, latest, categories);
    }
  }

  Widget _loadingSliver(BuildContext context) {
    final carouselH = PeekCarousel.resolveHeight(context, 0.72);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LoadingShimmer(height: 20, width: 120, borderRadius: BorderRadius.circular(6)),
            const SizedBox(height: 16),
            LoadingShimmer(height: carouselH),
            const SizedBox(height: 28),
            LoadingShimmer(height: 20, width: 120, borderRadius: BorderRadius.circular(6)),
            const SizedBox(height: 16),
            LoadingShimmer(height: carouselH),
          ],
        ),
      ),
    );
  }

  List<Widget> _loadedSlivers(
    BuildContext context,
    List<WallpaperEntity> trending,
    List<WallpaperEntity> latest,
    List<CategoryEntity> categories,
  ) {
    // Group loaded wallpapers by category for the dynamic category sections.
    final pool = <String, WallpaperEntity>{};
    for (final w in [...trending, ...latest]) {
      pool[w.id] = w;
    }
    final byCategory = <String, List<WallpaperEntity>>{};
    for (final w in pool.values) {
      byCategory.putIfAbsent(w.category.id, () => []).add(w);
    }

    return [
      // Special Features — flagship transparent (live-camera) wallpaper.
      _sectionHeaderSliver(context.l10n.specialFeatures, null),
      const SliverToBoxAdapter(child: TransparentFeatureCard()),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.section)),
      if (trending.isNotEmpty) ...[
        _sectionHeaderSliver(context.l10n.trending,
            () => context.push(RouteNames.viewAllPath('trending'))),
        SliverToBoxAdapter(
          child: TrendingCarousel(wallpapers: trending, onTap: _openDetails),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.section)),
      ],
      if (latest.isNotEmpty) ...[
        _sectionHeaderSliver(context.l10n.latest,
            () => context.push(RouteNames.viewAllPath('latest'))),
        SliverToBoxAdapter(
          child: LatestCarousel(wallpapers: latest, onTap: _openDetails),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.section)),
      ],
      for (final category in categories)
        if ((byCategory[category.id] ?? const []).isNotEmpty) ...[
          SliverToBoxAdapter(
            child: CategoryCarousel(
              categoryName: category.name,
              wallpapers: byCategory[category.id]!,
              onViewAll: () =>
                  context.push(RouteNames.viewAllPath(category.id)),
              onTapWallpaper: _openDetails,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.section)),
        ],
    ];
  }

  Widget _sectionHeaderSliver(String title, VoidCallback? onViewAll) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH, 0, AppSpacing.screenH, 12),
        child: SectionHeader(title: title, onViewAll: onViewAll),
      ),
    );
  }
}

/// Pinned header hosting the floating search bar; keeps it at the top once the
/// greeting has scrolled away.
class _PinnedSearchHeader extends SliverPersistentHeaderDelegate {
  _PinnedSearchHeader({required this.onTap});

  final VoidCallback onTap;

  static const double _height = 84;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Transparent background: only the floating white pill remains over the
    // wallpaper content (no white header rectangle). Extra top padding lowers
    // the bar for better spacing from the status bar.
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 20, AppSpacing.screenH, 12),
      child: AppSearchBar(onTap: onTap),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedSearchHeader oldDelegate) => false;
}

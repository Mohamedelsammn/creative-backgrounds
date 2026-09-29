import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent, ScrollDirection;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/ad_constants.dart';
import '../../../../core/ads/adaptive_banner_manager.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../../core/widgets/live_preview_playback_gate.dart';
import '../../../../core/widgets/mixed_wallpaper_feed_sliver.dart';
import '../../../../core/widgets/nav_visibility.dart';
import '../../../../injection.dart';
import '../../../transparent_wallpaper/presentation/widgets/transparent_feature_card.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../bloc/explore_bloc.dart';
import '../widgets/greeting_header.dart';

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

class _ExploreViewState extends State<_ExploreView>
    with WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();
  final LivePreviewPlaybackGate _livePreviewGate = LivePreviewPlaybackGate();
  Timer? _resumeLivePreviewTimer;
  NavVisibilityController? _nav;

  // One banner manager per ad slot in the mixed feed, created lazily and kept
  // for the lifetime of this state (not per-build) so a scroll-driven rebuild
  // never tears down and reloads an already-loaded/loading banner.
  final List<AdaptiveBannerManager> _bannerManagers = [];

  // Guards against firing load-more repeatedly for the same page: only fires
  // again once the item count grows (i.e. the previous page arrived).
  int _requestedAt = -1;

  AdaptiveBannerManager _bannerManagerAt(int slot, String adUnitId) {
    while (_bannerManagers.length <= slot) {
      _bannerManagers.add(AdaptiveBannerManager(adUnitId));
    }
    return _bannerManagers[slot];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onLoadMoreScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Bottom nav is always visible (no scroll gating).
    _nav = NavVisibility.maybeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _nav?.show());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeLivePreviewTimer?.cancel();
    _livePreviewGate.dispose();
    _scroll.removeListener(_onLoadMoreScroll);
    _scroll.dispose();
    for (final manager in _bannerManagers) {
      manager.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeAfterScrollSettles();
    } else {
      _pauseLivePreviews();
    }
  }

  void _onLoadMoreScroll() {
    if (!_scroll.hasClients) return;
    final state = context.read<ExploreBloc>().state;
    if (state is! ExploreLoaded || !state.hasMore || state.isLoadingMore) {
      return;
    }
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      if (state.wallpapers.length != _requestedAt) {
        _requestedAt = state.wallpapers.length;
        context.read<ExploreBloc>().add(const ExploreLoadMoreRequested());
      }
    }
  }

  void _pauseLivePreviews() {
    _resumeLivePreviewTimer?.cancel();
    _livePreviewGate.pause();
  }

  void _resumeAfterScrollSettles() {
    _resumeLivePreviewTimer?.cancel();
    // Starting a decoder during the same frame as the final ballistic scroll
    // tick still causes visible contention on older devices. A short quiet
    // window makes the static poster the scrolling placeholder instead. This
    // is the playback-RESUME debounce only - distinct from (and much shorter
    // than) LiveWallpaperPlayer's own decoder-RELEASE grace period, which is
    // what actually keeps a paused decoder warm through a quick reversal.
    _resumeLivePreviewTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _livePreviewGate.resume();
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle)) {
      _pauseLivePreviews();
    } else if (notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle)) {
      _resumeAfterScrollSettles();
    }
    return false;
  }

  void _openDetails(WallpaperEntity w, String heroTag) {
    // Navigate first. The feed row's `fullUrl` is its thumbnail, and resolving
    // it again at intrinsic size here used to start a second decode/GPU upload
    // on the same frame as the route animation. Details owns its deliberately
    // delayed, screen-bounded preview load.
    context.push(RouteNames.wallpaperDetailsPath(w.id), extra: w);
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
            return NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: CustomScrollView(
                controller: _scroll,
                // Media-heavy sections must not initialise far below the
                // viewport. A small cache is enough to avoid scroll gaps.
                scrollCacheExtent: const ScrollCacheExtent.pixels(200),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Greeting fades out as the list scrolls up.
                  SliverToBoxAdapter(
                    child: AnimatedBuilder(
                      animation: _scroll,
                      builder: (context, child) {
                        final offset = _scroll.hasClients
                            ? _scroll.offset
                            : 0.0;
                        final opacity = (1 - offset / 90).clamp(0.0, 1.0);
                        return Opacity(
                          opacity: opacity,
                          child: IgnorePointer(
                            ignoring: opacity < 0.1,
                            child: child,
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.screenH,
                          8,
                          AppSpacing.screenH,
                          16,
                        ),
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
                  const SliverToBoxAdapter(child: TransparentFeatureCard()),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.section),
                  ),
                  _sectionTitleSliver(context.l10n.newWallpapers),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ..._buildStateSlivers(context, state),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
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
        return [_loadingSliver()];
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
      case ExploreLoaded(
        :final wallpapers,
        :final hasMore,
        :final isLoadingMore,
      ):
        return buildMixedWallpaperFeedSlivers(
          context,
          wallpapers: wallpapers,
          hasMore: hasMore,
          isLoadingMore: isLoadingMore,
          onTap: _openDetails,
          adUnitId: AdConstants.inFeedBannerAdUnitId,
          bannerManagerAt: _bannerManagerAt,
          livePreviewPlaybackGate: _livePreviewGate,
          heroPrefix: 'explore',
        );
    }
  }

  /// 2-column shimmer grid matching the mixed feed's own uniform card shape.
  Widget _loadingSliver() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.grid,
          crossAxisSpacing: AppSpacing.grid,
          childAspectRatio: kWallpaperCardAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const LoadingShimmer(),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _sectionTitleSliver(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: Text(title, style: AppTextStyles.sectionTitle),
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
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Transparent background: only the floating white pill remains over the
    // wallpaper content (no white header rectangle). Extra top padding lowers
    // the bar for better spacing from the status bar.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        20,
        AppSpacing.screenH,
        12,
      ),
      child: AppSearchBar(onTap: onTap),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedSearchHeader oldDelegate) => false;
}

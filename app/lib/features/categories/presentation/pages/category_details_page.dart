import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/ad_constants.dart';
import '../../../../core/ads/adaptive_banner_manager.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/adaptive_banner_ad.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/wallpaper_grid.dart';
import '../../../../injection.dart';
import '../../../explore/domain/entities/category_entity.dart';
import '../bloc/category_details_bloc.dart';
import '../widgets/category_grid_shimmer.dart';

/// Category Details: back + name + count header, then a continuous 2-column
/// paginated grid (normal/depth/live/PRO mixed), same [WallpaperGrid] used
/// everywhere else - explicit light-mode `Scaffold` so this route (pushed
/// outside `MainShell`, which is the only other place a `Scaffold`/`Material`
/// ancestor would otherwise come from) never falls back to a bare black
/// canvas with no `Material` ancestor.
///
/// Unlike Explore, this screen does NOT insert an ad every 6 wallpapers -
/// it has exactly ONE persistent banner anchored below the grid instead (see
/// [_CategoryDetailsViewState._bannerManager]), so scrolling never
/// encounters a giant blank gap or a duplicated ad slot.
class CategoryDetailsPage extends StatelessWidget {
  const CategoryDetailsPage({
    super.key,
    required this.slug,
    this.knownCategory,
  });

  final String slug;

  /// The category row the caller already has, when available (from the
  /// Categories tab) - lets the header paint the real name/count instantly
  /// instead of a generic placeholder while the first page loads.
  final CategoryEntity? knownCategory;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CategoryDetailsBloc>()
        ..add(CategoryDetailsFetchRequested(slug)),
      child: _CategoryDetailsView(slug: slug, knownCategory: knownCategory),
    );
  }
}

class _CategoryDetailsView extends StatefulWidget {
  const _CategoryDetailsView({required this.slug, this.knownCategory});

  final String slug;
  final CategoryEntity? knownCategory;

  @override
  State<_CategoryDetailsView> createState() => _CategoryDetailsViewState();
}

class _CategoryDetailsViewState extends State<_CategoryDetailsView> {
  // One banner for the whole screen's lifetime - never torn down/reloaded by
  // pagination or any other rebuild.
  late final AdaptiveBannerManager _bannerManager =
      AdaptiveBannerManager(AdConstants.bottomBannerAdUnitId);

  @override
  void dispose() {
    _bannerManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(category: widget.knownCategory, slug: widget.slug),
              Expanded(
                child: BlocBuilder<CategoryDetailsBloc, CategoryDetailsState>(
                  builder: (context, state) {
                    return switch (state) {
                      CategoryDetailsInitial() ||
                      CategoryDetailsLoading() =>
                        const CategoryGridShimmer(),
                      CategoryDetailsError(:final message) => ErrorView(
                          message: message,
                          onRetry: () => context
                              .read<CategoryDetailsBloc>()
                              .add(CategoryDetailsFetchRequested(widget.slug)),
                        ),
                      CategoryDetailsLoaded(
                        :final wallpapers,
                        :final hasMore,
                        :final isLoadingMore,
                      ) =>
                        // No adUnitId/bannerManagerAt here - Category Details
                        // never inserts an ad into the wallpaper list itself,
                        // unlike Explore. The single persistent banner below
                        // is the only ad on this screen.
                        WallpaperGrid(
                          wallpapers: wallpapers,
                          hasMore: hasMore,
                          isLoadingMore: isLoadingMore,
                          heroPrefix: 'category_${widget.slug}',
                          // Only normal grid spacing plus a small bottom
                          // inset. The persistent banner is a sibling BELOW
                          // this grid, not an overlay on top of it, so no
                          // room needs reserving for it here - the default
                          // 120px bottom inset (sized for Home's floating
                          // nav, which this pushed route does not have)
                          // would just read as dead space under the last row.
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenH,
                            0,
                            AppSpacing.screenH,
                            AppSpacing.md,
                          ),
                          onLoadMore: () => context
                              .read<CategoryDetailsBloc>()
                              .add(const CategoryDetailsLoadMoreRequested()),
                          onTap: (wallpaper, heroTag) => context.push(
                            RouteNames.wallpaperDetailsPath(wallpaper.id),
                            extra: wallpaper,
                          ),
                        ),
                    };
                  },
                ),
              ),
              // Persistent bottom banner - reserves exactly its own adaptive
              // height (see AdaptiveBannerAd's doc), so an unloaded ad never
              // opens up a large empty region, and a loaded one never covers
              // grid content since it sits below the Expanded grid, not on
              // top of it.
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                    vertical: AppSpacing.sm,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _bannerManager.load(constraints.maxWidth.truncate());
                      return AdaptiveBannerAd(manager: _bannerManager);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.category, required this.slug});

  final CategoryEntity? category;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final name = category?.displayName(context.languageCode) ?? slug;
    final count = category?.wallpaperCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        8,
        AppSpacing.screenH,
        12,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: InkWell(
              onTap: () => context.pop(),
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 22),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (count != null)
                  Text(
                    '$count ${context.l10n.wallpapers}',
                    style: AppTextStyles.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

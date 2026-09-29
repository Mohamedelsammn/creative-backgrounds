import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../../injection.dart';
import '../../../explore/domain/entities/category_entity.dart';
import '../../domain/live_category.dart';
import '../bloc/categories_bloc.dart';

/// The 8 categories this tab offers to browse by, regardless of what the
/// backend's `/categories` endpoint currently returns.
///
/// Deliberately just an allow-list of slugs now - a business rule kept
/// separate from cover art, which the dashboard is the sole source of now
/// (see [_CategoryCard]). A retired category (e.g. "Cities") or any future
/// one not yet added here is filtered out of the tab, not just visually
/// hidden. Existing wallpapers tagged with a filtered-out category are
/// unaffected - they still resolve normally wherever they're referenced by
/// id/slug directly (feed, search, favorites); this only concerns which
/// tiles this tab offers to browse by.
const Set<String> kApprovedCategorySlugs = {
  'nature',
  'amoled',
  'space',
  'cars',
  'anime',
  'minimal',
  'abstract',
  'animals',
};

/// Categories tab: one large horizontal card per category, matching the
/// approved UI (background image, name, wallpaper count, chevron).
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CategoriesBloc>()..add(const CategoriesStarted()),
      child: const _CategoriesView(),
    );
  }
}

class _CategoriesView extends StatelessWidget {
  const _CategoriesView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              8,
              AppSpacing.screenH,
              16,
            ),
            child: Text(context.l10n.categories, style: AppTextStyles.displayLarge),
          ),
          Expanded(
            child: BlocBuilder<CategoriesBloc, CategoriesState>(
              builder: (context, state) {
                return switch (state) {
                  CategoriesInitial() ||
                  CategoriesLoading() =>
                    _loadingList(),
                  CategoriesError(:final message) => ErrorView(
                      message: message,
                      onRetry: () => context
                          .read<CategoriesBloc>()
                          .add(const CategoriesStarted()),
                    ),
                  CategoriesLoaded(:final categories) =>
                    _CategoryList(categories: categories),
                };
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        120,
      ),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) => const LoadingShimmer(height: 120),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories});

  final List<CategoryEntity> categories;

  @override
  Widget build(BuildContext context) {
    // Only the 8 approved categories are ever selectable here, regardless
    // of what the backend currently returns - a retired category (e.g.
    // "Cities") or any future one not yet added to the approved set is
    // filtered out of the tab, not just visually hidden. Existing
    // wallpapers tagged with a filtered-out category are unaffected - they
    // still resolve normally wherever they're referenced by id/slug
    // directly (feed, search, favorites); this only concerns which tiles
    // this tab offers to browse by.
    final approved = this
        .categories
        .where((c) => kApprovedCategorySlugs.contains(c.slug))
        .toList();
    // The empty state still keys off the BACKEND categories - the live
    // pseudo-category below is always present, so including it here would
    // make "no categories yet" unreachable and hide a genuinely empty
    // /categories response.
    if (approved.isEmpty) {
      return const ErrorView(
        message: 'Check back soon.',
        headline: 'No categories yet',
        icon: Icons.category_outlined,
      );
    }
    final categories = <CategoryEntity>[
      // "Live Wallpapers" always leads, and is a client-side
      // pseudo-category rather than a backend row (see [LiveCategory]) - so
      // it is prepended here rather than being expected in the API response.
      LiveCategory.entity,
      ...approved,
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        120,
      ),
      itemCount: categories.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryCard(
          category: category,
          onTap: () => context.push(
            RouteNames.categoryDetailsPath(
              category.slug.isNotEmpty ? category.slug : category.id,
            ),
            extra: category,
          ),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final CategoryEntity category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = category.wallpaperCount;
    return Semantics(
      button: true,
      label: category.displayName(context.languageCode),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: AppShapes.cardLarge,
          child: SizedBox(
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CategoryCover(category: category),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  bottom: 16,
                  right: 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category.displayName(context.languageCode),
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (count != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$count ${context.l10n.wallpapers}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A category card's cover image.
///
/// The dashboard is the sole source of cover art now - no bundled asset map
/// exists to fall back to. [CategoryEntity.thumbnailUrl] (`coverThumbnailUrl`
/// on the public API) is fetched and cached through the app's normal
/// [CachedNetworkImage] pipeline, exactly like every wallpaper thumbnail
/// already is. `__live__`, the client-side pseudo-category (see
/// [LiveCategory]), has no backend row and therefore no `thumbnailUrl` at
/// all - it always falls through to the plain accent-colour block below,
/// same as any other category with a missing or broken URL.
class _CategoryCover extends StatelessWidget {
  const _CategoryCover({required this.category});

  final CategoryEntity category;

  /// A lightweight, non-image fallback: the API's own accent [color] when
  /// supplied, otherwise [AppColors.categoryAccents] keyed by the category's
  /// lowercased name, otherwise a plain surface tone. The name/count text
  /// stays legible over any of these, matching what a missing bundled asset
  /// used to render.
  Color get _fallbackColor {
    final apiColor = category.color;
    if (apiColor != null) return Color(apiColor);
    final accent = AppColors.categoryAccents[category.name.toLowerCase()];
    return accent ?? AppColors.surfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final url = category.thumbnailUrl;
    if (url == null || url.isEmpty) {
      return ColoredBox(color: _fallbackColor);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      // Sized to the card's own pixel footprint, not the source image's -
      // the same reasoning the bundled assets this replaces were cached at
      // (800px), so a full-resolution dashboard upload never sits in memory
      // at its original size for a 120dp-tall card.
      memCacheWidth: 800,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) => ColoredBox(color: _fallbackColor),
      // A missing or broken dashboard URL falls back to the same plain
      // colour block a category with no cover at all uses - never a
      // bundled image, per the dashboard-is-source-of-truth requirement.
      errorWidget: (context, url, error) => ColoredBox(color: _fallbackColor),
    );
  }
}

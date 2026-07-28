import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/wallpaper_card.dart';
import '../../../../injection.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../bloc/favorites_bloc.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<FavoritesBloc>()..add(const FavoritesFetchRequested()),
      child: const _FavoritesView(),
    );
  }
}

class _FavoritesView extends StatelessWidget {
  const _FavoritesView();

  // Varied heights for a staggered look.
  static const _aspectRatios = [0.72, 0.9, 0.85, 0.68];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: BlocBuilder<FavoritesBloc, FavoritesState>(
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, 16, AppSpacing.screenH, 16),
                  child: Text(context.l10n.favorites,
                      style: AppTextStyles.displayLarge),
                ),
              ),
              ..._buildBody(context, state),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context, FavoritesState state) {
    switch (state) {
      case FavoritesLoading():
      case FavoritesInitial():
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      case FavoritesEmpty():
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateView(
              headline: context.l10n.noFavorites,
              subtext: context.l10n.noFavoritesSubtitle,
            ),
          ),
        ];
      case FavoritesError(:final message):
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorView(
              message: message,
              onRetry: () => context
                  .read<FavoritesBloc>()
                  .add(const FavoritesFetchRequested()),
            ),
          ),
        ];
      case FavoritesLoaded(:final favorites):
        return [_grid(context, favorites)];
    }
  }

  Widget _grid(BuildContext context, List<WallpaperEntity> favorites) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.grid,
        crossAxisSpacing: AppSpacing.grid,
        childCount: favorites.length,
        itemBuilder: (context, index) {
          final wallpaper = favorites[index];
          return AspectRatio(
            aspectRatio: _aspectRatios[index % _aspectRatios.length],
            child: GestureDetector(
              onLongPress: () => _confirmRemove(context, wallpaper),
              child: WallpaperCard(
                imageUrl: wallpaper.thumbnailUrl,
                title: wallpaper.title,
                category: wallpaper.category.name,
                isPremium: wallpaper.isPremium,
                heroTag: 'fav_hero_${wallpaper.id}',
                onTap: () => context.push(
                  RouteNames.wallpaperDetailsPath(wallpaper.id),
                  extra: 'fav_hero_${wallpaper.id}',
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmRemove(BuildContext context, WallpaperEntity wallpaper) {
    final bloc = context.read<FavoritesBloc>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text('Remove "${wallpaper.title}" from favorites'),
              onTap: () {
                bloc.add(FavoriteRemovedRequested(wallpaper.id));
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

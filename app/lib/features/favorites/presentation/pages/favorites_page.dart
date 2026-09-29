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
import '../../../../core/widgets/frosted_icon_button.dart';
import '../../../../core/widgets/wallpaper_card.dart';
import '../../../../injection.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../bloc/favorites_bloc.dart';
import '../../../../features/explore/domain/usecases/resolve_video_url_usecase.dart';

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
          final header = Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              16,
              AppSpacing.screenH,
              16,
            ),
            child: Text(
              context.l10n.favorites,
              style: AppTextStyles.displayLarge,
            ),
          );

          // Loading/empty/error have no scrollable content of their own - a
          // CustomScrollView around them still permits an overscroll/bounce
          // gesture that springs back to nowhere, which is what read as
          // "the empty page is scrollable". A fixed, non-scrolling Column
          // instead keeps the header in place and centers the state body in
          // the remaining space, with nothing to drag.
          if (state case FavoritesLoaded(:final favorites)) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: header),
                _grid(context, favorites),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              Expanded(child: Center(child: _stateBody(context, state))),
            ],
          );
        },
      ),
    );
  }

  Widget _stateBody(BuildContext context, FavoritesState state) {
    switch (state) {
      case FavoritesLoading():
      case FavoritesInitial():
        return const CircularProgressIndicator();
      case FavoritesEmpty():
        return EmptyStateView(
          headline: context.l10n.noFavorites,
          subtext: context.l10n.noFavoritesSubtitle,
        );
      case FavoritesError(:final message):
        return ErrorView(
          message: message,
          onRetry: () => context.read<FavoritesBloc>().add(
            const FavoritesFetchRequested(),
          ),
        );
      case FavoritesLoaded():
        // Handled by the CustomScrollView branch above - never reached here.
        return const SizedBox.shrink();
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
            // Each card carries its own visible remove control. Tapping it
            // dispatches straight to the existing FavoritesBloc; removal is
            // reflected via the bloc's watch-stream re-fetch (see
            // FavoritesBloc's constructor), so this widget holds no favorite
            // state of its own - no risk of the icon and the list disagreeing.
            child: Stack(
              fit: StackFit.expand,
              children: [
                WallpaperCard(
                  imageUrl: wallpaper.thumbnailUrl,
                  title: wallpaper.title,
                  category: wallpaper.category.displayName(
                    context.languageCode,
                  ),
                  placeholderColor: wallpaper.dominantColor == null
                      ? null
                      : Color(wallpaper.dominantColor!),
                  type: wallpaper.type,
                  resolveVideoUrl: () =>
                      sl<ResolveVideoUrlUseCase>()(wallpaper),
                  isPremium: wallpaper.isPremium,
                  onTap: () => context.push(
                    RouteNames.wallpaperDetailsPath(wallpaper.id),
                    extra: wallpaper,
                  ),
                ),
                Positioned(
                  // True top-left, matching where users actually expect it -
                  // the vast majority of favorites are normal wallpapers
                  // with no other top-left badge, so it must not float lower
                  // "waiting" for a badge that isn't there. A favorited
                  // depth/live wallpaper (which does have a type badge in
                  // this same corner) is the rare case; a slight visual
                  // overlap there is preferable to this control looking
                  // wrong on every ordinary favorite.
                  top: 12,
                  left: 12,
                  child: FrostedIconButton(
                    icon: Icons.favorite,
                    iconColor: const Color(0xFFFF4D6D),
                    size: 32,
                    semanticLabel: context.l10n.removeFromFavorites,
                    onPressed: () => context.read<FavoritesBloc>().add(
                      FavoriteRemovedRequested(wallpaper.id),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

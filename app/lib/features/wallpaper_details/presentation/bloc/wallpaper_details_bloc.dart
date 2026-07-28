import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:share_plus/share_plus.dart';

import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../favorites/domain/usecases/add_favorite_usecase.dart';
import '../../../favorites/domain/usecases/remove_favorite_usecase.dart';
import '../../domain/usecases/get_wallpaper_details_usecase.dart';

part 'wallpaper_details_event.dart';
part 'wallpaper_details_state.dart';

class WallpaperDetailsBloc
    extends Bloc<WallpaperDetailsEvent, WallpaperDetailsState> {
  WallpaperDetailsBloc({
    required GetWallpaperDetailsUseCase getDetails,
    required AddFavoriteUseCase addFavorite,
    required RemoveFavoriteUseCase removeFavorite,
    required FavoritesRepository favoritesRepository,
  })  : _getDetails = getDetails,
        _addFavorite = addFavorite,
        _removeFavorite = removeFavorite,
        _favorites = favoritesRepository,
        super(const WallpaperDetailsLoading()) {
    on<WallpaperDetailsFetchRequested>(_onFetch);
    on<WallpaperFavoriteToggleRequested>(_onToggleFavorite);
    on<WallpaperShareRequested>(_onShare);
  }

  final GetWallpaperDetailsUseCase _getDetails;
  final AddFavoriteUseCase _addFavorite;
  final RemoveFavoriteUseCase _removeFavorite;
  final FavoritesRepository _favorites;

  Future<void> _onFetch(
    WallpaperDetailsFetchRequested event,
    Emitter<WallpaperDetailsState> emit,
  ) async {
    emit(const WallpaperDetailsLoading());
    final result = await _getDetails(event.id);
    result.fold(
      (failure) => emit(WallpaperDetailsError(failure.message)),
      (wallpaper) => emit(WallpaperDetailsLoaded(
        wallpaper: wallpaper,
        isFavorite: _favorites.isFavorite(wallpaper.id),
      )),
    );
  }

  Future<void> _onToggleFavorite(
    WallpaperFavoriteToggleRequested event,
    Emitter<WallpaperDetailsState> emit,
  ) async {
    final current = state;
    if (current is! WallpaperDetailsLoaded) return;

    final wasFavorite = current.isFavorite;
    // Optimistic update.
    emit(current.copyWith(isFavorite: !wasFavorite));

    final result = wasFavorite
        ? await _removeFavorite(current.wallpaper.id)
        : await _addFavorite(current.wallpaper);

    // Revert on failure.
    result.fold(
      (_) => emit(current.copyWith(isFavorite: wasFavorite)),
      (_) {},
    );
  }

  Future<void> _onShare(
    WallpaperShareRequested event,
    Emitter<WallpaperDetailsState> emit,
  ) async {
    final current = state;
    if (current is! WallpaperDetailsLoaded) return;
    final w = current.wallpaper;
    await Share.share('${w.title} — ${w.fullUrl}');
  }
}

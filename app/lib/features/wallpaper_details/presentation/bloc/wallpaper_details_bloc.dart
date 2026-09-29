import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:share_plus/share_plus.dart';

import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../favorites/domain/usecases/add_favorite_usecase.dart';
import '../../../favorites/domain/usecases/remove_favorite_usecase.dart';
import '../../domain/repositories/wallpaper_details_repository.dart';
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
    required WallpaperDetailsRepository repository,
  })  : _getDetails = getDetails,
        _repository = repository,
        _addFavorite = addFavorite,
        _removeFavorite = removeFavorite,
        _favorites = favoritesRepository,
        super(const WallpaperDetailsLoading()) {
    on<WallpaperDetailsFetchRequested>(_onFetch);
    on<WallpaperFavoriteToggleRequested>(_onToggleFavorite);
    on<WallpaperShareRequested>(_onShare);
  }

  final GetWallpaperDetailsUseCase _getDetails;
  final WallpaperDetailsRepository _repository;
  final AddFavoriteUseCase _addFavorite;
  final RemoveFavoriteUseCase _removeFavorite;
  final FavoritesRepository _favorites;

  Future<void> _onFetch(
    WallpaperDetailsFetchRequested event,
    Emitter<WallpaperDetailsState> emit,
  ) async {
    // Paint immediately with what the caller already knows (thumbnail,
    // title, category - everything a list row carries) instead of a loading
    // spinner, then silently upgrade to the full detail below. Skipped only
    // when nothing is known yet (e.g. a deep link straight to this id).
    final known = event.knownWallpaper;
    if (known != null) {
      emit(WallpaperDetailsLoaded(
        wallpaper: known,
        isFavorite: _favorites.isFavorite(known.id),
      ));
    } else {
      emit(const WallpaperDetailsLoading());
    }

    final result = await _getDetails(event.id);
    result.fold(
      (failure) {
        // A known wallpaper is already fully visible; a failed detail
        // refresh must not blank that screen out from under the user.
        if (known == null) emit(WallpaperDetailsError(failure.message));
      },
      (wallpaper) {
        emit(WallpaperDetailsLoaded(
          wallpaper: wallpaper,
          isFavorite: _favorites.isFavorite(wallpaper.id),
        ));
        // Analytics, deliberately not awaited: the screen is already usable
        // and a failed count must never surface to the user.
        unawaited(_repository.recordView(wallpaper.id));
      },
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

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/usecases/get_favorites_usecase.dart';
import '../../domain/usecases/remove_favorite_usecase.dart';

part 'favorites_event.dart';
part 'favorites_state.dart';

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  FavoritesBloc({
    required GetFavoritesUseCase getFavorites,
    required RemoveFavoriteUseCase removeFavorite,
    required FavoritesRepository repository,
  })  : _getFavorites = getFavorites,
        _removeFavorite = removeFavorite,
        _repository = repository,
        super(const FavoritesInitial()) {
    on<FavoritesFetchRequested>(_onFetch);
    on<FavoriteRemovedRequested>(_onRemove);

    // Live-sync: reload whenever the favorites store changes (e.g. toggled on
    // the Wallpaper Details screen).
    _subscription = _repository.watchChanges().listen(
          (_) => add(const FavoritesFetchRequested()),
        );
  }

  final GetFavoritesUseCase _getFavorites;
  final RemoveFavoriteUseCase _removeFavorite;
  final FavoritesRepository _repository;
  late final StreamSubscription<void> _subscription;

  Future<void> _onFetch(
    FavoritesFetchRequested event,
    Emitter<FavoritesState> emit,
  ) async {
    if (state is! FavoritesLoaded) emit(const FavoritesLoading());
    final result = await _getFavorites(const NoParams());
    result.fold(
      (failure) => emit(FavoritesError(failure.message)),
      (favorites) => emit(
        favorites.isEmpty
            ? const FavoritesEmpty()
            : FavoritesLoaded(favorites),
      ),
    );
  }

  Future<void> _onRemove(
    FavoriteRemovedRequested event,
    Emitter<FavoritesState> emit,
  ) async {
    await _removeFavorite(event.wallpaperId);
    // The watch stream triggers a refresh; no direct emit needed.
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}

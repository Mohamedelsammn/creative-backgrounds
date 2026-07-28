part of 'favorites_bloc.dart';

sealed class FavoritesEvent extends Equatable {
  const FavoritesEvent();

  @override
  List<Object?> get props => [];
}

class FavoritesFetchRequested extends FavoritesEvent {
  const FavoritesFetchRequested();
}

class FavoriteRemovedRequested extends FavoritesEvent {
  const FavoriteRemovedRequested(this.wallpaperId);

  final String wallpaperId;

  @override
  List<Object?> get props => [wallpaperId];
}

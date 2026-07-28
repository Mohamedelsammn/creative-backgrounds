part of 'wallpaper_details_bloc.dart';

sealed class WallpaperDetailsEvent extends Equatable {
  const WallpaperDetailsEvent();

  @override
  List<Object?> get props => [];
}

class WallpaperDetailsFetchRequested extends WallpaperDetailsEvent {
  const WallpaperDetailsFetchRequested(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

class WallpaperFavoriteToggleRequested extends WallpaperDetailsEvent {
  const WallpaperFavoriteToggleRequested();
}

class WallpaperShareRequested extends WallpaperDetailsEvent {
  const WallpaperShareRequested();
}

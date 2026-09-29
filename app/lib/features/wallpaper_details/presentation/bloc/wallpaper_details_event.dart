part of 'wallpaper_details_bloc.dart';

sealed class WallpaperDetailsEvent extends Equatable {
  const WallpaperDetailsEvent();

  @override
  List<Object?> get props => [];
}

class WallpaperDetailsFetchRequested extends WallpaperDetailsEvent {
  const WallpaperDetailsFetchRequested(this.id, {this.knownWallpaper});

  final String id;

  /// The list row the user tapped, when the caller already has it. Lets the
  /// screen paint immediately (thumbnail, title, category all already known)
  /// instead of showing a loading spinner while the network round-trip for
  /// the full detail (assets, description) completes in the background.
  final WallpaperEntity? knownWallpaper;

  @override
  List<Object?> get props => [id, knownWallpaper];
}

class WallpaperFavoriteToggleRequested extends WallpaperDetailsEvent {
  const WallpaperFavoriteToggleRequested();
}

class WallpaperShareRequested extends WallpaperDetailsEvent {
  const WallpaperShareRequested();
}

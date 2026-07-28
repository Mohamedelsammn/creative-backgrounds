part of 'wallpaper_details_bloc.dart';

sealed class WallpaperDetailsState extends Equatable {
  const WallpaperDetailsState();

  @override
  List<Object?> get props => [];
}

class WallpaperDetailsLoading extends WallpaperDetailsState {
  const WallpaperDetailsLoading();
}

class WallpaperDetailsLoaded extends WallpaperDetailsState {
  const WallpaperDetailsLoaded({
    required this.wallpaper,
    required this.isFavorite,
  });

  final WallpaperEntity wallpaper;
  final bool isFavorite;

  WallpaperDetailsLoaded copyWith({WallpaperEntity? wallpaper, bool? isFavorite}) {
    return WallpaperDetailsLoaded(
      wallpaper: wallpaper ?? this.wallpaper,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  List<Object?> get props => [wallpaper, isFavorite];
}

class WallpaperDetailsError extends WallpaperDetailsState {
  const WallpaperDetailsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

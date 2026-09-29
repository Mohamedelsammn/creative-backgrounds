part of 'apply_wallpaper_bloc.dart';

sealed class ApplyWallpaperState extends Equatable {
  const ApplyWallpaperState();

  @override
  List<Object?> get props => [];
}

class ApplyWallpaperInitial extends ApplyWallpaperState {
  const ApplyWallpaperInitial();
}

class ApplyWallpaperInProgress extends ApplyWallpaperState {
  const ApplyWallpaperInProgress();
}

class ApplyWallpaperSuccess extends ApplyWallpaperState {
  const ApplyWallpaperSuccess({required this.isLive});

  /// True for a live/depth wallpaper, where this only means "Android's
  /// live-wallpaper picker was launched" - the picker itself is the user's
  /// actual confirmation, so the app must not also claim success with its
  /// own Done screen; that combination is what reads as "applied twice".
  /// False for a static wallpaper, where `WallpaperManager.setBitmap`
  /// genuinely completed synchronously with no further system UI, so the
  /// app's Done screen is the one and only confirmation the user sees.
  final bool isLive;

  @override
  List<Object?> get props => [isLive];
}

class ApplyWallpaperError extends ApplyWallpaperState {
  const ApplyWallpaperError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

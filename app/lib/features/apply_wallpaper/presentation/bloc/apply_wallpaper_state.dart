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
  const ApplyWallpaperSuccess();
}

class ApplyWallpaperError extends ApplyWallpaperState {
  const ApplyWallpaperError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

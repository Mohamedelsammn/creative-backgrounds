part of 'apply_wallpaper_bloc.dart';

sealed class ApplyWallpaperEvent extends Equatable {
  const ApplyWallpaperEvent();

  @override
  List<Object?> get props => [];
}

class ApplyWallpaperRequested extends ApplyWallpaperEvent {
  const ApplyWallpaperRequested({
    required this.wallpaper,
    required this.destination,
    this.clockConfig,
    this.depthConfig,
  });

  final WallpaperEntity wallpaper;
  final ApplyDestination destination;
  final ClockConfigEntity? clockConfig;
  final DepthConfigEntity? depthConfig;

  @override
  List<Object?> get props => [wallpaper, destination, clockConfig, depthConfig];
}

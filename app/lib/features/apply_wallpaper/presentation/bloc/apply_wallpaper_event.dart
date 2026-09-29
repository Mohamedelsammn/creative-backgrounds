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
    this.widgets = const [],
    this.dateWidget,
  });

  final WallpaperEntity wallpaper;
  final ApplyDestination destination;
  final ClockConfigEntity? clockConfig;
  final DepthConfigEntity? depthConfig;

  /// Authored studio widgets to apply. Empty for "Wallpaper Only".
  final List<StudioWidget> widgets;

  /// The independently-positioned date element. Null for "Wallpaper Only".
  final StudioDateWidget? dateWidget;

  @override
  List<Object?> get props =>
      [wallpaper, destination, clockConfig, depthConfig, widgets, dateWidget];
}

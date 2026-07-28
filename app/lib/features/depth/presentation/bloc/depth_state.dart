part of 'depth_bloc.dart';

sealed class DepthState extends Equatable {
  const DepthState();

  @override
  List<Object?> get props => [];
}

class DepthInitial extends DepthState {
  const DepthInitial();
}

class DepthReady extends DepthState {
  const DepthReady({
    required this.config,
    required this.wallpaperSupportsDepth,
  });

  final DepthConfigEntity config;
  final bool wallpaperSupportsDepth;

  @override
  List<Object?> get props => [config, wallpaperSupportsDepth];
}

/// Transient signal emitted when depth is toggled on an unsupported wallpaper.
class DepthNotSupported extends DepthState {
  const DepthNotSupported(this.message);

  final String message;

  @override
  List<Object?> get props => [message, DateTime.now().microsecondsSinceEpoch];
}

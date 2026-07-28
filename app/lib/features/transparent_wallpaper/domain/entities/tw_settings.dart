import 'package:equatable/equatable.dart';

/// User-tunable settings for the transparent wallpaper. Quality is expressed as
/// a target FPS (which also drives capture resolution natively):
/// 30 = Smooth (1080p), 24 = Balanced (720p), 15 = Saver (480p).
class TwSettings extends Equatable {
  const TwSettings({this.fps = 24});

  final int fps;

  TwSettings copyWith({int? fps}) => TwSettings(fps: fps ?? this.fps);

  @override
  List<Object?> get props => [fps];
}

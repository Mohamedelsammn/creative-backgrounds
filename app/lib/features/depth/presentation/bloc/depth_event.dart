part of 'depth_bloc.dart';

sealed class DepthEvent extends Equatable {
  const DepthEvent();

  @override
  List<Object?> get props => [];
}

class DepthConfigLoaded extends DepthEvent {
  const DepthConfigLoaded({
    required this.wallpaperId,
    required this.hasForegroundMask,
  });

  final String wallpaperId;
  final bool hasForegroundMask;

  @override
  List<Object?> get props => [wallpaperId, hasForegroundMask];
}

class DepthEffectToggled extends DepthEvent {
  const DepthEffectToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class DepthConfigSaved extends DepthEvent {
  const DepthConfigSaved();
}

import 'package:equatable/equatable.dart';

class DepthConfigEntity extends Equatable {
  const DepthConfigEntity({
    required this.wallpaperId,
    this.enabled = false,
    this.hasForegroundMask = false,
  });

  final String wallpaperId;
  final bool enabled;
  final bool hasForegroundMask;

  DepthConfigEntity copyWith({bool? enabled, bool? hasForegroundMask}) {
    return DepthConfigEntity(
      wallpaperId: wallpaperId,
      enabled: enabled ?? this.enabled,
      hasForegroundMask: hasForegroundMask ?? this.hasForegroundMask,
    );
  }

  @override
  List<Object?> get props => [wallpaperId, enabled, hasForegroundMask];
}

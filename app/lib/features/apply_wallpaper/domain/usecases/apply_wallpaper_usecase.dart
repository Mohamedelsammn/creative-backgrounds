import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../channels/wallpaper_channel.dart';
import '../../../../core/error/failures.dart';
import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../depth/domain/entities/depth_config_entity.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../repositories/apply_wallpaper_repository.dart';

class ApplyWallpaperUseCase {
  ApplyWallpaperUseCase(this._repository);

  final ApplyWallpaperRepository _repository;

  Future<Either<Failure, bool>> call(ApplyWallpaperParams params) {
    return _repository.apply(
      wallpaper: params.wallpaper,
      destination: params.destination,
      clockConfig: params.clockConfig,
      depthConfig: params.depthConfig,
    );
  }
}

class ApplyWallpaperParams extends Equatable {
  const ApplyWallpaperParams({
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

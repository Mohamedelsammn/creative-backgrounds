import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../channels/wallpaper_channel.dart';
import '../../../../core/error/failures.dart';
import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/domain/entities/studio_design_entity.dart';
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
      widgets: params.widgets,
      dateWidget: params.dateWidget,
    );
  }
}

class ApplyWallpaperParams extends Equatable {
  const ApplyWallpaperParams({
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
  final List<StudioWidget> widgets;
  final StudioDateWidget? dateWidget;

  @override
  List<Object?> get props =>
      [wallpaper, destination, clockConfig, depthConfig, widgets, dateWidget];
}

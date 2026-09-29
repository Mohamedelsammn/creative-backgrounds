import 'package:dartz/dartz.dart';

import '../../../../channels/wallpaper_channel.dart';
import '../../../../core/error/failures.dart';
import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/domain/entities/studio_design_entity.dart';
import '../../../depth/domain/entities/depth_config_entity.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';

abstract class ApplyWallpaperRepository {
  Future<Either<Failure, bool>> apply({
    required WallpaperEntity wallpaper,
    required ApplyDestination destination,
    ClockConfigEntity? clockConfig,
    DepthConfigEntity? depthConfig,

    /// Authored studio widgets to draw over the clock. Empty for a
    /// "Wallpaper Only" apply, which is what removes the ring.
    List<StudioWidget> widgets,

    /// The independently-positioned date element. Null for a
    /// "Wallpaper Only" apply.
    StudioDateWidget? dateWidget,
  });
}

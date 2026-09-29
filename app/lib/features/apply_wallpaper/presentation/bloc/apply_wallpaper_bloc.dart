import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../channels/wallpaper_channel.dart';
import '../../../../core/ads/ad_manager.dart';
import '../../../../core/error/error_handler.dart';
import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/domain/entities/studio_design_entity.dart';
import '../../../depth/domain/entities/depth_config_entity.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../domain/usecases/apply_wallpaper_usecase.dart';

part 'apply_wallpaper_event.dart';
part 'apply_wallpaper_state.dart';

class ApplyWallpaperBloc
    extends Bloc<ApplyWallpaperEvent, ApplyWallpaperState> {
  ApplyWallpaperBloc(this._apply, {void Function()? onStaticApplied})
      : _onStaticApplied = onStaticApplied ?? AdManager.instance.onWallpaperApplied,
        super(const ApplyWallpaperInitial()) {
    on<ApplyWallpaperRequested>(_onRequested);
  }

  final ApplyWallpaperUseCase _apply;

  /// Counts a successful static apply toward the interstitial rule. A live
  /// apply only opens the system picker here; it is counted when the picker
  /// reports it was actually set (see `MainShell`).
  final void Function() _onStaticApplied;

  Future<void> _onRequested(
    ApplyWallpaperRequested event,
    Emitter<ApplyWallpaperState> emit,
  ) async {
    emit(const ApplyWallpaperInProgress());
    final result = await _apply(ApplyWallpaperParams(
      wallpaper: event.wallpaper,
      destination: event.destination,
      clockConfig: event.clockConfig,
      depthConfig: event.depthConfig,
      widgets: event.widgets,
      dateWidget: event.dateWidget,
    ));
    final isLive = event.wallpaper.isLiveApply(
      clockConfig: event.clockConfig,
      depthConfig: event.depthConfig,
    );
    result.fold(
      (failure) =>
          emit(ApplyWallpaperError(ErrorHandler.mapFailureToMessage(failure))),
      (_) {
        emit(ApplyWallpaperSuccess(isLive: isLive));
        // After the apply completed; the ad is never awaited here.
        if (!isLive) _onStaticApplied();
      },
    );
  }
}

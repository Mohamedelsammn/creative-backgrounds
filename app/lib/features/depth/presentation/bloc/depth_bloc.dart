import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/depth_config_entity.dart';
import '../../domain/usecases/save_depth_config_usecase.dart';

part 'depth_event.dart';
part 'depth_state.dart';

class DepthBloc extends Bloc<DepthEvent, DepthState> {
  DepthBloc(this._save) : super(const DepthInitial()) {
    on<DepthConfigLoaded>(_onLoad);
    on<DepthEffectToggled>(_onToggled);
    on<DepthConfigSaved>(_onSaved);
  }

  final SaveDepthConfigUseCase _save;

  DepthConfigEntity? _config;

  bool get _supportsDepth => _config?.hasForegroundMask ?? false;

  void _onLoad(DepthConfigLoaded event, Emitter<DepthState> emit) {
    _config = DepthConfigEntity(
      wallpaperId: event.wallpaperId,
      hasForegroundMask: event.hasForegroundMask,
    );
    emit(DepthReady(config: _config!, wallpaperSupportsDepth: _supportsDepth));
  }

  void _onToggled(DepthEffectToggled event, Emitter<DepthState> emit) {
    final config = _config;
    if (config == null) return;
    if (event.enabled && !_supportsDepth) {
      emit(const DepthNotSupported(
          'Depth effect is not available for this wallpaper.'));
      emit(DepthReady(config: config, wallpaperSupportsDepth: false));
      return;
    }
    _config = config.copyWith(enabled: event.enabled);
    emit(DepthReady(config: _config!, wallpaperSupportsDepth: _supportsDepth));
  }

  Future<void> _onSaved(DepthConfigSaved event, Emitter<DepthState> emit) async {
    final config = _config;
    if (config != null) await _save(config);
  }
}

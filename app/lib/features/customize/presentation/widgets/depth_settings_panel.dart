import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/toggle_row.dart';
import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/presentation/bloc/clock_bloc.dart';
import '../../../depth/presentation/bloc/depth_bloc.dart';
import '../../../depth/presentation/widgets/depth_preview_widget.dart';

/// Depth tab: enable toggle + description + inline layered preview.
class DepthSettingsPanel extends StatelessWidget {
  const DepthSettingsPanel({
    super.key,
    required this.backgroundUrl,
    this.foregroundMaskUrl,
  });

  final String backgroundUrl;
  final String? foregroundMaskUrl;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DepthBloc, DepthState>(
      listenWhen: (prev, curr) => curr is DepthNotSupported,
      listener: (context, state) {
        if (state is DepthNotSupported) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final enabled = state is DepthReady && state.config.enabled;
        final supports = state is DepthReady && state.wallpaperSupportsDepth;
        final clockConfig = context.select<ClockBloc, ClockConfigEntity>(
          (bloc) => bloc.state is ClockReady
              ? (bloc.state as ClockReady).config
              : const ClockConfigEntity(),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: supports
                  ? ''
                  : 'Not available for this wallpaper',
              triggerMode: supports
                  ? TooltipTriggerMode.manual
                  : TooltipTriggerMode.tap,
              child: ToggleRow(
                label: 'Depth Effect',
                subtitle:
                    'The clock sits behind the subject of the wallpaper, like the iOS lock screen.',
                value: enabled,
                enabled: supports,
                onChanged: (v) =>
                    context.read<DepthBloc>().add(DepthEffectToggled(v)),
              ),
            ),
            const SizedBox(height: 16),
            DepthPreviewWidget(
              backgroundUrl: backgroundUrl,
              foregroundMaskUrl: foregroundMaskUrl,
              clockConfig: clockConfig,
              depthEnabled: enabled,
            ),
          ],
        );
      },
    );
  }
}

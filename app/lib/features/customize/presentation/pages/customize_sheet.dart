import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_shapes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';
import '../../../../core/widgets/segmented_control.dart';
import '../../../apply_wallpaper/presentation/pages/apply_wallpaper_page.dart';
import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/presentation/bloc/clock_bloc.dart';
import '../../../depth/presentation/bloc/depth_bloc.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../bloc/customize_bloc.dart';
import '../widgets/clock_settings_panel.dart';
import '../widgets/clock_styles_panel.dart';
import '../widgets/depth_settings_panel.dart';

/// Opens the Customize controls as a floating glass bottom sheet (no route
/// push). The wallpaper + live clock preview stay visible behind it because the
/// caller renders them on the Details page and the barrier is transparent.
///
/// [clockBloc]/[depthBloc] are owned by the caller (Details page) so the same
/// config drives both the sheet controls and the preview behind the sheet.
Future<void> showCustomizeSheet(
  BuildContext context, {
  required WallpaperEntity wallpaper,
  required ClockBloc clockBloc,
  required DepthBloc depthBloc,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CustomizeBloc()),
        BlocProvider.value(value: clockBloc),
        BlocProvider.value(value: depthBloc),
      ],
      child: _CustomizeSheetBody(wallpaper: wallpaper),
    ),
  );
}

class _CustomizeSheetBody extends StatelessWidget {
  const _CustomizeSheetBody({required this.wallpaper});

  final WallpaperEntity wallpaper;

  static const _segments = ['Clock', 'Styles', 'Depth'];

  @override
  Widget build(BuildContext context) {
    // Fixed height: the sheet never resizes, only its content scrolls.
    return FractionallySizedBox(
      heightFactor: 0.68,
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              // Liquid glass: translucent so the wallpaper shows through.
              color: const Color(0xFF141922).withValues(alpha: 0.45),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
              ),
            ),
            child: Column(
              children: [
                const BottomSheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: BlocBuilder<CustomizeBloc, CustomizeState>(
                    builder: (context, state) => SegmentedControl(
                      segments: _segments,
                      selectedIndex: state.activeTab.index,
                      onSegmentChanged: (i) => context
                          .read<CustomizeBloc>()
                          .add(CustomizeTabChanged(CustomizeTab.values[i])),
                    ),
                  ),
                ),
                Expanded(
                  child: BlocBuilder<CustomizeBloc, CustomizeState>(
                    builder: (context, state) => ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: [_tabContent(state.activeTab)],
                    ),
                  ),
                ),
                _ApplyBar(wallpaper: wallpaper),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabContent(CustomizeTab tab) {
    switch (tab) {
      case CustomizeTab.clock:
        return const ClockSettingsPanel();
      case CustomizeTab.styles:
        return const ClockStylesPanel();
      case CustomizeTab.depth:
        return DepthSettingsPanel(
          backgroundUrl: wallpaper.fullUrl,
          foregroundMaskUrl: wallpaper.foregroundMaskUrl,
        );
    }
  }
}

class _ApplyBar extends StatelessWidget {
  const _ApplyBar({required this.wallpaper});

  final WallpaperEntity wallpaper;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Material(
          color: Colors.white,
          borderRadius: AppShapes.pill,
          child: InkWell(
            borderRadius: AppShapes.pill,
            onTap: () {
              final clockState = context.read<ClockBloc>().state;
              final clockConfig = clockState is ClockReady
                  ? clockState.config
                  : const ClockConfigEntity();
              final depthState = context.read<DepthBloc>().state;
              final depthConfig =
                  depthState is DepthReady ? depthState.config : null;

              context.read<ClockBloc>().add(const ClockConfigSaved());
              context.read<DepthBloc>().add(const DepthConfigSaved());

              showApplyWallpaperSheet(
                context,
                wallpaper: wallpaper,
                clockConfig: clockConfig,
                depthConfig: depthConfig,
              );
            },
            child: Container(
              height: 54,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check, size: 20, color: Colors.black),
                  const SizedBox(width: 8),
                  Text('Apply Wallpaper',
                      style:
                          AppTextStyles.bodyLarge.copyWith(color: Colors.black)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

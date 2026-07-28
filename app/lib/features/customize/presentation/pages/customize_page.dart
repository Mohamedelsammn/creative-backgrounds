import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_shapes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/frosted_icon_button.dart';
import '../../../../core/widgets/segmented_control.dart';
import '../../../../injection.dart';
import '../../../apply_wallpaper/presentation/pages/apply_wallpaper_page.dart';
import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/presentation/bloc/clock_bloc.dart';
import '../../../clock/presentation/widgets/clock_renderer_widget.dart';
import '../../../depth/presentation/bloc/depth_bloc.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../../wallpaper_details/domain/usecases/get_wallpaper_details_usecase.dart';
import '../bloc/customize_bloc.dart';
import '../widgets/clock_settings_panel.dart';
import '../widgets/clock_styles_panel.dart';
import '../widgets/depth_settings_panel.dart';

class CustomizePage extends StatelessWidget {
  const CustomizePage({super.key, required this.wallpaperId});

  final String wallpaperId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder(
        future: sl<GetWallpaperDetailsUseCase>()(wallpaperId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          return snapshot.data!.fold(
            (failure) => ErrorView(message: failure.message),
            (wallpaper) => _CustomizeView(wallpaper: wallpaper),
          );
        },
      ),
    );
  }
}

class _CustomizeView extends StatelessWidget {
  const _CustomizeView({required this.wallpaper});

  final WallpaperEntity wallpaper;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CustomizeBloc()),
        BlocProvider(create: (_) => sl<ClockBloc>()..add(const ClockConfigLoaded())),
        BlocProvider(
          create: (_) => sl<DepthBloc>()
            ..add(DepthConfigLoaded(
              wallpaperId: wallpaper.id,
              hasForegroundMask: wallpaper.hasForegroundMask,
            )),
        ),
      ],
      child: Stack(
        children: [
          // Full-bleed wallpaper.
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: wallpaper.fullUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(color: const Color(0xFF15151A)),
              errorWidget: (context, url, error) =>
                  Container(color: const Color(0xFF15151A)),
            ),
          ),
          // Live clock preview overlay.
          Positioned.fill(
            child: BlocBuilder<ClockBloc, ClockState>(
              builder: (context, state) {
                final config = state is ClockReady
                    ? state.config
                    : const ClockConfigEntity();
                return IgnorePointer(
                  child: ClockRendererWidget(config: config),
                );
              },
            ),
          ),
          // Back button.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: FrostedIconButton(
                  icon: Icons.arrow_back_ios_new,
                  semanticLabel: 'Back',
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          ),
          // Draggable settings panel.
          _CustomizePanel(wallpaper: wallpaper),
          // Always-visible Apply button.
          Positioned(
            left: 24,
            right: 24,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: _ApplyButton(wallpaper: wallpaper),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomizePanel extends StatelessWidget {
  const _CustomizePanel({required this.wallpaper});

  final WallpaperEntity wallpaper;

  static const _segments = ['Clock', 'Styles', 'Depth'];

  @override
  Widget build(BuildContext context) {
    // Fixed-height panel pinned to the bottom: the panel never moves, only its
    // content scrolls internally, so the wallpaper + clock preview stay visible.
    final panelHeight = MediaQuery.of(context).size.height * 0.56;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: panelHeight,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E2332).withValues(alpha: 0.82),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
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
                      builder: (context, state) {
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                          children: [_tabContent(state.activeTab)],
                        );
                      },
                    ),
                  ),
                ],
              ),
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

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.wallpaper});

  final WallpaperEntity wallpaper;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppShapes.pill,
      elevation: 8,
      shadowColor: Colors.black45,
      child: InkWell(
        borderRadius: AppShapes.pill,
        onTap: () {
          // Persist config, then open the (live) apply flow.
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
          height: 56,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check, size: 20, color: Colors.black),
              const SizedBox(width: 8),
              Text('Apply Wallpaper',
                  style: AppTextStyles.bodyLarge.copyWith(color: Colors.black)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/frosted_icon_button.dart';
import '../../../../injection.dart';
import '../../../apply_wallpaper/presentation/pages/apply_wallpaper_page.dart';
import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/presentation/bloc/clock_bloc.dart';
import '../../../clock/presentation/widgets/clock_renderer_widget.dart';
import '../../../customize/presentation/pages/customize_sheet.dart';
import '../../../depth/presentation/bloc/depth_bloc.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../bloc/wallpaper_details_bloc.dart';
import '../widgets/wallpaper_info_panel.dart';

class WallpaperDetailsPage extends StatelessWidget {
  const WallpaperDetailsPage({super.key, required this.id, this.heroTag});

  final String id;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<WallpaperDetailsBloc>()..add(WallpaperDetailsFetchRequested(id)),
      child: _DetailsView(id: id, heroTag: heroTag),
    );
  }
}

class _DetailsView extends StatefulWidget {
  const _DetailsView({required this.id, this.heroTag});

  final String id;
  final String? heroTag;

  @override
  State<_DetailsView> createState() => _DetailsViewState();
}

class _DetailsViewState extends State<_DetailsView> {
  // Created lazily when Customize is opened as a bottom sheet; the same blocs
  // drive the sheet controls and the live clock preview rendered behind it.
  ClockBloc? _clockBloc;
  DepthBloc? _depthBloc;
  bool _customizing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _clockBloc?.close();
    _depthBloc?.close();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  Future<void> _openCustomize(WallpaperEntity wallpaper) async {
    final clockBloc = sl<ClockBloc>()..add(const ClockConfigLoaded());
    final depthBloc = sl<DepthBloc>()
      ..add(DepthConfigLoaded(
        wallpaperId: wallpaper.id,
        hasForegroundMask: wallpaper.hasForegroundMask,
      ));
    setState(() {
      _clockBloc = clockBloc;
      _depthBloc = depthBloc;
      _customizing = true;
    });
    await showCustomizeSheet(
      context,
      wallpaper: wallpaper,
      clockBloc: clockBloc,
      depthBloc: depthBloc,
    );
    if (mounted) setState(() => _customizing = false);
    await clockBloc.close();
    await depthBloc.close();
    _clockBloc = null;
    _depthBloc = null;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocBuilder<WallpaperDetailsBloc, WallpaperDetailsState>(
          builder: (context, state) {
            return switch (state) {
              WallpaperDetailsLoading() =>
                const Center(child: CircularProgressIndicator(color: Colors.white)),
              WallpaperDetailsError(:final message) => ErrorView(
                  message: message,
                  onRetry: () => context
                      .read<WallpaperDetailsBloc>()
                      .add(WallpaperDetailsFetchRequested(widget.id)),
                ),
              WallpaperDetailsLoaded(:final wallpaper, :final isFavorite) => Stack(
                  fit: StackFit.expand,
                  children: [
                    // Full-bleed image (behind system bars). The already-cached
                    // thumbnail is the placeholder, so the image is visible
                    // instantly on arrival — never a black flash — while the
                    // full-resolution image loads seamlessly on top.
                    Hero(
                      tag: widget.heroTag ?? 'details_${wallpaper.id}',
                      child: CachedNetworkImage(
                        imageUrl: wallpaper.fullUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 150),
                        placeholderFadeInDuration: Duration.zero,
                        placeholder: (context, url) => CachedNetworkImage(
                          imageUrl: wallpaper.thumbnailUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          placeholder: (context, url) =>
                              Container(color: const Color(0xFF15151A)),
                          errorWidget: (context, url, error) =>
                              Container(color: const Color(0xFF15151A)),
                        ),
                        errorWidget: (context, url, error) => const ColoredBox(
                          color: Color(0xFF15151A),
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.white38, size: 48),
                        ),
                      ),
                    ),
                    // Live clock preview overlay while the Customize sheet is
                    // open (rendered on the wallpaper, behind the sheet).
                    if (_customizing && _clockBloc != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: BlocProvider.value(
                            value: _clockBloc!,
                            child: BlocBuilder<ClockBloc, ClockState>(
                              builder: (context, state) => ClockRendererWidget(
                                config: state is ClockReady
                                    ? state.config
                                    : const ClockConfigEntity(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Top action bar — pinned to the very top safe area.
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            FrostedIconButton(
                              icon: Icons.arrow_back_ios_new,
                              semanticLabel: 'Back',
                              onPressed: () => context.pop(),
                            ),
                            const Spacer(),
                            _AnimatedHeart(
                              isFavorite: isFavorite,
                              onTap: () => context
                                  .read<WallpaperDetailsBloc>()
                                  .add(const WallpaperFavoriteToggleRequested()),
                            ),
                            const SizedBox(width: 10),
                            FrostedIconButton(
                              icon: Icons.ios_share,
                              semanticLabel: 'Share',
                              onPressed: () => context
                                  .read<WallpaperDetailsBloc>()
                                  .add(const WallpaperShareRequested()),
                            ),
                          ],
                        ),
                      ),
                      ),
                    ),
                    // Bottom info panel.
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: WallpaperInfoPanel(
                        wallpaper: wallpaper,
                        onCustomize: () => _openCustomize(wallpaper),
                        onApply: () => showApplyWallpaperSheet(
                          context,
                          wallpaper: wallpaper,
                        ),
                      ),
                    ),
                  ],
                ),
            };
          },
        ),
      ),
    );
  }
}

/// Heart button with a spring scale bounce + fill cross-fade on toggle.
class _AnimatedHeart extends StatelessWidget {
  const _AnimatedHeart({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      child: FrostedIconButton(
        icon: isFavorite ? Icons.favorite : Icons.favorite_border,
        iconColor: isFavorite ? const Color(0xFFFF4D6D) : Colors.white,
        onPressed: onTap,
      ),
    );
  }
}

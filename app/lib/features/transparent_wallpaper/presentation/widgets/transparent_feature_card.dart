import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../injection.dart';
import '../bloc/transparent_wallpaper_bloc.dart';
import 'transparent_control_sheet.dart';
import 'transparent_status_pill.dart';

/// Explore "Special Features" card for the transparent (live rear-camera)
/// wallpaper. Self-contained: it owns its bloc, reflects the live native status,
/// and opens the control sheet on tap.
class TransparentFeatureCard extends StatelessWidget {
  const TransparentFeatureCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TransparentWallpaperBloc>.value(
      value: sl<TransparentWallpaperBloc>()
        ..add(const TransparentWallpaperStarted()),
      child: const _CardBody(),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<TransparentWallpaperBloc, TransparentWallpaperState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => TransparentControlSheet.show(
                context,
                bloc: context.read<TransparentWallpaperBloc>(),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _LeadingIcon(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.transparentWallpaper,
                                style: AppTextStyles.bodyLarge),
                            const SizedBox(height: 3),
                            Text(
                              l10n.transparentWallpaperSubtitle,
                              style: AppTextStyles.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            TransparentStatusPill(state: state),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2F3E), Color(0xFF12151F)],
        ),
      ),
      child: const Icon(Icons.camera_rear_outlined, color: Colors.white, size: 26),
    );
  }
}

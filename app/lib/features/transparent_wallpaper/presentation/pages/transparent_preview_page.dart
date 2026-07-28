import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/frosted_icon_button.dart';
import '../../../../injection.dart';
import '../bloc/transparent_wallpaper_bloc.dart';

/// Native platform-view type for the CameraX live preview.
const String _kPreviewViewType = 'com.creative.backgrounds/transparent_preview';

/// Minimum seconds the user must preview before Apply is enabled.
const int _kMinPreviewSeconds = 5;

/// Full-screen live camera preview shown before applying. The camera itself is
/// rendered natively (PlatformView); Apply is gated for [_kMinPreviewSeconds] so
/// the user actually sees the effect before committing (never auto-applies).
class TransparentPreviewPage extends StatelessWidget {
  const TransparentPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TransparentWallpaperBloc>(
      create: (_) =>
          sl<TransparentWallpaperBloc>()..add(const TransparentWallpaperStarted()),
      child: const _PreviewView(),
    );
  }
}

class _PreviewView extends StatefulWidget {
  const _PreviewView();

  @override
  State<_PreviewView> createState() => _PreviewViewState();
}

class _PreviewViewState extends State<_PreviewView> {
  Timer? _timer;
  int _remaining = _kMinPreviewSeconds;

  bool get _canApply => _remaining <= 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 0) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _onApply() {
    // Kicks off the native apply flow (foreground service + system picker).
    // The prominent disclosure is layered in front of this in Phase 10.
    context.read<TransparentWallpaperBloc>().add(
          const TransparentActivationRequested(),
        );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Native live camera preview.
            const AndroidView(viewType: _kPreviewViewType),

            // Top + bottom scrims for control legibility.
            const _Scrim(),

            // Top controls: Cancel (left) + Settings (right).
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    FrostedIconButton(
                      icon: Icons.close,
                      semanticLabel: l10n.twCancel,
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    FrostedIconButton(
                      icon: Icons.tune,
                      semanticLabel: l10n.twSettings,
                      onPressed: () =>
                          context.push(RouteNames.transparentSettings),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom: hint + Apply.
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.twPreviewHint,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ApplyButton(
                        enabled: _canApply,
                        label: _canApply
                            ? l10n.twApply
                            : l10n.twApplyIn(_remaining),
                        onTap: _onApply,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x66000000),
              Color(0x00000000),
              Color(0x00000000),
              Color(0x99000000),
            ],
            stops: [0.0, 0.2, 0.6, 1.0],
          ),
        ),
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: enabled ? Colors.white : Colors.white24,
        borderRadius: AppShapes.pill,
        child: InkWell(
          borderRadius: AppShapes.pill,
          onTap: enabled ? onTap : null,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.bodyLarge.copyWith(
                color: enabled ? Colors.black : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

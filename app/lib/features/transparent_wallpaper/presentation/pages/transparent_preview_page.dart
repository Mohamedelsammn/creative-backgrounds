import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
const String _kPreviewViewType = 'com.backgrounds.trend4k/transparent_preview';

/// Full-screen live camera preview shown before applying. The camera itself is
/// rendered natively (PlatformView) and fills the whole screen, so what the user
/// sees here is what the wallpaper will look like. Nothing is ever applied
/// without an explicit tap on Continue.
class TransparentPreviewPage extends StatelessWidget {
  const TransparentPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    // `.value`, never `create:` - the bloc is a shared singleton and
    // BlocProvider would close it when this route pops.
    return BlocProvider<TransparentWallpaperBloc>.value(
      value: sl<TransparentWallpaperBloc>()
        ..add(const TransparentWallpaperStarted()),
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
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  Future<void> _onApply() async {
    // Kick off the native apply flow (foreground service + system picker).
    //
    // Do NOT pop first. This page owns its bloc, so popping immediately would
    // dispose it, cancel its EventChannel subscription, and drop every state
    // transition that happens during the apply - which is how the UI ended up
    // stuck on "Preparing". Await the request, then leave: by that point the
    // native side owns the flow and reports its outcome on the activity-resume
    // sync, which any surviving control surface picks up.
    final bloc = context.read<TransparentWallpaperBloc>();
    bloc.add(const TransparentActivationRequested());

    // Give the command a moment to reach native before this route (and its
    // bloc) goes away.
    await bloc.stream.firstWhere((s) => !s.busy).timeout(
          const Duration(seconds: 5),
          onTimeout: () => bloc.state,
        );
    if (!mounted) return;
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
            // Native live camera preview, full-bleed.
            // `AndroidViewSurface` + `initExpensiveAndroidView` selects hybrid
            // composition. The default `AndroidView` uses a virtual display,
            // which measures the native view independently of the Flutter
            // widget - that is what left the camera occupying only part of the
            // screen with black underneath. Hybrid composition puts the real
            // view in the activity hierarchy at the widget's exact size.
            const _CameraPreviewSurface(),

            // Top controls: Cancel (left) + Settings (right).
            // `Positioned` with top/left/right (and no bottom) gives the row its
            // natural height. A bare child of a `StackFit.expand` Stack is
            // stretched to the full height instead, and the Row then centres its
            // children vertically - which is what put the close button in the
            // middle of the screen.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
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
            ),

            // Bottom: hint + Apply.
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: BlocBuilder<TransparentWallpaperBloc,
                      TransparentWallpaperState>(
                    builder: (context, state) => _ApplyButton(
                      // Disabled only while the request is in flight, so a
                      // double tap cannot open two pickers.
                      enabled: !state.busy,
                      label: l10n.twContinue,
                      onTap: _onApply,
                    ),
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

/// Hosts the native CameraX preview using hybrid composition.
///
/// Hybrid composition costs more than a virtual display, but it is the only
/// mode where the platform view is laid out by the real Android view system at
/// the size Flutter asked for - which is what a full-bleed camera preview
/// requires.
class _CameraPreviewSurface extends StatelessWidget {
  const _CameraPreviewSurface();

  @override
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: _kPreviewViewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
      onCreatePlatformView: (params) {
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: _kPreviewViewType,
          layoutDirection: TextDirection.ltr,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}

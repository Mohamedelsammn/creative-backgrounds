import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ads/ad_manager.dart';

import '../../channels/wallpaper_channel.dart';
import '../../features/adblock/presentation/ad_integrity_gate.dart';
import '../../injection.dart';
import '../l10n/l10n.dart';
import '../theme/app_spacing.dart';
import '../widgets/floating_bottom_nav.dart';
import '../widgets/nav_visibility.dart';

/// Persistent shell hosting the four primary tabs and the floating bottom nav.
/// Owns a [NavVisibilityController] so tab pages can reveal/hide the nav
/// (Explore hides it at the top; Categories/Favorites/Settings keep it
/// visible).
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  final NavVisibilityController _navVisibility = NavVisibilityController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Full ad-blocking check, once per launch, after Home is on screen -
    // never on Splash's critical path.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AdIntegrityGate.instance.runPostHomeCheck(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navVisibility.dispose();
    super.dispose();
  }

  // A live/depth apply now returns to Home the instant the system picker
  // launches (the picker itself is the next thing the user sees), rather
  // than waiting here on Details/Customize for an outcome that can take an
  // unpredictable amount of time. `ACTION_CHANGE_LIVE_WALLPAPER` gives no
  // result callback, so resuming the app is the only moment the outcome
  // becomes knowable at all - reported here, at the shell level, since the
  // user has already landed back on Home (or another tab) by the time it
  // arrives.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _checkPendingApplyOutcome();
  }

  Future<void> _checkPendingApplyOutcome() async {
    final outcome = await sl<WallpaperChannel>().consumePendingApplyOutcome();
    if (!mounted || outcome == LiveWallpaperApplyOutcome.none) return;
    // A live apply is only successful once the picker actually set it.
    if (outcome == LiveWallpaperApplyOutcome.applied) {
      AdManager.instance.onWallpaperApplied();
    }

    final message = outcome == LiveWallpaperApplyOutcome.applied
        ? context.l10n.liveWallpaperAppliedToast
        : context.l10n.liveWallpaperNotAppliedToast;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onTap(int index) {
    // Non-Explore tabs always show the nav; Explore manages it via scroll.
    if (index != 0) _navVisibility.show();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavVisibility(
      controller: _navVisibility,
      child: Scaffold(
        body: Stack(
          children: [
            widget.navigationShell,
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.floatingBottom,
              child: SafeArea(
                top: false,
                child: Center(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _navVisibility,
                    builder: (context, visible, _) => FloatingBottomNav(
                      currentIndex: widget.navigationShell.currentIndex,
                      onTap: _onTap,
                      visible: visible,
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_spacing.dart';
import '../widgets/floating_bottom_nav.dart';
import '../widgets/nav_visibility.dart';

/// Persistent shell hosting the three primary tabs and the floating bottom nav.
/// Owns a [NavVisibilityController] so tab pages can reveal/hide the nav
/// (Explore hides it at the top; Favorites/Settings keep it visible).
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final NavVisibilityController _navVisibility = NavVisibilityController();

  @override
  void dispose() {
    _navVisibility.dispose();
    super.dispose();
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

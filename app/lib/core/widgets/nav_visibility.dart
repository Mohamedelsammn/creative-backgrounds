import 'package:flutter/widgets.dart';

/// Drives visibility of the shell's floating bottom nav. Owned by the shell and
/// read by tab pages (Explore hides it at the top of the list, reveals it on
/// scroll; Favorites/Settings keep it shown).
class NavVisibilityController extends ValueNotifier<bool> {
  NavVisibilityController([super.value = true]);

  void show() => value = true;
  void hide() => value = false;
}

class NavVisibility extends InheritedNotifier<NavVisibilityController> {
  const NavVisibility({
    super.key,
    required NavVisibilityController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Returns the controller if a [NavVisibility] ancestor exists, else null so
  /// pages remain usable standalone (e.g. in tests).
  static NavVisibilityController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NavVisibility>()
        ?.notifier;
  }
}

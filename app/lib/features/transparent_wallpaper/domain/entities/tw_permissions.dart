/// State of a single runtime permission, as reported natively.
enum TwPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,

  /// The permission does not apply on this OS version (e.g. notifications < 33).
  notRequired,
}

/// Snapshot of the permissions the transparent wallpaper needs.
class TwPermissions {
  const TwPermissions({
    required this.camera,
    required this.notifications,
  });

  final TwPermissionStatus camera;
  final TwPermissionStatus notifications;

  /// Camera is mandatory; notifications are optional (a warning at most).
  bool get isReady => camera == TwPermissionStatus.granted;

  /// The user must visit system settings to proceed (camera hard-denied).
  bool get needsSettings => camera == TwPermissionStatus.permanentlyDenied ||
      camera == TwPermissionStatus.restricted;
}

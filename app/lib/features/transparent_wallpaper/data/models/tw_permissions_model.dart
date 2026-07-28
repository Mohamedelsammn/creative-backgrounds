import '../../domain/entities/tw_permissions.dart';

/// Maps the native permission-status map into [TwPermissions].
class TwPermissionsModel {
  const TwPermissionsModel._();

  static TwPermissions fromMap(Map<dynamic, dynamic> map) {
    return TwPermissions(
      camera: _statusFrom(map['camera'] as String?),
      notifications: _statusFrom(map['notifications'] as String?),
    );
  }

  static TwPermissionStatus _statusFrom(String? raw) {
    switch (raw) {
      case 'granted':
        return TwPermissionStatus.granted;
      case 'denied':
        return TwPermissionStatus.denied;
      case 'permanentlyDenied':
        return TwPermissionStatus.permanentlyDenied;
      case 'restricted':
        return TwPermissionStatus.restricted;
      case 'notRequired':
        return TwPermissionStatus.notRequired;
      default:
        // Safest default: treat unknown as denied so we never assume access.
        return TwPermissionStatus.denied;
    }
  }
}

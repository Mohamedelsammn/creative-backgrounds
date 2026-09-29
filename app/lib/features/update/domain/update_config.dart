/// Compile-time constants for the mandatory-update gate.
///
/// The minimum supported build is NOT here - it is fetched at runtime from
/// `AppConfig.updatePolicyUrl` (see `UpdatePolicyRemoteDatasource`), because
/// a hardcoded minimum can only be changed by shipping another release,
/// which defeats the entire point of a remote kill switch. This class now
/// holds only the fallback store listing.
class UpdateConfig {
  const UpdateConfig._();

  /// Play listing used when the remote policy supplies no `storeUrl`.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.backgrounds.trend4k';
}

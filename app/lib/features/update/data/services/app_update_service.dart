import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/entities/update_policy.dart';
import '../../domain/update_config.dart';
import '../datasources/update_policy_remote_datasource.dart';

/// Decides whether the installed build is still allowed to run.
///
/// Comparison is on the Android **versionCode / build number** (an integer
/// from `PackageInfo.buildNumber`), against a REMOTELY controlled minimum -
/// see [UpdatePolicyRemoteDatasource]. An earlier revision compared
/// semantic-version strings against a hardcoded constant, which meant the
/// gate could only ever be changed by shipping another release (defeating
/// remote control) and inherited all the usual `1.10.0 < 1.9.0` string
/// ordering hazards.
///
/// ## Fail-safe
///
/// Every failure path resolves to [UpdatePolicy.failOpen] - i.e. "not
/// required". A config outage, a DNS failure, a malformed document, or a
/// missing `UPDATE_POLICY_URL` must never block the entire install base out
/// of a working app. A missed force-update is recovered on the next launch;
/// a false one is a support incident.
class AppUpdateService {
  AppUpdateService(this._remote);

  final UpdatePolicyRemoteDatasource _remote;

  /// Cached for the process lifetime so the resume re-check (and any repeat
  /// call) does not refetch on every foreground event.
  UpdatePolicy? _cachedPolicy;

  /// The policy actually in force, fetched at most once per process unless
  /// [forceRefresh] is set (used by the resume re-check on the blocking
  /// screen, where the user may have just updated).
  Future<UpdatePolicy> resolvePolicy({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cachedPolicy;
      if (cached != null) return cached;
    }
    final fetched = await _remote.fetchPolicy();
    final policy = fetched ?? UpdatePolicy.failOpen;
    _cachedPolicy = policy;
    return policy;
  }

  /// The installed Android versionCode, or null when it cannot be read or
  /// is not an integer. Null is treated as "cannot evaluate" by callers,
  /// which then allow access rather than guess.
  Future<int?> installedBuildNumber() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber.trim());
    } catch (_) {
      return null;
    }
  }

  /// True only when a trusted policy says the installed build is too old.
  ///
  /// Called by `SplashBloc` on the startup path, and again by
  /// `UpdateRequiredScreen` when the app returns to the foreground.
  Future<bool> isUpdateRequired({bool forceRefresh = false}) async {
    try {
      final installed = await installedBuildNumber();
      // Cannot determine what is installed -> never block. Also skips the
      // network call entirely, since no policy could change this answer.
      if (installed == null) return false;

      final policy = await resolvePolicy(forceRefresh: forceRefresh);
      return policy.isUpdateRequiredFor(installed);
    } catch (_) {
      return false;
    }
  }

  /// Play listing URL for the blocking screen: the policy's override when
  /// present, else the compiled-in listing.
  Future<String> storeUrl() async {
    try {
      final policy = await resolvePolicy();
      final remote = policy.storeUrl;
      if (remote != null && remote.isNotEmpty) return remote;
    } catch (_) {
      // Fall through to the compiled-in listing.
    }
    return UpdateConfig.playStoreUrl;
  }

  /// Backend-authored message for [languageCode], or null to use the app's
  /// own localized copy.
  Future<String?> remoteMessage(String languageCode) async {
    try {
      final policy = await resolvePolicy();
      return policy.messageFor(languageCode);
    } catch (_) {
      return null;
    }
  }
}

import 'package:equatable/equatable.dart';

/// The remotely-controlled update policy for this platform.
///
/// Compared against the installed Android `versionCode` (an integer), never
/// against a semantic-version string: a build number is monotonic and
/// unambiguous, whereas `1.10.0` vs `1.9.0` string comparison is a classic
/// source of wrong verdicts.
class UpdatePolicy extends Equatable {
  const UpdatePolicy({
    required this.minimumSupportedBuild,
    this.latestBuild,
    this.forceUpdate = true,
    this.storeUrl,
    this.messages = const {},
  });

  /// The oldest build still allowed to run. An installed build STRICTLY
  /// below this is blocked; equal or higher continues normally.
  final int minimumSupportedBuild;

  /// Newest published build, when the backend reports it. Informational
  /// only - it never gates access, so publishing a release does not
  /// force-update anyone by itself.
  final int? latestBuild;

  /// Master switch. When false the gate is inert no matter what
  /// [minimumSupportedBuild] says, so a bad config value can be neutralised
  /// remotely without shipping a build.
  final bool forceUpdate;

  /// Play listing URL override. Falls back to the compiled-in listing URL
  /// when absent or blank.
  final String? storeUrl;

  /// Locale code -> message. Falls back to the app's own localized copy when
  /// the requested locale is missing.
  final Map<String, String> messages;

  /// The policy used whenever remote config cannot be trusted (offline,
  /// timeout, malformed payload, HTTP error).
  ///
  /// FAIL-OPEN by design: `minimumSupportedBuild: 0` can never exceed a real
  /// installed build, so a config outage leaves every user running normally
  /// instead of locking the entire install base out of an app that was
  /// working a minute earlier. Locking users out is the far more expensive
  /// failure mode - a missed force-update is recoverable on the next launch,
  /// a false force-update is not.
  static const UpdatePolicy failOpen = UpdatePolicy(
    minimumSupportedBuild: 0,
    forceUpdate: false,
  );

  /// True when [installedBuild] is no longer supported.
  bool isUpdateRequiredFor(int installedBuild) {
    if (!forceUpdate) return false;
    if (minimumSupportedBuild <= 0) return false;
    return installedBuild < minimumSupportedBuild;
  }

  /// Localized update message for [languageCode], else null so the caller
  /// can use its own bundled copy.
  String? messageFor(String languageCode) {
    final exact = messages[languageCode];
    if (exact != null && exact.trim().isNotEmpty) return exact;
    return null;
  }

  @override
  List<Object?> get props => [
    minimumSupportedBuild,
    latestBuild,
    forceUpdate,
    storeUrl,
    messages,
  ];
}

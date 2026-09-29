import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/storage_keys.dart';

/// Owns the in-app review prompt: when the user has earned being asked, and
/// the once-per-version guarantee that stops it becoming nagging.
///
/// ## Trigger
///
/// The positive-engagement signal is a **successful wallpaper apply**, not
/// time in app or screens visited - a user who has actually put two of our
/// wallpapers on their phone is the one plausibly happy enough to rate.
/// Only confirmed applies count; [recordSuccessfulApply] is called from the
/// success path alone, never from "Apply tapped".
///
/// ## Anti-spam
///
/// Google Play decides whether its review sheet actually appears (quota,
/// eligibility, recent reviews) and gives no way to find out. That is a
/// normal outcome, so this service NEVER retries on "nothing appeared" -
/// it records that the version was asked and stops. One ask per app
/// version, at most.
///
/// Every method is failure-safe: storage errors, a missing Play Store, and
/// platform exceptions all resolve quietly. A review prompt is the least
/// important thing in the app and must never surface an error or block a UX
/// flow.
class ReviewService {
  ReviewService({HiveStorage? storage, InAppReview? review})
    : _storage = storage ?? HiveStorage(),
      _review = review ?? InAppReview.instance;

  final HiveStorage _storage;
  final InAppReview _review;

  /// Successful applies required before the user is ever asked.
  static const int applyThreshold = 2;

  /// Records one confirmed successful apply and returns the new total.
  ///
  /// Deliberately does NOT itself show anything - the caller finishes the
  /// apply success UX first, then asks [maybeRequestReview] at a calm
  /// moment. Interrupting the success moment with a rating sheet is exactly
  /// the pattern this avoids.
  Future<int> recordSuccessfulApply() async {
    try {
      final next = successfulApplyCount + 1;
      await _storage.write(
        HiveBoxes.settings,
        StorageKeys.successfulApplyCount,
        next,
      );
      return next;
    } catch (_) {
      return successfulApplyCount;
    }
  }

  int get successfulApplyCount =>
      _storage.read<int>(
        HiveBoxes.settings,
        StorageKeys.successfulApplyCount,
      ) ??
      0;

  /// True once enough successful applies have accumulated.
  bool get isEligible => successfulApplyCount >= applyThreshold;

  /// The app version that was last asked, or null if never.
  String? get lastRequestedVersion => _storage.read<String>(
    HiveBoxes.settings,
    StorageKeys.reviewRequestedVersion,
  );

  /// Asks Google Play for a review sheet, if and only if the user is
  /// eligible and this app version has not already asked.
  ///
  /// Returns true when a request was actually handed to Play (which is NOT
  /// a promise that the user saw anything), false when skipped.
  Future<bool> maybeRequestReview() async {
    try {
      if (!isEligible) return false;

      final version = await _currentVersion();
      // Already asked on this version - never ask twice, and never treat
      // "Play showed nothing" as grounds to try again.
      if (version != null && lastRequestedVersion == version) return false;

      if (!await _review.isAvailable()) return false;

      // Persist BEFORE requesting: if the process dies mid-flow, the
      // failure mode should be "asked once too few", never a loop that
      // re-asks on every launch.
      await _markRequested(version);
      await _review.requestReview();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markRequested(String? version) async {
    try {
      if (version != null) {
        await _storage.write(
          HiveBoxes.settings,
          StorageKeys.reviewRequestedVersion,
          version,
        );
      }
      await _storage.write(
        HiveBoxes.settings,
        StorageKeys.reviewRequestedAt,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {
      // Best-effort; a persistence failure must not break the flow.
    }
  }

  Future<String?> _currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }
}

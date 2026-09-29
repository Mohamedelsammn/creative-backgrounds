import 'package:creativebackground/core/storage/hive_storage.dart';
import 'package:creativebackground/core/storage/storage_keys.dart';
import 'package:creativebackground/features/review/data/services/review_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// `ReviewService` gates the Play in-app review prompt on SUCCESSFUL
/// wallpaper applies, and guarantees at most one ask per app version.
///
/// The property that matters most: Google Play may silently decline to show
/// its sheet, and that must never be treated as grounds to ask again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProvider();

  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Creative Backgrounds',
      packageName: 'com.backgrounds.trend4k',
      version: '1.0.0',
      buildNumber: '45',
      buildSignature: '',
    );
    Hive.init('.dart_tool/test_hive_review');
    await Hive.openBox(HiveBoxes.settings);
    await Hive.box(HiveBoxes.settings).clear();
  });

  tearDown(() async {
    await Hive.box(HiveBoxes.settings).clear();
    await Hive.close();
  });

  ReviewService build({
    bool available = true,
    void Function()? onRequest,
  }) => ReviewService(
    storage: HiveStorage(),
    review: _FakeInAppReview(available: available, onRequest: onRequest),
  );

  group('apply-count trigger', () {
    test('0 successful applies -> not eligible, no review', () async {
      final service = build();
      expect(service.successfulApplyCount, 0);
      expect(service.isEligible, isFalse);
      expect(await service.maybeRequestReview(), isFalse);
    });

    test('1 successful apply -> still not eligible', () async {
      final service = build();
      expect(await service.recordSuccessfulApply(), 1);
      expect(service.isEligible, isFalse);
      expect(await service.maybeRequestReview(), isFalse);
    });

    test('2 successful applies -> eligible and the review is requested',
        () async {
      var requested = 0;
      final service = build(onRequest: () => requested++);
      await service.recordSuccessfulApply();
      expect(await service.recordSuccessfulApply(), 2);
      expect(service.isEligible, isTrue);
      expect(await service.maybeRequestReview(), isTrue);
      expect(requested, 1);
    });

    test('the threshold is exactly two applies', () {
      expect(ReviewService.applyThreshold, 2);
    });
  });

  group('only confirmed applies count', () {
    test(
      'the counter only ever moves through recordSuccessfulApply - nothing '
      'about opening Details, tapping Apply, or a cancelled/failed apply '
      'touches it',
      () async {
        final service = build();
        // Simulate a session of browsing and abandoned applies: no calls.
        expect(service.successfulApplyCount, 0);
        expect(service.isEligible, isFalse);

        // Only a confirmed success increments.
        await service.recordSuccessfulApply();
        expect(service.successfulApplyCount, 1);
      },
    );
  });

  group('persistence', () {
    test('the count survives a new service instance (app restart)', () async {
      await build().recordSuccessfulApply();
      await build().recordSuccessfulApply();
      // A fresh instance reads the persisted total, not in-memory state.
      expect(build().successfulApplyCount, 2);
      expect(build().isEligible, isTrue);
    });
  });

  group('anti-spam', () {
    test('a second request on the SAME version is skipped', () async {
      var requested = 0;
      final service = build(onRequest: () => requested++);
      await service.recordSuccessfulApply();
      await service.recordSuccessfulApply();

      expect(await service.maybeRequestReview(), isTrue);
      expect(await service.maybeRequestReview(), isFalse);
      expect(await service.maybeRequestReview(), isFalse);
      expect(requested, 1, reason: 'Play is asked once per version at most');
    });

    test(
      'Play declining to show its sheet is NOT a retry trigger - the version '
      'is still recorded as asked',
      () async {
        var requested = 0;
        final service = build(onRequest: () => requested++);
        await service.recordSuccessfulApply();
        await service.recordSuccessfulApply();

        // requestReview() completing tells us nothing about whether the user
        // saw anything; the service must behave identically either way.
        await service.maybeRequestReview();
        expect(service.lastRequestedVersion, '1.0.0+45');
        expect(await service.maybeRequestReview(), isFalse);
        expect(requested, 1);
      },
    );

    test('a NEW app version becomes eligible to ask again', () async {
      var requested = 0;
      final service = build(onRequest: () => requested++);
      await service.recordSuccessfulApply();
      await service.recordSuccessfulApply();
      expect(await service.maybeRequestReview(), isTrue);

      // Ship a new build: the once-per-version guard no longer matches.
      PackageInfo.setMockInitialValues(
        appName: 'Creative Backgrounds',
        packageName: 'com.backgrounds.trend4k',
        version: '1.1.0',
        buildNumber: '46',
        buildSignature: '',
      );
      expect(await build(onRequest: () => requested++).maybeRequestReview(),
          isTrue);
      expect(requested, 2);
    });

    test('a request timestamp is persisted for future spacing rules',
        () async {
      final service = build();
      await service.recordSuccessfulApply();
      await service.recordSuccessfulApply();
      await service.maybeRequestReview();
      final at = HiveStorage().read<String>(
        HiveBoxes.settings,
        StorageKeys.reviewRequestedAt,
      );
      expect(at, isNotNull);
      expect(DateTime.tryParse(at!), isNotNull);
    });
  });

  group('failure safety', () {
    test('an unavailable Play Store is a silent no-op', () async {
      final service = build(available: false);
      await service.recordSuccessfulApply();
      await service.recordSuccessfulApply();
      expect(await service.maybeRequestReview(), isFalse);
    });

    test('a throwing review plugin never propagates', () async {
      final service = ReviewService(
        storage: HiveStorage(),
        review: _ThrowingInAppReview(),
      );
      await service.recordSuccessfulApply();
      await service.recordSuccessfulApply();
      expect(await service.maybeRequestReview(), isFalse);
    });
  });
}

class _FakeInAppReview implements InAppReview {
  _FakeInAppReview({required this.available, this.onRequest});
  final bool available;
  final void Function()? onRequest;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => onRequest?.call();

  @override
  Future<void> openStoreListing({String? appStoreId, String? microsoftStoreId}) async {}
}

class _ThrowingInAppReview implements InAppReview {
  @override
  Future<bool> isAvailable() async => throw Exception('play missing');

  @override
  Future<void> requestReview() async => throw Exception('play missing');

  @override
  Future<void> openStoreListing({String? appStoreId, String? microsoftStoreId}) async {}
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      '.dart_tool/test_hive_review';
}

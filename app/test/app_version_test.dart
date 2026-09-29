import 'package:creativebackground/features/update/domain/entities/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AppVersion` is a small hand-rolled dotted-version comparator (deliberately
/// not `pub_semver`, a transitive-only dependency here) used by
/// `AppUpdateService` to gate the app against `UpdateConfig.minSupportedVersion`.
void main() {
  group('parsing', () {
    test('a plain "major.minor.patch" string parses to matching parts', () {
      expect(AppVersion.parse('5.0.1').parts, [5, 0, 1]);
    });

    test('the build-number suffix ("+45") is discarded', () {
      expect(AppVersion.parse('5.0.1+45').parts, [5, 0, 1]);
    });

    test('a malformed segment degrades to 0 rather than throwing', () {
      expect(AppVersion.parse('5.x.1').parts, [5, 0, 1]);
    });
  });

  group('comparison', () {
    test('a strictly greater major version compares greater', () {
      expect(AppVersion.parse('6.0.0') > AppVersion.parse('5.9.9'), isTrue);
    });

    test('string-order would get this wrong, but numeric comparison does not: '
        '5.10.0 is greater than 5.9.0', () {
      expect(AppVersion.parse('5.10.0') > AppVersion.parse('5.9.0'), isTrue);
    });

    test('equal versions compare equal', () {
      expect(AppVersion.parse('5.0.1').compareTo(AppVersion.parse('5.0.1')), 0);
    });

    test('a missing trailing segment is treated as 0: "5.0" == "5.0.0"', () {
      expect(
        AppVersion.parse('5.0').compareTo(AppVersion.parse('5.0.0')),
        0,
      );
    });

    test('a lesser patch version compares less', () {
      expect(AppVersion.parse('5.0.0') < AppVersion.parse('5.0.1'), isTrue);
    });
  });
}

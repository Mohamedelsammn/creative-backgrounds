import 'package:creativebackground/features/update/data/datasources/update_policy_remote_datasource.dart';
import 'package:creativebackground/features/update/domain/entities/update_policy.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// The remote policy document is untrusted input on the startup path. Every
/// malformed shape must yield null (-> `UpdatePolicy.failOpen`) rather than a
/// half-populated policy that could block users because of a backend typo.
void main() {
  UpdatePolicy? parse(dynamic body) =>
      UpdatePolicyRemoteDatasourceImpl.parseBody(body);

  test('a well-formed android-scoped document parses fully', () {
    final policy = parse({
      'android': {
        'minimumSupportedBuild': 47,
        'latestBuild': 49,
        'forceUpdate': true,
        'storeUrl': 'https://play.google.com/store/apps/details?id=x',
        'updateMessage': {'en': 'Update please', 'ar': 'حدّث'},
      },
    });
    expect(policy, isNotNull);
    expect(policy!.minimumSupportedBuild, 47);
    expect(policy.latestBuild, 49);
    expect(policy.forceUpdate, isTrue);
    expect(policy.messageFor('ar'), 'حدّث');
  });

  test('a flat (non-platform-scoped) document also parses', () {
    expect(parse({'minimumSupportedBuild': 12})?.minimumSupportedBuild, 12);
  });

  test('numeric strings are accepted for build numbers', () {
    final policy = parse({
      'android': {'minimumSupportedBuild': '47'},
    });
    expect(policy?.minimumSupportedBuild, 47);
  });

  test('forceUpdate defaults to true when omitted', () {
    final policy = parse({
      'android': {'minimumSupportedBuild': 5},
    });
    expect(policy?.forceUpdate, isTrue);
  });

  test('forceUpdate:false is honoured and disables the gate', () {
    final policy = parse({
      'android': {'minimumSupportedBuild': 999, 'forceUpdate': false},
    });
    expect(policy?.isUpdateRequiredFor(1), isFalse);
  });

  group('malformed input yields null (fail-open)', () {
    test('missing minimumSupportedBuild', () {
      expect(parse({'android': {'latestBuild': 9}}), isNull);
    });

    test('non-numeric minimumSupportedBuild', () {
      expect(parse({'android': {'minimumSupportedBuild': 'soon'}}), isNull);
    });

    test('a JSON array instead of an object', () {
      expect(parse([1, 2, 3]), isNull);
    });

    test('a bare string body', () {
      expect(parse('not json at all'), isNull);
    });

    test('null body', () {
      expect(parse(null), isNull);
    });

    test('an empty object', () {
      expect(parse(<String, dynamic>{}), isNull);
    });
  });

  test('blank storeUrl is discarded so the fallback listing is used', () {
    final policy = parse({
      'android': {'minimumSupportedBuild': 1, 'storeUrl': '   '},
    });
    expect(policy?.storeUrl, isNull);
  });

  test('non-string message values are dropped, valid ones kept', () {
    final policy = parse({
      'android': {
        'minimumSupportedBuild': 1,
        'updateMessage': {'en': 'ok', 'ar': 42, 'de': ''},
      },
    });
    expect(policy?.messageFor('en'), 'ok');
    expect(policy?.messageFor('ar'), isNull);
    expect(policy?.messageFor('de'), isNull);
  });

  test(
    'an unset UPDATE_POLICY_URL skips the fetch entirely and reports null, '
    'so an unconfigured build can never gate anyone',
    () async {
      // dotenv is not loaded in tests, so AppConfig.updatePolicyUrl is ''.
      final result =
          await UpdatePolicyRemoteDatasourceImpl(Dio()).fetchPolicy();
      expect(result, isNull);
    },
  );
}

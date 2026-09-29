import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
import 'package:creativebackground/features/settings/domain/entities/app_settings.dart';
import 'package:creativebackground/features/settings/domain/repositories/settings_repository.dart';
import 'package:creativebackground/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:creativebackground/features/settings/domain/usecases/update_settings_usecase.dart';
import 'package:creativebackground/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:creativebackground/features/settings/presentation/pages/settings_page.dart';
import 'package:creativebackground/injection.dart' as di;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Settings must contain exactly the rows the redesign spec requires -
/// Language, Clear cache, Rate the app, Share app, About (Privacy Policy
/// moved onto the About page) -
/// and explicitly must NOT contain a Premium/Pro row, since mobile no longer
/// has any in-app entitlement purchase flow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    di.sl.registerFactory<SettingsBloc>(
      () => SettingsBloc(
        getSettings: GetSettingsUseCase(_FakeSettingsRepository()),
        updateSettings: UpdateSettingsUseCase(_FakeSettingsRepository()),
      ),
    );
  });

  tearDown(() => di.sl.reset());

  Future<void> pumpSettings(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) =>
              const Scaffold(body: SettingsPage()),
        ),
        GoRoute(path: '/about', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/privacy', builder: (context, state) => const SizedBox()),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows Language, Clear cache, Rate the app, Share app and '
      'About - and nothing named Premium/Pro', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Clear cache'), findsOneWidget);
    expect(find.text('Rate the app'), findsOneWidget);
    expect(find.text('Share app'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    // Privacy Policy lives on the About page (`about_page.dart`), not on
    // Settings itself - still reachable, one tap further in.
    expect(find.text('Privacy Policy'), findsNothing);

    expect(find.textContaining('Premium'), findsNothing);
    expect(find.textContaining('PRO', findRichText: true), findsNothing);
  });
}

class _FakeSettingsRepository implements SettingsRepository {
  static const _settings = AppSettings(
    language: 'en',
    cachedSizeBytes: 1024,
    appVersion: '1.0.0',
  );

  @override
  Future<Either<Failure, AppSettings>> getSettings() async =>
      const Right(_settings);

  @override
  Future<Either<Failure, AppSettings>> setLanguage(String language) async =>
      Right(_settings.copyWith(language: language));

  @override
  Future<Either<Failure, AppSettings>> clearCache() async =>
      const Right(AppSettings(language: 'en', cachedSizeBytes: 0, appVersion: '1.0.0'));
}

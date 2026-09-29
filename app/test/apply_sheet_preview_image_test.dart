import 'dart:async';

import 'package:creativebackground/channels/wallpaper_channel.dart';
import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
import 'package:creativebackground/core/router/route_names.dart';
import 'package:creativebackground/features/apply_wallpaper/domain/repositories/apply_wallpaper_repository.dart';
import 'package:creativebackground/features/apply_wallpaper/domain/usecases/apply_wallpaper_usecase.dart';
import 'package:creativebackground/features/apply_wallpaper/presentation/bloc/apply_wallpaper_bloc.dart';
import 'package:creativebackground/features/apply_wallpaper/presentation/pages/apply_wallpaper_page.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/depth/domain/entities/depth_config_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/injection.dart' as di;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The redesigned Apply sheet must show a small preview of the wallpaper
/// being applied, above the destination buttons - the mobile user has just
/// backed out of a Customize-free flow, so this is their last visual
/// confirmation before committing.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');
  final wallpaper = WallpaperEntity(
    id: 'w1',
    title: 'Wallpaper',
    category: category,
    thumbnailUrl: 'https://cdn.test/w1.webp',
    fullUrl: 'https://cdn.test/w1.webp',
    resolution: '1080x1920',
  );

  late GoRouter router;

  Future<void> pumpApp(WidgetTester tester) async {
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const _HomeStub()),
        GoRoute(
            path: RouteNames.explore,
            builder: (context, state) => const _HomeStub()),
        GoRoute(
            path: RouteNames.success,
            builder: (context, state) => const _SuccessStub()),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pump();
  }

  setUp(() {
    di.sl.registerFactory<ApplyWallpaperBloc>(
      () => ApplyWallpaperBloc(ApplyWallpaperUseCase(_NoopApplyRepository())),
    );
  });

  tearDown(() => di.sl.reset());

  testWidgets('shows a preview image of the wallpaper above the destination '
      'buttons', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(_HomeStub));

    unawaited(showApplyWallpaperSheet(context, wallpaper: wallpaper));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsWidgets,
        reason: 'the sheet must render a preview of the wallpaper being '
            'applied, not just destination text buttons');
    expect(find.text('Home Screen'), findsOneWidget);
  });
}

class _HomeStub extends StatelessWidget {
  const _HomeStub();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('home'));
}

class _SuccessStub extends StatelessWidget {
  const _SuccessStub();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('success'));
}

class _NoopApplyRepository implements ApplyWallpaperRepository {
  @override
  Future<Either<Failure, bool>> apply({
    required WallpaperEntity wallpaper,
    required ApplyDestination destination,
    ClockConfigEntity? clockConfig,
    DepthConfigEntity? depthConfig,
    List<StudioWidget> widgets = const [],
    StudioDateWidget? dateWidget,
  }) async =>
      const Right(true);
}

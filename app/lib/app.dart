import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n/generated/app_localizations.dart';
import 'core/localization/locale_cubit.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_banner.dart';
import 'features/connectivity/bloc/connectivity_bloc.dart';
import 'injection.dart';

/// Root application widget. Provides app-scoped blocs above [MaterialApp] and
/// wires GoRouter + theme + localization.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  // Router is built once and kept for the app's lifetime.
  final _router = AppRouter.build();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ConnectivityBloc>.value(value: sl<ConnectivityBloc>()),
        BlocProvider<LocaleCubit>.value(value: sl<LocaleCubit>()),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return MaterialApp.router(
            title: 'Creative Backgrounds',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            routerConfig: _router,
            locale: locale,
            supportedLocales: LocaleCubit.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              // Root-level offline banner. Zero-footprint when online so
              // full-bleed screens keep extending behind the status bar.
              final topInset = MediaQuery.of(context).viewPadding.top;
              return Column(
                children: [
                  BlocBuilder<ConnectivityBloc, ConnectivityState>(
                    builder: (context, state) => OfflineBanner(
                      visible: state is ConnectivityOffline,
                      topInset: topInset,
                    ),
                  ),
                  Expanded(child: child ?? const SizedBox.shrink()),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

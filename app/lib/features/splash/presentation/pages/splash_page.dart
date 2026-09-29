import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/ad_manager.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_names.dart';
import '../../../../injection.dart';
import '../../../adblock/presentation/ad_integrity_gate.dart';
import '../../../update/data/services/app_update_service.dart';
import '../../../update/presentation/pages/update_required_screen.dart';
import '../bloc/splash_bloc.dart';
import '../widgets/premium_splash_animation.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SplashBloc>(),
      child: const _SplashView(),
    );
  }
}

class _SplashView extends StatefulWidget {
  const _SplashView();

  @override
  State<_SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<_SplashView> {
  @override
  void initState() {
    super.initState();
    // Paint the splash before platform channels, storage, or an integrity
    // signal are touched. This gives the entrance animation a guaranteed
    // first frame instead of competing with startup work in the initial build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SplashBloc>().add(const SplashStarted());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocConsumer<SplashBloc, SplashState>(
        listener: (context, state) {
          if (state is SplashComplete) {
            context.go(RouteNames.explore);
            // Never make Home wait for an App Open network load. Home is
            // shown first; AdManager shows an App Open that is ready, or one
            // that arrives within its short cold-start window.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => AdManager.instance.onHomeReady(),
            );
          } else if (state is SplashError) {
            _showErrorDialog(context, state.message);
          } else if (state is SplashAdsBlocked) {
            AdIntegrityGate.instance.present(
              Navigator.of(context),
              onCleared: () {
                // Enter the app exactly like a clean Splash does.
                context.go(RouteNames.explore);
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => AdManager.instance.onHomeReady(),
                );
              },
            );
          } else if (state is SplashUpdateRequired) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => UpdateRequiredScreen(
                  service: sl<AppUpdateService>(),
                  // If the user updates and returns, the gate re-checks and
                  // hands control back here rather than stranding them.
                  onUpdateResolved: () => context.go(RouteNames.explore),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return const Center(
            child: PremiumSplashAnimation(appName: 'Creative Backgrounds'),
          );
        },
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.somethingWentWrong),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<SplashBloc>().add(const SplashStarted());
            },
            child: Text(context.l10n.retry),
          ),
        ],
      ),
    );
  }
}

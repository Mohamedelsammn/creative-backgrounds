import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/services/ad_integrity_service.dart';

/// Terminal screen shown when [AdIntegrityService] determines that ads are
/// being blocked (VPN, ad-blocking private DNS, or every ad request
/// failing). The app is ad-funded, so this screen intentionally has no way
/// forward except a successful retry - no skip, no back navigation.
///
/// [onRetrySucceeded] is called once a retry check comes back clear - the
/// caller (whatever routed here from Splash) decides where to navigate next,
/// keeping this widget free of any router dependency.
class AdBlockingDetectedScreen extends StatefulWidget {
  const AdBlockingDetectedScreen({
    super.key,
    required this.onRetrySucceeded,
  });

  final VoidCallback onRetrySucceeded;

  @override
  State<AdBlockingDetectedScreen> createState() =>
      _AdBlockingDetectedScreenState();
}

class _AdBlockingDetectedScreenState extends State<AdBlockingDetectedScreen>
    with WidgetsBindingObserver {
  final _service = AdIntegrityService();
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The whole point of this gate is that the user fixes the problem
    // OUTSIDE the app (Private DNS off, VPN/ad-blocker disabled) and comes
    // back - so returning to the foreground is exactly when a re-check is
    // worth running. The observer is registered only for this screen's
    // lifetime, so no other part of the app pays for it, and `_isRetrying`
    // keeps overlapping resume events from stacking probes.
    if (state == AppLifecycleState.resumed && !_isRetrying) {
      unawaited(_retry());
    }
  }

  Future<void> _retry() async {
    if (!mounted) return;
    setState(() => _isRetrying = true);
    final result = await _service.runIntegrityCheck();
    if (!mounted) return;
    if (!result.isBlocked) {
      widget.onRetrySucceeded();
      return;
    }
    setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      // The user must stay on this screen until ads load successfully - no
      // system-back, no swipe-back gesture out of it.
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 96,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.adsBlockedTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.adsBlockedBody,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isRetrying ? null : _retry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                    child: _isRetrying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            l10n.adsBlockedRetry,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/services/app_update_service.dart';

/// Terminal screen shown when the installed build is below the remotely
/// configured `minimumSupportedBuild`. No skip, no back navigation - the
/// user must update to continue.
///
/// "Update Now" prefers Google Play's **immediate in-app update** flow
/// (Play already has the new build staged, so the user never leaves the
/// app), and falls back to opening the Play listing whenever that flow is
/// unavailable for any reason - Play Services missing, sideloaded build,
/// no update staged yet, or the user cancelling the sheet.
///
/// When the app returns to the foreground this screen re-checks eligibility
/// (forcing a policy refetch) and dismisses itself via [onUpdateResolved] if
/// the user has since updated - so a completed update does not leave them
/// staring at a stale gate.
class UpdateRequiredScreen extends StatefulWidget {
  const UpdateRequiredScreen({
    super.key,
    required this.service,
    required this.onUpdateResolved,
  });

  final AppUpdateService service;

  /// Invoked once a re-check confirms the installed build is supported again.
  final VoidCallback onUpdateResolved;

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _remoteMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadRemoteMessage());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only on actual resume, and only while this gate is the thing on screen
    // - this observer is registered exactly as long as the gate lives, so it
    // cannot fire for any other part of the app.
    if (state == AppLifecycleState.resumed) {
      unawaited(_recheck());
    }
  }

  Future<void> _loadRemoteMessage() async {
    final code = context.languageCode;
    final message = await widget.service.remoteMessage(code);
    if (!mounted || message == null) return;
    setState(() => _remoteMessage = message);
  }

  /// Re-evaluates eligibility with a forced policy refetch. If the user
  /// updated while away, the new build number clears the gate.
  Future<void> _recheck() async {
    final stillRequired = await widget.service.isUpdateRequired(
      forceRefresh: true,
    );
    if (!mounted || stillRequired) return;
    widget.onUpdateResolved();
  }

  Future<void> _updateNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final usedPlayFlow = await _tryImmediateInAppUpdate();
      if (!usedPlayFlow) await _openStoreListing();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Attempts Play's immediate update. Returns false (so the caller falls
  /// back to the listing) for every non-success path: Play Services absent,
  /// no update available, a sideloaded/non-Play install, or the user
  /// dismissing Play's own sheet.
  Future<bool> _tryImmediateInAppUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }
      if (info.immediateUpdateAllowed != true) return false;
      await InAppUpdate.performImmediateUpdate();
      // performImmediateUpdate only returns normally when Play handled the
      // flow; the process is typically restarted by Play on success.
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openStoreListing() async {
    final url = await widget.service.storeUrl();
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenStore)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      // System back must not bypass a mandatory update.
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
                    Icons.system_update_alt_rounded,
                    size: 96,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.updateRequiredTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    // Backend copy wins when supplied for this locale, so the
                    // reason can be tailored per rollout without a release.
                    _remoteMessage ?? l10n.updateRequiredBody,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _busy ? null : _updateNow,
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
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            l10n.updateNow,
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

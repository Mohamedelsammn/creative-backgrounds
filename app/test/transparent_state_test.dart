import 'package:creativebackground/features/transparent_wallpaper/data/models/tw_status_model.dart';
import 'package:creativebackground/features/transparent_wallpaper/domain/entities/tw_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests for the transparent-wallpaper state mapping.
///
/// The native `TransparentWallpaperManager.State` enum is the source of truth
/// and crosses the channel as its lower-cased name. If the two ever drift, the
/// UI silently falls back to `idle` - which is exactly how a feature ends up
/// looking "off" while the camera is running. These pin the wire contract.
void main() {
  /// Every wire name the native state machine can emit.
  const nativeWireNames = <String>[
    'idle',
    'checking',
    'incompatible',
    'permission_needed',
    'ready',
    'preparing',
    'preview',
    'applying',
    'running',
    'paused',
    'stopping',
    'restoring',
    'stopped',
    'recovering',
    'camera_busy',
    'camera_lost',
    'wallpaper_removed',
    'error',
    'completed',
  ];

  group('wire mapping', () {
    test('every native state maps to a distinct TwStatus', () {
      final mapped = nativeWireNames.map(TwStatusModel.statusFrom).toList();

      // No name may silently collapse to the `idle` fallback except 'idle'.
      for (var i = 0; i < nativeWireNames.length; i++) {
        if (nativeWireNames[i] == 'idle') continue;
        expect(
          mapped[i],
          isNot(TwStatus.idle),
          reason: '"${nativeWireNames[i]}" fell through to the idle fallback - '
              'the Dart enum is missing a case for it',
        );
      }
      expect(mapped.toSet(), hasLength(nativeWireNames.length));
    });

    test('the Dart enum has no value the native side cannot produce', () {
      final reachable = nativeWireNames.map(TwStatusModel.statusFrom).toSet();
      expect(
        TwStatus.values.toSet().difference(reachable),
        isEmpty,
        reason: 'a TwStatus exists that native can never emit',
      );
    });

    test('an unknown state degrades to idle rather than throwing', () {
      expect(TwStatusModel.statusFrom('something_new'), TwStatus.idle);
      expect(TwStatusModel.statusFrom(null), TwStatus.idle);
    });

    test('reads the full status payload including pendingApply', () {
      final state = TwStatusModel.fromMap({
        'state': 'applying',
        'error': null,
        'running': false,
        'enabled': false,
        'pendingApply': true,
      });
      expect(state.status, TwStatus.applying);
      expect(state.pendingApply, isTrue);
      expect(state.enabled, isFalse);
    });

    test('a payload missing pendingApply defaults it to false', () {
      final state = TwStatusModel.fromMap({'state': 'running'});
      expect(state.pendingApply, isFalse);
    });
  });

  group('derived flags', () {
    test('pending apply is busy but NOT active', () {
      // The whole point of splitting the two flags: while the system picker is
      // open the feature must show progress without claiming to be on.
      const state = TwRuntimeState(
        status: TwStatus.applying,
        pendingApply: true,
      );
      expect(state.isBusy, isTrue);
      expect(state.isActive, isFalse);
    });

    test('enabled is active even when the status has not caught up', () {
      // After a process kill the wallpaper still runs while in-memory state
      // has reset to idle; the persisted flag is what keeps the UI honest.
      const state = TwRuntimeState(status: TwStatus.idle, enabled: true);
      expect(state.isActive, isTrue);
    });

    test('paused and recovering are still active', () {
      const paused = TwRuntimeState(status: TwStatus.paused);
      const recovering = TwRuntimeState(status: TwStatus.recovering);
      expect(paused.isActive, isTrue);
      expect(recovering.isActive, isTrue);
    });

    test('teardown states are busy but not active', () {
      const stopping = TwRuntimeState(status: TwStatus.stopping);
      const restoring = TwRuntimeState(status: TwStatus.restoring);
      expect(stopping.isBusy, isTrue);
      expect(restoring.isBusy, isTrue);
      expect(stopping.isActive, isFalse);
      expect(restoring.isActive, isFalse);
    });

    test('stopped is neither busy nor active', () {
      const state = TwRuntimeState(status: TwStatus.stopped);
      expect(state.isBusy, isFalse);
      expect(state.isActive, isFalse);
      expect(state.isError, isFalse);
    });

    test('camera failures are reported as errors', () {
      for (final status in [
        TwStatus.error,
        TwStatus.cameraBusy,
        TwStatus.cameraLost,
      ]) {
        expect(TwRuntimeState(status: status).isError, isTrue);
      }
    });

    test('recovering is not yet an error - a retry is still pending', () {
      const state = TwRuntimeState(status: TwStatus.recovering);
      expect(state.isError, isFalse);
    });
  });
}

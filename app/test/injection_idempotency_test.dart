import 'package:creativebackground/features/explore/presentation/bloc/explore_bloc.dart';
import 'package:creativebackground/injection.dart' as di;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test: `setupDI()` must be safe to call more than once within
/// the same running Dart VM. Android can re-enter `main()` (and therefore
/// `setupDI()`) without tearing down the Flutter engine/VM in some Activity-
/// recreation scenarios - without the `isRegistered` guard, GetIt throws on
/// the very first duplicate registration, before `runApp`/`SplashBloc` can
/// ever be (re)built, which leaves the app stuck on whatever was last drawn
/// (indistinguishable from being permanently stuck on the splash screen).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // ExploreBloc's dependency chain reads AppConfig.mockApi, which reads
    // dotenv - never loaded from a real .env file in a unit test, so this
    // stands in for it.
    dotenv.testLoad();
  });

  tearDown(() => di.sl.reset());

  test('calling setupDI() twice does not throw', () async {
    await di.setupDI();
    // The bug this guards: without the isRegistered check, this second call
    // throws "type X is already registered inside GetIt".
    await expectLater(di.setupDI(), completes);
  });

  test('every dependency remains resolvable after a second setupDI() call',
      () async {
    await di.setupDI();
    await di.setupDI();

    expect(() => di.sl<ExploreBloc>(), returnsNormally);
  });
}

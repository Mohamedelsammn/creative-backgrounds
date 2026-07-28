import 'package:connectivity_plus/connectivity_plus.dart';

/// Point-in-time connectivity check. The reactive stream lives in
/// `ConnectivityBloc`; repositories use this for one-off "am I online?" checks.
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}

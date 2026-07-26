import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps `connectivity_plus` into a plain `Stream<bool>`, so consumers
/// (SitesCubit's offline banner, the sync queue runner) never touch the
/// plugin's `ConnectivityResult` type directly.
class ConnectivityObserver {
  ConnectivityObserver({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  Future<bool> get isConnected async =>
      _hasConnection(await _connectivity.checkConnectivity());

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}

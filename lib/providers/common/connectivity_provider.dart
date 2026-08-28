import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityProvider() {
    _initConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initConnectivity() async {
    try {
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      debugPrint('Connectivity Error: $e');
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // If results contains none, it's offline. Otherwise, if there is wifi, mobile, or ethernet, it's online.
    _isOnline = results.contains(ConnectivityResult.mobile) ||
               results.contains(ConnectivityResult.wifi) ||
               results.contains(ConnectivityResult.ethernet) ||
               results.contains(ConnectivityResult.vpn);
               
    notifyListeners();
  }
  
  // Method for manual check (onRetry)
  Future<void> checkConnection() async {
    final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    _updateConnectionStatus(results);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

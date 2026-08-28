import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/services/auth/cloud_backup_service.dart';
import 'package:nutriscan/services/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CloudBackupProvider with ChangeNotifier {
  final CloudBackupService _cloudBackupService = CloudBackupService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _isSignedIn = false;
  String? _error;
  Map<String, dynamic>? _backupInfo;
  bool _isInitialized = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  bool get isLoading => _isLoading;
  bool get isSignedIn => _isSignedIn;
  String? get error => _error;
  Map<String, dynamic>? get backupInfo => _backupInfo;
  bool get isInitialized => _isInitialized;
  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring;

  // Initialize the provider
  Future<void> initialize({String language = 'en'}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _cloudBackupService.initialize();
      _isSignedIn = _cloudBackupService.isSignedIn;

      if (_isSignedIn) {
        await _loadBackupInfo();
      }

      // Set up auth state listener for real-time updates
      _setupAuthStateListener();
    } catch (e) {
      _error = AppLocalizations.getString('login_failed', language);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Initialize silently without loading state
  Future<void> initializeSilently() async {
    if (_isInitialized) return;

    try {
      await _cloudBackupService.initialize();
      _isSignedIn = _cloudBackupService.isSignedIn;

      if (_isSignedIn) {
        await _loadBackupInfo();
      }

      // Set up auth state listener for real-time updates
      _setupAuthStateListener();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // Silent initialization error
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle({String language = 'en'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _cloudBackupService.signInWithGoogle();

      // Wait a moment for Firebase auth state to update
      await Future.delayed(const Duration(milliseconds: 1000));

      // Check actual auth state regardless of service result
      final isActuallySignedIn = _auth.currentUser != null;

      if (isActuallySignedIn) {
        _isSignedIn = true;
        await _loadBackupInfo();
        _error = null; // Clear any previous errors
        // Force UI update after successful sign in
        notifyListeners();
        return true;
      } else {
        _error = AppLocalizations.getString('login_failed', language);
        _isSignedIn = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = AppLocalizations.getString('login_failed', language);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut({String language = 'en'}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _cloudBackupService.signOut();

      // Clear local state
      _isSignedIn = false;
      _backupInfo = null;
      _error = null;

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_logged_in', false);

      // Force UI update after successful sign out
      notifyListeners();
    } catch (e) {
      _error = AppLocalizations.getString('login_failed', language);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Backup data to cloud
  Future<bool> backupData({
    bool isPremiumUser = false,
    String language = 'en',
  }) async {
    if (!_isSignedIn) return false;

    // Check if user is premium for backup
    if (!isPremiumUser) {
      _error = AppLocalizations.getString(
        'cloud_backup_premium_only',
        language,
      );
      notifyListeners();
      return false;
    }

    _isBackingUp = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _databaseHelper.backupToCloud(
        isPremiumUser: isPremiumUser,
      );
      if (success) {
        await _loadBackupInfo();
      }
      return success;
    } catch (e) {
      // Use localized error message with fallback
      _error = AppLocalizations.getString('subscription_error', language);
      return false;
    } finally {
      _isBackingUp = false;
      notifyListeners();
    }
  }

  // Restore data from cloud
  Future<bool> restoreData({
    bool isPremiumUser = false,
    String language = 'en',
  }) async {
    if (!_isSignedIn) return false;

    // Check if user is premium for restore
    if (!isPremiumUser) {
      _error = AppLocalizations.getString(
        'cloud_restore_premium_only',
        language,
      );
      notifyListeners();
      return false;
    }

    _isRestoring = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _databaseHelper.restoreFromCloudAndReplace();
      return success;
    } catch (e) {
      // Use localized error message with fallback
      _error = AppLocalizations.getString('subscription_error', language);
      return false;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  // Check if backup exists
  Future<bool> hasBackup() async {
    if (!_isSignedIn) return false;

    try {
      return await _databaseHelper.hasCloudBackup();
    } catch (e) {
      return false;
    }
  }

  // Delete backup
  Future<bool> deleteBackup() async {
    if (!_isSignedIn) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _databaseHelper.deleteCloudBackup();
      if (success) {
        _backupInfo = null;
      }
      return success;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load backup info
  Future<void> _loadBackupInfo() async {
    try {
      _backupInfo = await _databaseHelper.getCloudBackupInfo();
    } catch (e) {
      _backupInfo = null;
    }
  }

  // Refresh backup info
  Future<void> refreshBackupInfo() async {
    if (_isSignedIn) {
      await _loadBackupInfo();
      notifyListeners();
    }
  }

  // Get last backup time
  Future<DateTime?> getLastBackupTime() async {
    try {
      return await _cloudBackupService.getLastBackupTime();
    } catch (e) {
      return null;
    }
  }

  // Set auto backup preference
  Future<void> setAutoBackupEnabled(bool enabled) async {
    try {
      await _cloudBackupService.setAutoBackupEnabled(enabled);
    } catch (e) {
      // Silent error
    }
  }

  // Check if auto backup is enabled
  Future<bool> isAutoBackupEnabled() async {
    try {
      return await _cloudBackupService.isAutoBackupEnabled();
    } catch (e) {
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Set up Firebase Auth state listener for real-time updates
  void _setupAuthStateListener() {
    _auth.authStateChanges().listen((User? user) {
      final wasSignedIn = _isSignedIn;
      _isSignedIn = user != null;

      // Only update UI if state actually changed
      if (wasSignedIn != _isSignedIn) {
        if (_isSignedIn) {
          // User signed in - load backup info
          _loadBackupInfo();
        } else {
          // User signed out - clear backup info
          _backupInfo = null;
          _error = null;
        }
        notifyListeners();
      }
    });
  }
}

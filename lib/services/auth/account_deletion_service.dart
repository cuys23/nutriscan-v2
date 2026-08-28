import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nutriscan/config/firebase_config.dart';
import 'package:nutriscan/services/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Result of an account deletion attempt.
enum AccountDeletionStatus {
  /// Account and all associated data removed.
  success,

  /// No signed-in user was found.
  notSignedIn,

  /// Firebase requires a fresh credential before deleting the account and the
  /// silent re-authentication attempt failed. The caller should ask the user to
  /// sign in again and retry.
  requiresRecentLogin,

  /// Unexpected failure. Cloud data may have been partially removed.
  failed,
}

class AccountDeletionResult {
  const AccountDeletionResult(this.status, {this.message});

  final AccountDeletionStatus status;
  final String? message;

  bool get isSuccess => status == AccountDeletionStatus.success;
}

/// Permanently deletes a user account and every piece of data tied to it.
///
/// Required by App Store Review Guideline 5.1.1(v): an app that supports
/// account creation must also let the user initiate account deletion from
/// inside the app.
///
/// Deletion order matters. Cloud data is removed **before** the Firebase Auth
/// user, because Firestore/Storage security rules require an authenticated
/// `request.auth.uid` that matches the document path. Once the auth user is
/// gone those writes would be permanently rejected and the data orphaned.
///
/// Order:
///   1. Firebase Storage  `food_images/{uid}/**`
///   2. Firestore         `backups/{uid}`
///   3. Firestore         `users/{uid}`
///   4. Firebase Auth user (with silent re-auth if required)
///   5. Local SQLite food history
///   6. Local SharedPreferences
class AccountDeletionService {
  static final AccountDeletionService _instance =
      AccountDeletionService._internal();
  factory AccountDeletionService() => _instance;
  AccountDeletionService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Keys that must survive deletion because they describe the device, not the
  /// user. Everything else in SharedPreferences is wiped.
  static const Set<String> _preservedPrefKeys = {'device_id'};

  Future<AccountDeletionResult> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AccountDeletionResult(AccountDeletionStatus.notSignedIn);
    }

    final uid = user.uid;

    try {
      // ── 1..3 Cloud data (while still authenticated) ──────────────────────
      await _deleteStorageImages(uid);
      await _deleteFirestoreDoc(FirebaseConfig.backupCollection, uid);
      await _deleteFirestoreDoc(FirebaseConfig.usersCollection, uid);

      // ── 4 Auth user ──────────────────────────────────────────────────────
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code != 'requires-recent-login') rethrow;

        final reauthenticated = await _reauthenticate(user);
        if (!reauthenticated) {
          return const AccountDeletionResult(
            AccountDeletionStatus.requiresRecentLogin,
          );
        }
        await _auth.currentUser?.delete();
      }

      // ── 5..6 Local data ──────────────────────────────────────────────────
      await _clearLocalData();

      // Best-effort provider sign-out so no stale session lingers.
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Ignore: the Firebase user is already gone.
      }

      return const AccountDeletionResult(AccountDeletionStatus.success);
    } on FirebaseAuthException catch (e) {
      debugPrint('AccountDeletionService FirebaseAuthException: ${e.code}');
      if (e.code == 'requires-recent-login') {
        return const AccountDeletionResult(
          AccountDeletionStatus.requiresRecentLogin,
        );
      }
      return AccountDeletionResult(
        AccountDeletionStatus.failed,
        message: e.code,
      );
    } catch (e) {
      debugPrint('AccountDeletionService error: $e');
      return AccountDeletionResult(
        AccountDeletionStatus.failed,
        message: e.toString(),
      );
    }
  }

  /// Deletes every object under `food_images/{uid}/`.
  Future<void> _deleteStorageImages(String uid) async {
    try {
      final ref = _storage.ref().child('food_images').child(uid);
      final result = await ref.listAll();

      await Future.wait([
        for (final item in result.items) item.delete(),
      ]);

      for (final prefix in result.prefixes) {
        final nested = await prefix.listAll();
        await Future.wait([
          for (final item in nested.items) item.delete(),
        ]);
      }
    } catch (e) {
      debugPrint('AccountDeletionService: storage cleanup skipped ($e)');
    }
  }

  Future<void> _deleteFirestoreDoc(String collection, String uid) async {
    try {
      await _firestore.collection(collection).doc(uid).delete();
    } catch (e) {
      debugPrint(
          'AccountDeletionService: failed to delete $collection/$uid ($e)');
      rethrow;
    }
  }

  /// Attempts a silent re-authentication using the provider the account was
  /// created with.
  Future<bool> _reauthenticate(User user) async {
    final providerIds = user.providerData.map((p) => p.providerId).toList();

    try {
      if (providerIds.contains('google.com')) {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return false;

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
        return true;
      }

      if (providerIds.contains('apple.com')) {
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        final credential = OAuthProvider('apple.com').credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );
        await user.reauthenticateWithCredential(credential);
        return true;
      }
    } catch (e) {
      debugPrint('AccountDeletionService: re-auth failed ($e)');
      return false;
    }

    return false;
  }

  /// Wipes local food history and all preferences except device-scoped keys.
  Future<void> _clearLocalData() async {
    try {
      await _databaseHelper.deleteAllFoods();
    } catch (e) {
      debugPrint('AccountDeletionService: local DB wipe failed ($e)');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final preserved = <String, String>{};
      for (final key in _preservedPrefKeys) {
        final value = prefs.getString(key);
        if (value != null) preserved[key] = value;
      }

      await prefs.clear();

      for (final entry in preserved.entries) {
        await prefs.setString(entry.key, entry.value);
      }
    } catch (e) {
      debugPrint('AccountDeletionService: prefs wipe failed ($e)');
    }

    // Clear secure storage (subscription cache etc.)
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      debugPrint('AccountDeletionService: secure storage wipe failed ($e)');
    }
  }
}

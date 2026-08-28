import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageService {
  static final FirebaseStorageService _instance =
      FirebaseStorageService._internal();
  factory FirebaseStorageService() => _instance;
  FirebaseStorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload image to Firebase Storage
  Future<String?> uploadImage(File imageFile, String foodId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create unique filename
      final fileName =
          '${foodId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

      // Create reference to the file location
      final ref = _storage
          .ref()
          .child('food_images')
          .child(user.uid)
          .child(fileName);

      // Upload the file
      final uploadTask = ref.putFile(imageFile);

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  // Upload multiple images
  Future<List<String>> uploadImages(
    List<File> imageFiles,
    String foodId,
  ) async {
    final List<String> urls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      final url = await uploadImage(imageFiles[i], '${foodId}_$i');
      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }

  // Delete image from Firebase Storage
  Future<bool> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete multiple images
  Future<bool> deleteImages(List<String> imageUrls) async {
    bool allDeleted = true;

    for (final url in imageUrls) {
      final deleted = await deleteImage(url);
      if (!deleted) {
        allDeleted = false;
      }
    }

    return allDeleted;
  }

  // Get image reference from URL
  Reference? getImageReference(String imageUrl) {
    try {
      return _storage.refFromURL(imageUrl);
    } catch (e) {
      return null;
    }
  }

  // Check if URL is a Firebase Storage URL
  bool isFirebaseStorageUrl(String url) {
    return url.contains('firebasestorage.googleapis.com');
  }

  // Get file size from Firebase Storage
  Future<int?> getFileSize(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      final metadata = await ref.getMetadata();
      return metadata.size;
    } catch (e) {
      return null;
    }
  }

  // Get all images for a user
  Future<List<Reference>> getUserImages() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final ref = _storage.ref().child('food_images').child(user.uid);
      final result = await ref.listAll();

      return result.items;
    } catch (e) {
      return [];
    }
  }

  // Clean up old images (older than specified days)
  Future<int> cleanupOldImages(int daysOld) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final ref = _storage.ref().child('food_images').child(user.uid);
      final result = await ref.listAll();

      int deletedCount = 0;
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      for (final item in result.items) {
        final metadata = await item.getMetadata();
        final created = metadata.timeCreated;

        if (created != null && created.isBefore(cutoffDate)) {
          await item.delete();
          deletedCount++;
        }
      }

      return deletedCount;
    } catch (e) {
      return 0;
    }
  }
}

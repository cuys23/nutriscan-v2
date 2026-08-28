import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  // Generic method for iOS permission handling
  Future<bool> _handleIOSPermission(Permission permission) async {
    // Check current status first
    PermissionStatus status = await permission.status;

    if (status.isDenied) {
      status = await permission.request();
    }

    if (status.isPermanentlyDenied) {
      return false;
    }

    return status.isGranted;
  }

  // Request camera permission with better iOS handling
  Future<bool> requestCameraPermission() async {
    try {
      if (Platform.isIOS) {
        return await _handleIOSPermission(Permission.camera);
      } else {
        // Android permission handling
        PermissionStatus status = await Permission.camera.request();
        return status.isGranted;
      }
    } catch (e) {
      return false;
    }
  }

  // Request storage permission with better iOS handling
  Future<bool> requestStoragePermission() async {
    try {
      if (Platform.isIOS) {
        return await _handleIOSPermission(Permission.photos);
      } else {
        // Android permission handling
        if (await _isAndroid13OrHigher()) {
          PermissionStatus status = await Permission.photos.request();
          return status.isGranted;
        } else {
          PermissionStatus status = await Permission.storage.request();
          return status.isGranted;
        }
      }
    } catch (e) {
      return false;
    }
  }

  // Check if Android version is 13 or higher
  Future<bool> _isAndroid13OrHigher() async {
    try {
      // This is a simple check - in production you might want to use device_info_plus package
      // For now, we'll assume Android 13+ and use the new permissions
      return true;
    } catch (e) {
      return false;
    }
  }

  // Take photo from camera with better error handling
  Future<File?> takePhotoFromCamera() async {
    try {
      bool hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        throw Exception(
          'Camera permission denied. Please enable camera access in Settings.',
        );
      }

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        return File(photo.path);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Pick image from gallery with better error handling
  Future<File?> pickImageFromGallery() async {
    try {
      bool hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        throw Exception(
          'Photo library permission denied. Please enable photo access in Settings.',
        );
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Show image source picker dialog
  Future<File?> showImageSourceDialog() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Check if permissions are granted
  Future<Map<String, bool>> checkPermissions() async {
    try {
      bool cameraGranted = await Permission.camera.isGranted;
      bool photosGranted = await Permission.photos.isGranted;

      return {'camera': cameraGranted, 'photos': photosGranted};
    } catch (e) {
      return {'camera': false, 'photos': false};
    }
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';

/// Image helper utility for managing local and Firebase images
class ImageHelper {
  /// Determines if an image path is a Firebase Storage URL
  static bool isFirebaseUrl(String imagePath) {
    return imagePath.startsWith('http') &&
        (imagePath.contains('firebasestorage.googleapis.com') ||
            imagePath.contains('googleapis.com'));
  }

  /// Determines if an image path is any HTTP/HTTPS URL
  static bool isNetworkUrl(String imagePath) {
    return imagePath.startsWith('http://') || imagePath.startsWith('https://');
  }

  /// Determines if an image path is a local file path
  static bool isLocalPath(String imagePath) {
    return !isNetworkUrl(imagePath) && imagePath.isNotEmpty;
  }

  /// Creates appropriate ImageProvider based on image path type
  static ImageProvider? getImageProvider(String imagePath) {
    if (isNetworkUrl(imagePath)) {
      return NetworkImage(imagePath);
    } else if (isLocalPath(imagePath)) {
      return FileImage(File(imagePath));
    } else {
      // Return null for invalid paths - will be handled by error widget
      return null;
    }
  }

  /// Creates appropriate DecorationImage based on image path type
  static DecorationImage? getDecorationImage(
    String imagePath, {
    BoxFit fit = BoxFit.cover,
    String? placeholderAsset,
  }) {
    final imageProvider = getImageProvider(imagePath);
    if (imageProvider == null) return null;

    return DecorationImage(
      image: imageProvider,
      fit: fit,
      onError: placeholderAsset != null
          ? (exception, stackTrace) {
              // Handle error by using placeholder
            }
          : null,
    );
  }

  /// Creates appropriate Image widget based on image path type
  static Widget getImageWidget(
    String imagePath, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    String? placeholderAsset,
    Widget? errorWidget,
  }) {
    if (isNetworkUrl(imagePath)) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ??
              Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: const Icon(
                  IconlyLight.danger,
                  color: Colors.red,
                  size: 48,
                ),
              );
        },
      );
    } else if (isLocalPath(imagePath)) {
      return Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ??
              Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: const Icon(
                  IconlyLight.danger,
                  color: Colors.red,
                  size: 48,
                ),
              );
        },
      );
    } else {
      // Return placeholder widget with icon
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: const Icon(IconlyLight.image, color: Colors.grey, size: 48),
      );
    }
  }

  /// Checks if a local file exists
  static bool localFileExists(String imagePath) {
    if (!isLocalPath(imagePath)) return false;
    return File(imagePath).existsSync();
  }

  /// Gets the appropriate image source type
  static ImageSource getImageSource(String imagePath) {
    if (isNetworkUrl(imagePath)) {
      return ImageSource.network;
    } else if (isLocalPath(imagePath)) {
      return ImageSource.file;
    } else {
      return ImageSource.asset;
    }
  }

  /// Validates if an image path is valid
  static bool isValidImagePath(String imagePath) {
    if (imagePath.isEmpty) return false;

    if (isNetworkUrl(imagePath)) {
      return true; // Assume network URLs are valid
    } else if (isLocalPath(imagePath)) {
      return localFileExists(imagePath);
    }

    return false;
  }

  /// Creates a placeholder widget for missing images
  static Widget getPlaceholderWidget({double? width, double? height}) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Icon(IconlyLight.image, color: Colors.grey, size: 48),
    );
  }
}

/// Enum for image source types
enum ImageSource { network, file, asset }

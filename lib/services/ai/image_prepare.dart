import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Pure image resize/encode for the vision path — no network, no Firebase.
///
/// A raw camera photo is 5-10MB; base64 inflates it by another third and the
/// whole thing has to travel client -> Cloud Function -> OpenRouter, so an
/// uncompressed payload is both slow and billed as far more image tokens than
/// the model needs. Resizing to a 1024px max side at JPEG quality 75 lands
/// comfortably under 1MB while staying legible enough to identify a dish.
class ImagePrepare {
  ImagePrepare._();

  static const int _maxImageSide = 1024;
  static const int _jpegQuality = 75;

  /// Returns a ready-to-send `data:` URL for [imageFile].
  ///
  /// Always re-encodes to JPEG, so the returned mime type is always
  /// `image/jpeg` — deriving the mime from the file extension instead would
  /// label a re-encoded `.png` as `image/png` and hand the model a payload
  /// whose declared type does not match its bytes.
  ///
  /// Falls back to the original bytes (with the extension-derived mime) only
  /// when decoding fails, so an unsupported-but-valid image still gets a
  /// chance rather than failing the scan outright.
  static Future<String> processAndEncodeImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final originalKB = bytes.length ~/ 1024;

    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        debugPrint('[img] decode failed, sending raw ${originalKB}KB');
        return 'data:${_mimeTypeFromFile(imageFile)};base64,${base64Encode(bytes)}';
      }

      img.Image resized = decoded;
      if (decoded.width > _maxImageSide || decoded.height > _maxImageSide) {
        final isLandscape = decoded.width > decoded.height;
        resized = img.copyResize(
          decoded,
          width: isLandscape ? _maxImageSide : null,
          height: isLandscape ? null : _maxImageSide,
        );
      }

      final compressed = img.encodeJpg(resized, quality: _jpegQuality);
      debugPrint(
        '[img] ${decoded.width}x${decoded.height} ${originalKB}KB'
        ' → ${resized.width}x${resized.height} ${compressed.length ~/ 1024}KB',
      );
      return 'data:image/jpeg;base64,${base64Encode(compressed)}';
    } catch (e) {
      debugPrint('[img] compression failed, sending raw ${originalKB}KB: $e');
      return 'data:${_mimeTypeFromFile(imageFile)};base64,${base64Encode(bytes)}';
    }
  }

  static String _mimeTypeFromFile(File file) {
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

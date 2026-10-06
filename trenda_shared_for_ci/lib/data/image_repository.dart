// ============================================================================
// FILE: trenda_shared/lib/data/image_repository.dart
// Centralized image upload/delete via Cloudinary backend
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../core/exceptions.dart';
import '../core/images/picked_image.dart';
import 'base_repository.dart';

/// Centralized repository for image operations via Cloudinary backend
class ImageRepository extends BaseRepository {
  ImageRepository({super.baseUrl});

  // ============================================================================
  // UPLOAD METHODS
  // ============================================================================

  /// Upload a general image
  /// [imageData] can be a PickedImage, Uint8List, XFile, File, base64 string, or URL
  /// [folder] is the Cloudinary folder (e.g., 'products', 'users', 'deliveries')
  Future<ImageUploadResult> uploadImage({
    required dynamic imageData,
    String folder = 'general',
  }) async {
    try {
      return await retryRequest(() async {
        final token = await getIdToken();
        final uri = Uri.parse('$baseUrl/api/upload/image');

        final base64Image = await imageDataToDataUri(imageData);

        final response = await http
            .post(
              uri,
              headers: headers(token),
              body: jsonEncode({'image': base64Image, 'folder': folder}),
            )
            .timeout(AppConfig.connectTimeout);

        final body = parseResponse(response);
        return ImageUploadResult.fromJson(body['data'] ?? body);
      });
    } on ImageUploadException {
      rethrow;
    } catch (e) {
      if (e is AuthenticationException) rethrow;
      throw ImageUploadException('Image upload failed. Please try again.', e);
    }
  }

  /// Upload product image
  Future<ImageUploadResult> uploadProductImage({
    required dynamic imageData,
    required String productId,
  }) async {
    try {
      return await retryRequest(() async {
        final token = await getIdToken();
        final uri = Uri.parse('$baseUrl/api/upload/product/$productId');

        final base64Image = await imageDataToDataUri(imageData);

        final response = await http
            .post(
              uri,
              headers: headers(token),
              body: jsonEncode({'image': base64Image}),
            )
            .timeout(AppConfig.connectTimeout);

        final body = parseResponse(response);
        return ImageUploadResult.fromJson(body['data'] ?? body);
      });
    } on ImageUploadException {
      rethrow;
    } catch (e) {
      if (e is AuthenticationException) rethrow;
      throw ImageUploadException('Image upload failed. Please try again.', e);
    }
  }

  /// Upload proof of delivery image
  Future<ImageUploadResult> uploadProofOfDelivery({
    required dynamic imageData,
    required String orderId,
  }) async {
    try {
      return await retryRequest(() async {
        final token = await getIdToken();
        final uri = Uri.parse('$baseUrl/api/upload/delivery/$orderId');

        final base64Image = await imageDataToDataUri(imageData);

        final response = await http
            .post(
              uri,
              headers: headers(token),
              body: jsonEncode({'image': base64Image}),
            )
            .timeout(AppConfig.connectTimeout);

        final body = parseResponse(response);
        return ImageUploadResult.fromJson(body['data'] ?? body);
      });
    } on ImageUploadException {
      rethrow;
    } catch (e) {
      if (e is AuthenticationException) rethrow;
      throw ImageUploadException('Image upload failed. Please try again.', e);
    }
  }

  /// Upload user avatar
  Future<ImageUploadResult> uploadAvatar({required dynamic imageData}) async {
    try {
      return await retryRequest(() async {
        final token = await getIdToken();
        final uri = Uri.parse('$baseUrl/api/upload/avatar');

        final base64Image = await imageDataToDataUri(imageData);

        final response = await http
            .post(
              uri,
              headers: headers(token),
              body: jsonEncode({'image': base64Image}),
            )
            .timeout(AppConfig.connectTimeout);

        final body = parseResponse(response);
        return ImageUploadResult.fromJson(body['data'] ?? body);
      });
    } on ImageUploadException {
      rethrow;
    } catch (e) {
      if (e is AuthenticationException) rethrow;
      throw ImageUploadException('Image upload failed. Please try again.', e);
    }
  }

  /// Upload multiple images
  Future<List<ImageUploadResult>> uploadMultipleImages({
    required List<dynamic> images,
    String folder = 'general',
  }) async {
    final results = <ImageUploadResult>[];
    for (final image in images) {
      final result = await uploadImage(imageData: image, folder: folder);
      results.add(result);
    }
    return results;
  }

  /// Upload an image for the guest vendor application (no auth).
  Future<ImageUploadResult> uploadGuestImage({
    required dynamic imageData,
    String type = 'id_front',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/upload/guest');
      final base64Image = await imageDataToDataUri(imageData);
      final response = await http
          .post(uri,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode({'image': base64Image, 'type': type}))
          .timeout(AppConfig.connectTimeout);
      final body = parsePublicResponse(response);
      return ImageUploadResult.fromJson(body['data'] ?? body);
    } on ImageUploadException {
      rethrow;
    } catch (e) {
      throw ImageUploadException('Image upload failed. Please try again.', e);
    }
  }

  // ============================================================================
  // DELETE METHODS
  // ============================================================================

  /// Delete an image by public ID
  Future<bool> deleteImage(String publicId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/upload/$publicId');

      final response = await http
          .delete(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
      return true;
    });
  }
}

// ============================================================================
// RESULT TYPES
// ============================================================================

class ImageUploadResult {
  final String url;
  final String? publicId;

  /// Set when the upload was stored PRIVATELY (identity documents, receipts): there is no
  /// readable URL for it, and this reference is what gets stored and later signed for an
  /// admin. See trenda_backend/utils/documentRefs.js.
  final String? documentRef;
  final int? width;
  final int? height;
  final String? format;
  final int? bytes;

  ImageUploadResult({
    required this.url,
    this.publicId,
    this.documentRef,
    this.width,
    this.height,
    this.format,
    this.bytes,
  });

  factory ImageUploadResult.fromJson(Map<String, dynamic> json) {
    return ImageUploadResult(
      url: json['url'] ?? json['secure_url'] ?? '',
      publicId: json['publicId'] ?? json['public_id'],
      documentRef: json['documentRef'],
      width: json['width'],
      height: json['height'],
      format: json['format'],
      bytes: json['bytes'],
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'publicId': publicId,
    'width': width,
    'height': height,
    'format': format,
    'bytes': bytes,
  };
}

/// Thrown when an image upload fails. `toString()` is snackbar-friendly.
class ImageUploadException implements Exception {
  final String message;
  final Object? cause;
  ImageUploadException(this.message, [this.cause]);
  @override
  String toString() => message;
}

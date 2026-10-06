import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';

/// A platform-neutral picked image: raw bytes + metadata.
/// Built from XFile bytes so it works identically on web and mobile
/// (never wraps a dart:io File path).
class PickedImage {
  final Uint8List bytes;
  final String filename;
  final String mimeType;

  const PickedImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  /// Build a PickedImage from an image_picker/cross_file XFile, reading its
  /// bytes (web + mobile safe — never touches a dart:io path).
  static Future<PickedImage> fromXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    return PickedImage(
      bytes: bytes,
      filename: file.name,
      mimeType: mimeTypeForFilename(file.name),
    );
  }

  int get sizeBytes => bytes.length;
}

/// Derive a MIME type from a filename's extension. Defaults to image/jpeg.
String mimeTypeForFilename(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    default:
      return 'image/jpeg';
  }
}

/// Build a base64 `data:` URI from raw bytes (the form the backend accepts).
String buildDataUri(Uint8List bytes, String mimeType) =>
    'data:$mimeType;base64,${base64Encode(bytes)}';

/// Convert any supported image input into a base64 `data:` URI.
/// Accepts PickedImage (preferred), Uint8List, XFile, dart:io File (mobile
/// legacy), or an already-encoded String. Bytes-based → web-safe.
Future<String> imageDataToDataUri(dynamic imageData) async {
  if (imageData is PickedImage) {
    return buildDataUri(imageData.bytes, imageData.mimeType);
  }
  if (imageData is Uint8List) {
    return buildDataUri(imageData, 'image/jpeg');
  }
  if (imageData is XFile) {
    final bytes = await imageData.readAsBytes();
    return buildDataUri(bytes, mimeTypeForFilename(imageData.name));
  }
  if (imageData is File) {
    final bytes = await imageData.readAsBytes();
    return buildDataUri(bytes, mimeTypeForFilename(imageData.path));
  }
  if (imageData is String) {
    return imageData;
  }
  throw ArgumentError('Unsupported imageData type: ${imageData.runtimeType}');
}

import 'package:flutter/services.dart';

/// Thin wrapper over a host-app MethodChannel that opens the device's Gallery
/// app via the legacy `ACTION_PICK` MediaStore intent and returns a file path.
///
/// Why this exists: on some OEM/ColorOS ROMs the modern system Photo Picker
/// crashes ("Volume external_primary not found"), and the safe fallbacks
/// (ACTION_GET_CONTENT / SAF) open the Files/Recent browser instead of the
/// Photos grid, because those ROMs' Gallery app only registers for ACTION_PICK.
///
/// The native handler is registered per app in its MainActivity. If an app has
/// NOT registered it, [pickImagePath] throws [MissingPluginException] and the
/// caller falls back to file_picker.
class NativeGallery {
  static const MethodChannel _channel = MethodChannel('trenda/native_gallery');

  /// Opens the device Gallery and returns the absolute path of a cached copy of
  /// the picked image, or `null` if the user cancelled.
  ///
  /// Throws [MissingPluginException] when the host app has no native handler
  /// (caller should fall back), or [PlatformException] on a native error.
  static Future<String?> pickImagePath() {
    return _channel.invokeMethod<String>('pickImage');
  }

  /// Opens the device Gallery in multi-select mode (ACTION_PICK +
  /// EXTRA_ALLOW_MULTIPLE) and returns the absolute paths of cached copies of
  /// the picked images, or an empty list if the user cancelled.
  ///
  /// Throws [MissingPluginException] when the host app has no native handler
  /// (caller should fall back), or [PlatformException] on a native error.
  static Future<List<String>> pickImagePaths() async {
    final res = await _channel.invokeMethod<List<dynamic>>('pickImages');
    return res?.cast<String>() ?? <String>[];
  }
}

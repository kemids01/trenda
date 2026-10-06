import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import '../logger.dart';
import 'native_gallery.dart';
import 'picked_image.dart';

/// Cross-platform image picking. Uses file_picker for gallery (more reliable
/// on Android) and image_picker for camera. Returns bytes-based PickedImage
/// and never throws (returns null / skips on cancel or error).
///
/// IMPORTANT: We use FileType.custom with image extensions instead of
/// FileType.image because FileType.image triggers native image compression
/// in the file_picker plugin, which crashes on some Android OEMs (OPPO/Realme)
/// due to missing temp directories.
///
/// IMPORTANT (gallery path): on Android we pick gallery images via file_picker
/// (SAF / ACTION_OPEN_DOCUMENT), NOT image_picker's gallery source. The Android
/// system Photo Picker (com.google.android.providers.media.module:PhotoPicker)
/// crashes with `IllegalArgumentException: Volume external_primary not found`
/// on some OEM/ColorOS ROMs — an uncatchable crash in another process that
/// tears down our task so the app "closes" on a gallery pick. SAF avoids that
/// MediaProvider path entirely. The Photo Picker is therefore disabled (see
/// configureAndroidPhotoPicker). image_picker is still used for CAMERA capture.
class ImagePickerService {
  static const _imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'bmp'];

  final ImagePicker _cameraPicker;
  ImagePickerService([ImagePicker? picker])
      : _cameraPicker = picker ?? ImagePicker() {
    _ensureAndroidPhotoPickerOnce();
  }

  static bool _androidPhotoPickerConfigured = false;

  /// Public startup hook — call once from `main()` after
  /// `WidgetsFlutterBinding.ensureInitialized()` so the broken Android system
  /// Photo Picker is disabled before any pick. Idempotent; no-op off Android.
  static void ensureConfigured() => _ensureAndroidPhotoPickerOnce();

  /// Disable Android's system Photo Picker for image_picker, once.
  ///
  /// The system Photo Picker crashes on some OEM/ColorOS ROMs with
  /// `IllegalArgumentException: Volume external_primary not found` (thrown in
  /// the separate `...media.module:PhotoPicker` process, so it is uncatchable
  /// and tears down our task — the app "closes" on a gallery pick). We route
  /// gallery picks through file_picker/SAF instead (see `_pickFromGallery`), so
  /// image_picker only needs its default (Photo Picker OFF) for camera capture.
  static void _ensureAndroidPhotoPickerOnce() {
    if (_androidPhotoPickerConfigured) return;
    _androidPhotoPickerConfigured = true;
    try {
      configureAndroidPhotoPicker();
    } catch (e, st) {
      AppLogger.error('ImagePickerService: configureAndroidPhotoPicker failed', e, st);
    }
  }

  /// Forces `useAndroidPhotoPicker = false` when running on Android (the system
  /// Photo Picker is broken on some ROMs — see above). Idempotent and a no-op
  /// on other platforms. Exposed for testing.
  @visibleForTesting
  static void configureAndroidPhotoPicker([ImagePickerPlatform? platform]) {
    final impl = platform ?? ImagePickerPlatform.instance;
    if (impl is ImagePickerAndroid) {
      impl.useAndroidPhotoPicker = false;
    }
  }

  /// Pick a single image from gallery or camera.
  Future<PickedImage?> pickImage({
    ImageSource source = ImageSource.gallery,
    int maxWidth = 1600,
    int quality = 85,
  }) async {
    try {
      if (source == ImageSource.camera) {
        return await _pickFromCamera(maxWidth: maxWidth, quality: quality);
      }
      return await _pickFromGallery(maxWidth: maxWidth, quality: quality);
    } on PlatformException catch (e, st) {
      debugPrint('[ImagePickerService] PlatformException: ${e.code} - ${e.message}');
      AppLogger.error('ImagePickerService.pickImage PlatformException', e, st);
      return null;
    } on MissingPluginException catch (e, st) {
      debugPrint('[ImagePickerService] MissingPluginException: $e');
      AppLogger.error('ImagePickerService.pickImage MissingPlugin', e, st);
      return null;
    } catch (e, st) {
      debugPrint('[ImagePickerService] Unexpected error: $e');
      AppLogger.error('ImagePickerService.pickImage failed', e, st);
      return null;
    }
  }

  /// Pick a single gallery image and return its file PATH (not bytes), for
  /// consumers that need a path — e.g. ML barcode/QR analysis from an image.
  /// Android: native Gallery app, falling back to file_picker/SAF. Other
  /// platforms: image_picker gallery. Returns null on cancel.
  Future<String?> pickGalleryImagePath() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        try {
          // null here means the user cancelled — do NOT fall back.
          return await NativeGallery.pickImagePath();
        } on MissingPluginException {
          // Host app has no native handler → use file_picker.
        } on PlatformException catch (e, st) {
          AppLogger.error(
              'ImagePickerService native gallery error → file_picker', e, st);
        }
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: _imageExtensions,
          withData: false,
        );
        return (result != null && result.files.isNotEmpty)
            ? result.files.first.path
            : null;
      }
      final x = await _cameraPicker.pickImage(source: ImageSource.gallery);
      return x?.path;
    } catch (e, st) {
      AppLogger.error('ImagePickerService.pickGalleryImagePath failed', e, st);
      return null;
    }
  }

  /// Pick multiple gallery images and return their file PATHs (not bytes), for
  /// File-based consumers (e.g. product image grids). Android: file_picker /
  /// SAF (ACTION_OPEN_DOCUMENT + EXTRA_ALLOW_MULTIPLE) — the standard multi-
  /// select API. Other platforms: image_picker multi-select. Returns an
  /// empty list on cancel.
  Future<List<String>> pickMultipleGalleryImagePaths({int maxCount = 10}) async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        // Multi-select via native Gallery (ACTION_PICK + EXTRA_ALLOW_MULTIPLE)
        // is NOT a standard Android API combination — EXTRA_ALLOW_MULTIPLE is
        // only officially supported for ACTION_GET_CONTENT / ACTION_OPEN_DOCUMENT.
        // On OPPO/Realme/ColorOS (e.g. CPH2127), the Gallery app mishandles
        // this: thumbnails render black and selecting an image triggers
        // "error while getting selecting files", returning RESULT_CANCELED.
        // Go straight to file_picker (SAF / ACTION_OPEN_DOCUMENT) which is the
        // correct multi-select API and works reliably across all OEMs.
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: _imageExtensions,
          allowMultiple: true,
          withData: false,
        );
        if (result == null) return [];
        return result.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .take(maxCount)
            .toList();
      }
      final xs = await _cameraPicker.pickMultiImage();
      return xs.map((x) => x.path).take(maxCount).toList();
    } catch (e, st) {
      AppLogger.error(
          'ImagePickerService.pickMultipleGalleryImagePaths failed', e, st);
      return [];
    }
  }

  /// Pick multiple images from gallery.
  Future<List<PickedImage>> pickMultiple({
    int maxCount = 10,
    int maxWidth = 1600,
    int quality = 85,
  }) async {
    try {
      // On Android, use file_picker (SAF / ACTION_OPEN_DOCUMENT) for multi-select
      // via pickMultipleGalleryImagePaths, then read each path to bytes. This
      // avoids the system Photo Picker (crashes on some OEM ROMs) and native
      // Gallery ACTION_PICK multi-select (black thumbnails / selection errors).
      if (!kIsWeb && Platform.isAndroid) {
        final paths = await pickMultipleGalleryImagePaths(maxCount: maxCount);
        final out = <PickedImage>[];
        for (final p in paths) {
          try {
            final file = File(p);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              final name = p.split('/').last;
              out.add(PickedImage(
                bytes: bytes,
                filename: name,
                mimeType: mimeTypeForFilename(name),
              ));
            }
          } catch (e, st) {
            AppLogger.error('ImagePickerService: skip unreadable image', e, st);
          }
        }
        return out;
      }
      debugPrint('[ImagePickerService] pickMultiple via image_picker');
      List<XFile> files;
      try {
        files = await _cameraPicker.pickMultiImage(
          maxWidth: maxWidth.toDouble(),
          maxHeight: maxWidth.toDouble(),
          imageQuality: quality,
        );
      } on PlatformException catch (e, st) {
        debugPrint('[ImagePickerService] image_picker multi failed (${e.code}), '
            'falling back to file_picker');
        AppLogger.error('ImagePickerService pickMultiple fallback to file_picker', e, st);
        return _pickMultipleViaFilePicker(maxCount: maxCount);
      }
      if (files.isEmpty) {
        debugPrint('[ImagePickerService] pickMultiple cancelled');
        return [];
      }
      debugPrint('[ImagePickerService] pickMultiple returned ${files.length} files');
      final limited = files.take(maxCount);
      final out = <PickedImage>[];
      for (final file in limited) {
        try {
          out.add(await PickedImage.fromXFile(file));
        } catch (e, st) {
          AppLogger.error('ImagePickerService: skip unreadable image', e, st);
        }
      }
      return out;
    } on MissingPluginException catch (e, st) {
      debugPrint('[ImagePickerService] MissingPluginException in pickMultiple: $e');
      AppLogger.error('ImagePickerService.pickMultiple MissingPlugin', e, st);
      return [];
    } catch (e, st) {
      debugPrint('[ImagePickerService] Unexpected error in pickMultiple: $e');
      AppLogger.error('ImagePickerService.pickMultiple failed', e, st);
      return [];
    }
  }

  /// Android-only: recover image(s) lost when the OS killed the app's
  /// MainActivity while a picker was open (the classic "app closed on a photo
  /// pick" symptom). Call this on app resume from a screen that was mid-pick;
  /// on iOS/web, or when there is nothing to recover, it returns an empty list.
  /// Never throws.
  ///
  /// See https://pub.dev/packages/image_picker#handling-mainactivity-destruction-on-android
  Future<List<PickedImage>> retrieveLostImages() async {
    if (kIsWeb) return [];
    try {
      if (!Platform.isAndroid) return [];
    } catch (_) {
      return [];
    }
    try {
      final response = await _cameraPicker.retrieveLostData();
      if (response.isEmpty) return [];
      if (response.exception != null) {
        AppLogger.error('ImagePickerService.retrieveLostImages recovered with '
            'exception: ${response.exception!.code}');
      }
      final files = response.files ??
          (response.file != null ? <XFile>[response.file!] : <XFile>[]);
      final out = <PickedImage>[];
      for (final f in files) {
        try {
          out.add(await PickedImage.fromXFile(f));
        } catch (e, st) {
          AppLogger.error(
              'ImagePickerService: skip unreadable recovered image', e, st);
        }
      }
      if (out.isNotEmpty) {
        debugPrint('[ImagePickerService] recovered ${out.length} lost image(s)');
      }
      return out;
    } catch (e, st) {
      AppLogger.error('ImagePickerService.retrieveLostImages failed', e, st);
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Fallback multi-image pick via file_picker for OEMs where image_picker
  /// crashes. Uses FileType.custom to avoid native compression crashes.
  Future<List<PickedImage>> _pickMultipleViaFilePicker({int maxCount = 10}) async {
    debugPrint('[ImagePickerService] _pickMultipleViaFilePicker via file_picker');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _imageExtensions,
      allowMultiple: true,
      withData: false,
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty) {
      debugPrint('[ImagePickerService] pickMultiple cancelled');
      return [];
    }
    final limited = result.files.take(maxCount);
    final out = <PickedImage>[];
    for (final file in limited) {
      try {
        final picked = await _fileToPickedImage(file);
        if (picked != null) out.add(picked);
      } catch (e, st) {
        AppLogger.error('ImagePickerService: skip unreadable image', e, st);
      }
    }
    return out;
  }

  /// Convert a PlatformFile to a PickedImage by reading from path (mobile)
  /// or using bytes (web).
  Future<PickedImage?> _fileToPickedImage(PlatformFile file) async {
    debugPrint('[ImagePickerService] _fileToPickedImage: ${file.name}, path=${file.path}, bytesNull=${file.bytes == null}');

    // On web, bytes are available directly
    if (kIsWeb && file.bytes != null && file.bytes!.isNotEmpty) {
      return PickedImage(
        bytes: file.bytes!,
        filename: file.name,
        mimeType: mimeTypeForFilename(file.name),
      );
    }

    // On mobile, read from file path
    if (file.path != null) {
      final ioFile = File(file.path!);
      if (await ioFile.exists()) {
        final bytes = await ioFile.readAsBytes();
        debugPrint('[ImagePickerService] Read ${bytes.length} bytes from path');
        return PickedImage(
          bytes: bytes,
          filename: file.name,
          mimeType: mimeTypeForFilename(file.name),
        );
      }
    }

    debugPrint('[ImagePickerService] Could not read file: ${file.name}');
    return null;
  }

  /// Gallery pick.
  ///
  /// On Android we go straight to file_picker (SAF / ACTION_OPEN_DOCUMENT):
  /// image_picker's gallery source would open the system Photo Picker, which
  /// crashes ("Volume external_primary not found") on some OEM/ColorOS ROMs and
  /// closes the app (see class docstring). SAF avoids that MediaProvider path.
  /// On iOS/web/desktop the native image_picker gallery is reliable, so we use
  /// it there.
  Future<PickedImage?> _pickFromGallery({
    int maxWidth = 1600,
    int quality = 85,
  }) async {
    if (!kIsWeb && Platform.isAndroid) {
      // Prefer the native Gallery app (ACTION_PICK → Photos grid). Falls back to
      // file_picker/SAF when the host app has no native handler or it errors.
      try {
        final path = await NativeGallery.pickImagePath();
        if (path == null) return null; // cancelled
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final name = path.split('/').last;
          return PickedImage(
            bytes: bytes,
            filename: name,
            mimeType: mimeTypeForFilename(name),
          );
        }
        return _pickFromGalleryViaFilePicker();
      } on MissingPluginException {
        return _pickFromGalleryViaFilePicker();
      } catch (e, st) {
        AppLogger.error(
            'ImagePickerService native gallery failed → file_picker', e, st);
        return _pickFromGalleryViaFilePicker();
      }
    }
    debugPrint('[ImagePickerService] _pickFromGallery via image_picker');
    try {
      final x = await _cameraPicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxWidth.toDouble(),
        imageQuality: quality,
      );
      debugPrint('[ImagePickerService] gallery returned: ${x?.name ?? 'null (cancelled)'}');
      if (x == null) return null;
      return await PickedImage.fromXFile(x);
    } on PlatformException catch (e, st) {
      // OEM-specific gallery/compression crash → fall back to the SAF picker.
      debugPrint('[ImagePickerService] image_picker gallery failed (${e.code}), '
          'falling back to file_picker');
      AppLogger.error('ImagePickerService gallery fallback to file_picker', e, st);
      return _pickFromGalleryViaFilePicker();
    }
  }

  /// Fallback gallery pick via file_picker (reliable on all Android versions).
  /// Uses FileType.custom to avoid native image compression which crashes
  /// on OPPO/Realme/ColorOS devices.
  Future<PickedImage?> _pickFromGalleryViaFilePicker() async {
    debugPrint('[ImagePickerService] _pickFromGalleryViaFilePicker via file_picker');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _imageExtensions,
      allowMultiple: false,
      withData: false,
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty) {
      debugPrint('[ImagePickerService] gallery pick cancelled');
      return null;
    }
    final file = result.files.first;
    debugPrint('[ImagePickerService] gallery picked: ${file.name} (${file.size} bytes)');
    return _fileToPickedImage(file);
  }

  /// Camera capture via image_picker (file_picker doesn't support camera).
  Future<PickedImage?> _pickFromCamera({
    int maxWidth = 1600,
    int quality = 85,
  }) async {
    debugPrint('[ImagePickerService] _pickFromCamera via image_picker');
    final x = await _cameraPicker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxWidth.toDouble(),
      imageQuality: quality,
    );
    debugPrint('[ImagePickerService] camera returned: ${x?.name ?? 'null (cancelled)'}');
    if (x == null) return null;
    return await PickedImage.fromXFile(x);
  }
}

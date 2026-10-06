package com.example.trenda_frontend

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/// Native single-image gallery picker (channel `trenda/native_gallery`,
/// method `pickImage`). Opens the device Gallery via ACTION_PICK and returns a
/// cached file path. Multi-select is handled in Dart via file_picker/SAF — the
/// Gallery apps mishandle EXTRA_ALLOW_MULTIPLE over ACTION_PICK.
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "trenda/native_gallery"
    private val pickRequestCode = 0x6A10
    private val permRequestCode = 0x6A12
    private var pendingResult: MethodChannel.Result? = null

    private val readImagesPermission: String
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            Manifest.permission.READ_MEDIA_IMAGES
        else
            Manifest.permission.READ_EXTERNAL_STORAGE

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickImage" -> startGalleryPick(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun startGalleryPick(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("in_progress", "A gallery pick is already in progress", null)
            return
        }
        pendingResult = result
        // Reading the picked content://media URI needs the media-read permission.
        // Request it first; on denial Dart falls back to file_picker/SAF.
        if (ContextCompat.checkSelfPermission(this, readImagesPermission)
            == PackageManager.PERMISSION_GRANTED) {
            launchGalleryIntent()
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(readImagesPermission), permRequestCode)
        }
    }

    private fun launchGalleryIntent() {
        try {
            // Single-select ACTION_PICK opens the device Gallery (Photos grid).
            // Do NOT add EXTRA_ALLOW_MULTIPLE (Gallery apps render black thumbnails
            // / "error selecting files" and return CANCELED) or
            // FLAG_GRANT_READ_URI_PERMISSION (we don't own the MediaStore URI →
            // SecurityException on launch). Use setDataAndType, NOT `intent.type =`
            // (which clears the data URI and drops us into the Files picker).
            val intent = Intent(Intent.ACTION_PICK)
            intent.setDataAndType(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, "image/*")
            startActivityForResult(intent, pickRequestCode)
        } catch (e: Exception) {
            val r = pendingResult
            pendingResult = null
            r?.error("launch_failed", e.message, null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permRequestCode) return
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            launchGalleryIntent()
        } else {
            val r = pendingResult
            pendingResult = null
            r?.error("permission_denied", "Media read permission denied", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequestCode) return
        val result = pendingResult ?: return
        pendingResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null) // cancelled
            return
        }
        try {
            val uri = data?.data
            if (uri == null) result.success(null) else result.success(copyUriToCache(uri))
        } catch (e: Exception) {
            result.error("read_failed", e.message, null)
        }
    }

    private fun copyUriToCache(uri: Uri): String {
        val mime = contentResolver.getType(uri)
        val ext = when {
            mime == null -> "jpg"
            mime.contains("png") -> "png"
            mime.contains("webp") -> "webp"
            mime.contains("gif") -> "gif"
            else -> "jpg"
        }
        val outFile = File(cacheDir, "gallery_pick_${System.nanoTime()}.$ext")
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(outFile).use { output -> input.copyTo(output) }
        } ?: throw IllegalStateException("Unable to open picked image stream")
        return outFile.absolutePath
    }
}

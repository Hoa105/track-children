package com.example.track_children

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingSave: Pair<File, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "be_lon_khon/photobooth_gallery").setMethodCallHandler { call, result ->
            if (call.method != "saveImage") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val source = try { File(call.argument<String>("path") ?: "").canonicalFile }
                catch (_: Exception) { null }
            val allowedRoot = File(applicationInfo.dataDir).canonicalPath + File.separator
            if (source == null || !source.isFile || !source.path.startsWith(allowedRoot)
                || source.extension.lowercase() != "png") {
                result.error("invalid_file", "Image unavailable", null)
            } else if (Build.VERSION.SDK_INT <= 28 &&
                checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                if (pendingSave != null) {
                    result.error("busy", "Save already pending", null)
                } else {
                    pendingSave = Pair(source, result)
                    requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 704)
                }
            } else { saveImage(source, result) }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 704) return
        val pending = pendingSave ?: return
        pendingSave = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            saveImage(pending.first, pending.second)
        } else { pending.second.error("permission_denied", "Save permission denied", null) }
    }

    @Suppress("DEPRECATION")
    private fun saveImage(source: File, result: MethodChannel.Result) {
        Thread {
            if (Build.VERSION.SDK_INT >= 29) {
                var inserted: android.net.Uri? = null
                try {
                    val values = ContentValues().apply {
                        put(MediaStore.Images.Media.DISPLAY_NAME, "BeLonKhon-${source.name}")
                        put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                        put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/BeLonKhon")
                        put(MediaStore.Images.Media.IS_PENDING, 1)
                    }
                    val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                        ?: throw IllegalStateException("No destination")
                    inserted = uri
                    val output = contentResolver.openOutputStream(uri) ?: throw IllegalStateException("No stream")
                    output.use { stream -> source.inputStream().use { it.copyTo(stream) } }
                    val published = ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }
                    if (contentResolver.update(uri, published, null, null) != 1) throw IllegalStateException("Not published")
                    runOnUiThread { result.success(true) }
                } catch (_: Exception) {
                    inserted?.let { try { contentResolver.delete(it, null, null) } catch (_: Exception) {} }
                    runOnUiThread { result.error("save_failed", "Image not saved", null) }
                }
            } else {
                var destination: File? = null
                try {
                    val folder = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "BeLonKhon")
                    if (!folder.exists() && !folder.mkdirs()) throw IllegalStateException("No directory")
                    val file = File(folder, "BeLonKhon-${java.util.UUID.randomUUID()}.png")
                    destination = file
                    source.inputStream().use { input -> file.outputStream().use { input.copyTo(it) } }
                    MediaScannerConnection.scanFile(this, arrayOf(file.path), arrayOf("image/png")) { _, uri ->
                        if (uri == null) file.delete()
                        runOnUiThread {
                            if (uri != null) result.success(true)
                            else result.error("save_failed", "Image not saved", null)
                        }
                    }
                } catch (_: Exception) {
                    destination?.delete()
                    runOnUiThread { result.error("save_failed", "Image not saved", null) }
                }
            }
        }.start()
    }
}

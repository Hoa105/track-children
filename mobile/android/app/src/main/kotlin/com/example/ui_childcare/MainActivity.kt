package com.example.track_children

import android.content.Intent
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.view.ViewTreeObserver
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.FlutterEngineConfigurator
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener
import io.flutter.embedding.engine.plugins.util.GeneratedPluginRegister
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

class MainActivity : FragmentActivity(), FlutterEngineConfigurator, FlutterUiDisplayListener {
    companion object {
        private const val FLUTTER_CONTAINER = 0x00be1001
        private const val FLUTTER_TAG = "childcare_flutter"
    }
    private lateinit var root: FrameLayout
    private var startView: NativeStartView? = null
    private var flutter: FlutterFragment? = null
    private var flutterVisible = false
    private var contentReady = false
    private var releasing = false
    private var resumed = false
    private val launchStarted = SystemClock.uptimeMillis()
    private val startBars = ViewTreeObserver.OnPreDrawListener {
        if (startView != null) {
            val decor = window.decorView
            val flags = decor.systemUiVisibility or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
            if (flags != decor.systemUiVisibility) decor.systemUiVisibility = flags
            if (window.statusBarColor != NativeStartView.BACKGROUND) window.statusBarColor = NativeStartView.BACKGROUND
            if (window.navigationBarColor != NativeStartView.BACKGROUND) window.navigationBarColor = NativeStartView.BACKGROUND
        }
        true
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        setTheme(R.style.NormalTheme)
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                getSystemService(android.app.NotificationManager::class.java)?.createNotificationChannel(
                    android.app.NotificationChannel(
                        "care_reminders",
                        "Nhắc chăm sóc bé",
                        android.app.NotificationManager.IMPORTANCE_DEFAULT
                    )
                )
            } catch (_: Exception) {}
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.statusBarColor = NativeStartView.BACKGROUND
        window.navigationBarColor = NativeStartView.BACKGROUND
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        root = FrameLayout(this)
        val container = FrameLayout(this).apply { id = FLUTTER_CONTAINER }
        root.addView(container, FrameLayout.LayoutParams(-1, -1))
        // Every new host creates a new engine, including process-death restore.
        // Keep the full cover for that engine instead of restoring a stale released flag.
        startView = NativeStartView(this).also { view ->
            root.addView(view, FrameLayout.LayoutParams(-1, -1))
            view.onFirstDraw = {
                Log.i("StartLaunch", "native_first_frame")
                root.postOnAnimation { attachFlutter() }
            }
        }
        setContentView(root)
        if (startView != null) root.viewTreeObserver.addOnPreDrawListener(startBars)
        flutter = supportFragmentManager.findFragmentByTag(FLUTTER_TAG) as? FlutterFragment
    }

    private fun attachFlutter() {
        if (!resumed || isFinishing || isDestroyed || supportFragmentManager.isStateSaved) return
        if (flutter == null) {
            Log.i("StartLaunch", "flutter_loading_start")
            flutter = FlutterFragment.withNewEngine()
                .dartEntrypointArgs(listOf("native-start"))
                // Texture participates in the normal View hierarchy. A separate
                // SurfaceView layer can punch through an opaque native cover.
                .renderMode(RenderMode.texture)
                .shouldDelayFirstAndroidViewDraw(false)
                .shouldAutomaticallyHandleOnBackPressed(true)
                .build<FlutterFragment>()
            supportFragmentManager.beginTransaction()
                .add(FLUTTER_CONTAINER, flutter!!, FLUTTER_TAG).commitNow()
            // It was attached after the Activity's original onPostResume callback.
            flutter?.onPostResume()
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        resumed = true
        flutter?.onPostResume()
        if (startView?.isLaidOut == true) root.post { attachFlutter() }
        releaseStartIfReady()
    }

    override fun onPause() {
        resumed = false
        super.onPause()
    }

    override fun onFlutterUiDisplayed() {
        flutterVisible = true
        Log.i("StartLaunch", "flutter_first_frame")
        releaseStartIfReady()
    }

    override fun onFlutterUiNoLongerDisplayed() { flutterVisible = false }

    private fun releaseStartIfReady() {
        val cover = startView ?: return
        if (!flutterVisible || !contentReady || !resumed || releasing) return
        releasing = true
        val remaining = (1200L - (SystemClock.uptimeMillis() - launchStarted)).coerceAtLeast(0)
        root.postDelayed({
            if (isDestroyed) return@postDelayed
            // Keep the ready pose visible before uncovering Flutter.
            cover.showWelcome {
                if (isDestroyed) return@showWelcome
                if (!resumed) {
                    releasing = false
                    return@showWelcome
                }
                cover.animate().alpha(0f).setDuration(180).withEndAction {
                    root.removeView(cover)
                    cover.dispose()
                    startView = null
                    root.viewTreeObserver.removeOnPreDrawListener(startBars)
                    Log.i("StartLaunch", "native_cover_removed")
                }.start()
            }
        }, remaining)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        flutter?.onNewIntent(intent)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // Plugins such as image_picker start the picker through the Activity.
        // Its result must reach Flutter's plugin listeners on this custom host.
        flutter?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        flutter?.onUserLeaveHint()
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        flutter?.onTrimMemory(level)
    }

    override fun onDestroy() {
        if (::root.isInitialized) root.viewTreeObserver.removeOnPreDrawListener(startBars)
        startView?.animate()?.cancel()
        startView?.dispose()
        super.onDestroy()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "be_lon_khon/start_launch")
            .setMethodCallHandler(null)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "be_lon_khon/photobooth_gallery")
            .setMethodCallHandler(null)
    }

    private var pendingSave: Pair<File, MethodChannel.Result>? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegister.registerGeneratedPlugins(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "be_lon_khon/start_launch").setMethodCallHandler { call, result ->
            when (call.method) {
                "prepare" -> result.success(mapOf("supported" to false))
                "release" -> result.success(null)
                "contentReady" -> {
                    contentReady = true
                    Log.i("StartLaunch", "flutter_content_ready")
                    result.success(null)
                    releaseStartIfReady()
                }
                else -> result.notImplemented()
            }
        }
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
        flutter?.onRequestPermissionsResult(requestCode, permissions, grantResults)
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

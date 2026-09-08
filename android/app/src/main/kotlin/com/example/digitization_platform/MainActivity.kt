package com.example.digitization_platform

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/**
 * Lets the camera screen treat the volume rocker — and any Bluetooth
 * shutter-remote/selfie-stick that pairs as one, which is how the
 * overwhelming majority of them work — as a physical shutter button instead
 * of the system volume control.
 *
 * Only swallows [KeyEvent.KEYCODE_VOLUME_UP]/[KeyEvent.KEYCODE_VOLUME_DOWN]
 * while [captureButtonArmed] is true (armed/disarmed by Dart's
 * `CaptureButtonChannel` for the lifetime of `CameraCapturePage`) so the
 * volume buttons behave normally everywhere else in the app.
 *
 * Also exposes a second channel (`nilelens/public_downloads`) that copies an
 * already-saved app-private file into the device's public Downloads
 * collection — see Dart's `PublicDownloadsChannel` for why this is
 * Android-only.
 */
class MainActivity : FlutterActivity() {
    private val captureButtonChannelName = "nilelens/capture_button"
    private val publicDownloadsChannelName = "nilelens/public_downloads"
    private val downloadsSubfolder = "NileLens"

    private var captureButtonArmed = false
    private var captureButtonChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val captureChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, captureButtonChannelName)
        captureChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    captureButtonArmed = call.arguments as? Boolean ?: false
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        captureButtonChannel = captureChannel

        val downloadsChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, publicDownloadsChannelName)
        downloadsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "exportToDownloads" -> {
                    val args = call.arguments as? Map<*, *>
                    val sourcePath = args?.get("sourcePath") as? String
                    val displayName = args?.get("displayName") as? String
                    if (sourcePath == null || displayName == null) {
                        result.error(
                            "invalid_args",
                            "sourcePath and displayName are required",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        val savedUri = exportToDownloads(sourcePath, displayName)
                        result.success(savedUri?.toString())
                    } catch (e: IOException) {
                        result.error("export_failed", e.message, null)
                    } catch (e: SecurityException) {
                        result.error("export_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val isShutterKey = event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        if (captureButtonArmed && isShutterKey) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                captureButtonChannel?.invokeMethod("capturePressed", null)
            }
            // Swallow both DOWN and UP: letting UP fall through to the
            // system still nudges the volume/shows its overlay even if DOWN
            // was already consumed.
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    /**
     * Copies [sourcePath] into the public Downloads collection under a
     * dedicated `Download/NileLens/` subfolder, returning the saved item's
     * URI. Android 10+ (API 29+) writes through `MediaStore.Downloads`,
     * which needs no storage permission; earlier versions fall back to a
     * direct file write into the shared Downloads directory.
     */
    private fun exportToDownloads(sourcePath: String, displayName: String): Uri? {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) return null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/zip")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS + File.separator + downloadsSubfolder,
                )
            }
            val itemUri =
                contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: return null
            contentResolver.openOutputStream(itemUri)?.use { out ->
                sourceFile.inputStream().use { input -> input.copyTo(out) }
            } ?: return null
            return itemUri
        }

        // Pre-Android 10: no MediaStore.Downloads collection — scoped
        // storage doesn't apply yet, so a direct write to the shared
        // Downloads directory works without a runtime permission prompt on
        // devices this old (WRITE_EXTERNAL_STORAGE is granted at install
        // time up through API 28).
        val downloadsDir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            downloadsSubfolder,
        )
        if (!downloadsDir.exists()) downloadsDir.mkdirs()
        val destFile = File(downloadsDir, displayName)
        sourceFile.copyTo(destFile, overwrite = true)
        MediaScannerConnection.scanFile(this, arrayOf(destFile.absolutePath), null, null)
        return Uri.fromFile(destFile)
    }
}

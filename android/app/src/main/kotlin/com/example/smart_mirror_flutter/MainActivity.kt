package com.example.smart_mirror_flutter

import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.display.DisplayManager
import android.net.wifi.WifiManager
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter

class MainActivity : FlutterActivity() {

    private val CHANNEL = "smartmirror/native_agent"
    private val EVENT_CHANNEL = "smartmirror/native_agent_events"
    private val DEEP_LINK_CHANNEL = "smartmirror/deeplink"
    private val CRASH_PREFS = "mirror_crash"
    private val CRASH_KEY = "last_crash"
    private val MIRROR_STATUS_PREFS = "mirror_status"
    private val MIRROR_STATUS_KEY = "last_status"
    private val USB_CAPTURE_PREFS = "usb_capture_status"
    private val USB_CAPTURE_STATUS = "status"
    private val USB_CAPTURE_ERROR = "error"
    private val USB_CAPTURE_PATH = "path"
    private val USB_CAPTURE_TIME = "time_ms"

    private lateinit var nativeAgent: NativeAgent
    private lateinit var mirrorDisplayManager: MirrorDisplayManager
    private var multicastLock: WifiManager.MulticastLock? = null
    private var pendingVideoResult: MethodChannel.Result? = null
    private var pendingVideoPath: String? = null
    private val usbCaptureRequestCode = 9021

    // 🔑 Holds QR token when app is opened via QR deep link
    private var initialToken: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val previousHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { t, e ->
            val sw = StringWriter()
            val pw = PrintWriter(sw)
            pw.println("Thread: ${t.name}")
            e.printStackTrace(pw)
            pw.flush()
            getSharedPreferences(CRASH_PREFS, MODE_PRIVATE)
                .edit()
                .putString(CRASH_KEY, sw.toString())
                .apply()
            previousHandler?.uncaughtException(t, e)
        }

        // 🔗 Handle deep link: smartmirror://activate?token=XYZ
        intent?.data?.let { uri ->
            if (uri.scheme == "smartmirror" && uri.host == "activate") {
                initialToken = uri.getQueryParameter("token")
            }
        }

        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        multicastLock = wifi?.createMulticastLock("smartmirror_discovery")
        multicastLock?.setReferenceCounted(false)
        multicastLock?.acquire()
    }

    override fun onDestroy() {
        multicastLock?.release()
        multicastLock = null
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        val displayId = display?.displayId ?: Display.DEFAULT_DISPLAY
        if (::nativeAgent.isInitialized) {
            nativeAgent.setCurrentDisplayId(displayId)
        }
        if (::mirrorDisplayManager.isInitialized) {
            mirrorDisplayManager.setCurrentDisplayId(displayId)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        nativeAgent = NativeAgent.getInstance(this.applicationContext)
        mirrorDisplayManager = MirrorDisplayManager(this)
        val displayId = display?.displayId ?: Display.DEFAULT_DISPLAY
        nativeAgent.setCurrentDisplayId(displayId)
        mirrorDisplayManager.setCurrentDisplayId(displayId)

        // 🔗 Deep link channel → Flutter
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEEP_LINK_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialToken" -> {
                    result.success(initialToken)
                    initialToken = null // consume only once
                }
                else -> result.notImplemented()
            }
        }

        // 🎥 Existing Native Agent channel (UNCHANGED)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    val filename = call.argument<String>("filename") ?: "video.mp4"
                    val success = nativeAgent.startRecording(filename)
                    result.success(success)
                }
                "stopRecording" -> {
                    val path = nativeAgent.stopRecording()
                    result.success(path)
                }
                "preview" -> {
                    nativeAgent.preview()
                    result.success(true)
                }
                "playOnMirror" -> {
                    val path = call.argument<String>("path")
                    val ok = if (path != null) {
                        mirrorDisplayManager.playVideo(path)
                    } else {
                        false
                    }
                    result.success(ok)
                }
                "compareOnMirror" -> {
                    val left = call.argument<String>("left")
                    val right = call.argument<String>("right")
                    val ok = if (left != null && right != null) {
                        mirrorDisplayManager.compareVideos(left, right)
                    } else {
                        false
                    }
                    result.success(ok)
                }
                "showMirrorIdle" -> {
                    val ok = mirrorDisplayManager.showIdle()
                    result.success(ok)
                }
                "hideMirror" -> {
                    mirrorDisplayManager.hideMirror()
                    result.success(true)
                }
                "getDisplayInfo" -> {
                    val dm = getSystemService(DISPLAY_SERVICE) as DisplayManager
                    val presentationIds = dm.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
                        .map { it.displayId }
                        .toSet()
                    val displays = dm.displays
                    val currentId = display?.displayId ?: Display.DEFAULT_DISPLAY
                    val list = displays.map { d ->
                        mapOf(
                            "id" to d.displayId,
                            "name" to d.name,
                            "flags" to d.flags,
                            "state" to d.state,
                            "isPresentation" to presentationIds.contains(d.displayId),
                            "isDefault" to (d.displayId == Display.DEFAULT_DISPLAY)
                        )
                    }
                    result.success(
                        mapOf(
                            "currentDisplayId" to currentId,
                            "presentationIds" to presentationIds.toList(),
                            "displays" to list
                        )
                    )
                }
                "getLastCrash" -> {
                    val text = getSharedPreferences(CRASH_PREFS, MODE_PRIVATE)
                        .getString(CRASH_KEY, null)
                    result.success(text)
                }
                "clearLastCrash" -> {
                    getSharedPreferences(CRASH_PREFS, MODE_PRIVATE)
                        .edit()
                        .remove(CRASH_KEY)
                        .apply()
                    result.success(true)
                }
                "getMirrorStatus" -> {
                    val text = getSharedPreferences(MIRROR_STATUS_PREFS, MODE_PRIVATE)
                        .getString(MIRROR_STATUS_KEY, null)
                    result.success(text)
                }
                "clearMirrorStatus" -> {
                    getSharedPreferences(MIRROR_STATUS_PREFS, MODE_PRIVATE)
                        .edit()
                        .remove(MIRROR_STATUS_KEY)
                        .apply()
                    result.success(true)
                }
                "getLastUsbCaptureStatus" -> {
                    val prefs = getSharedPreferences(USB_CAPTURE_PREFS, MODE_PRIVATE)
                    val status = prefs.getString(USB_CAPTURE_STATUS, null)
                    val error = prefs.getString(USB_CAPTURE_ERROR, null)
                    val path = prefs.getString(USB_CAPTURE_PATH, null)
                    val timeMs = prefs.getLong(USB_CAPTURE_TIME, 0L)
                    result.success(
                        mapOf(
                            "status" to status,
                            "error" to error,
                            "path" to path,
                            "time_ms" to timeMs
                        )
                    )
                }
                "clearLastUsbCaptureStatus" -> {
                    getSharedPreferences(USB_CAPTURE_PREFS, MODE_PRIVATE)
                        .edit()
                        .clear()
                        .apply()
                    result.success(true)
                }
                "getLastRecorded" -> {
                    val path = nativeAgent.getLastRecordedPath()
                    result.success(path)
                }
                "captureUsbVideo" -> {
                    val autoStart = call.argument<Boolean>("auto_start") ?: true
                    launchUsbVideoCapture(result, autoStart)
                }
                "hasExternalCamera" -> {
                    result.success(hasExternalCamera())
                }
                "openNativePlayer" -> {
                    val source = call.argument<String>("source")
                    if (source.isNullOrBlank()) {
                        result.error("missing_source", "source required", null)
                    } else {
                        openNativePlayer(source)
                        result.success(true)
                    }
                }
                "openNativeCompare" -> {
                    val left = call.argument<String>("left")
                    val right = call.argument<String>("right")
                    if (left.isNullOrBlank() || right.isNullOrBlank()) {
                        result.error("missing_sources", "left/right required", null)
                    } else {
                        openNativeCompare(left, right)
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 📡 Existing Event channel (UNCHANGED)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                nativeAgent.setEventSink(events)
            }

            override fun onCancel(arguments: Any?) {
                nativeAgent.setEventSink(null)
            }
        })
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != usbCaptureRequestCode) return
        val response = pendingVideoResult ?: return
        val path = pendingVideoPath
        if (path != null) {
            val file = File(path)
            if (resultCode == RESULT_OK && file.exists() && file.length() > 0L) {
                setUsbCaptureStatus("ok", path, null)
                response.success(path)
            } else {
                val error = data?.getStringExtra(UsbCameraActivity.EXTRA_ERROR)
                if (!error.isNullOrBlank()) {
                    setUsbCaptureStatus("failed", path, error)
                    response.error("capture_failed", error, null)
                } else {
                    setUsbCaptureStatus("canceled", path, null)
                    response.success(null)
                }
            }
        } else {
            setUsbCaptureStatus("canceled", null, "missing_path")
            response.success(null)
        }
        pendingVideoResult = null
        pendingVideoPath = null
    }

    private fun launchUsbVideoCapture(result: MethodChannel.Result, autoStart: Boolean) {
        if (pendingVideoResult != null) {
            result.error("capture_busy", "Capture already in progress", null)
            return
        }
        val dir = getExternalFilesDir("videos") ?: filesDir
        val file = File(dir, "usb_${System.currentTimeMillis()}.mp4")
        val intent = Intent(this, UsbCameraActivity::class.java).apply {
            putExtra(UsbCameraActivity.EXTRA_OUTPUT_PATH, file.absolutePath)
            putExtra(UsbCameraActivity.EXTRA_AUTO_START, autoStart)
        }
        pendingVideoResult = result
        pendingVideoPath = file.absolutePath
        setUsbCaptureStatus("started", file.absolutePath, null)
        try {
            startActivityForResult(intent, usbCaptureRequestCode)
        } catch (e: Exception) {
            setUsbCaptureStatus("launch_failed", file.absolutePath, e.message)
            pendingVideoResult = null
            pendingVideoPath = null
            result.error("capture_error", e.message, null)
        }
    }

    private fun setUsbCaptureStatus(status: String, path: String?, error: String?) {
        getSharedPreferences(USB_CAPTURE_PREFS, MODE_PRIVATE)
            .edit()
            .putString(USB_CAPTURE_STATUS, status)
            .putString(USB_CAPTURE_PATH, path)
            .putString(USB_CAPTURE_ERROR, error)
            .putLong(USB_CAPTURE_TIME, System.currentTimeMillis())
            .apply()
    }

    private fun hasExternalCamera(): Boolean {
        return try {
            val manager = getSystemService(CAMERA_SERVICE) as CameraManager
            for (id in manager.cameraIdList) {
                val chars = manager.getCameraCharacteristics(id)
                val facing = chars.get(CameraCharacteristics.LENS_FACING)
                if (facing == CameraCharacteristics.LENS_FACING_EXTERNAL) {
                    return true
                }
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun openNativePlayer(source: String) {
        val intent = Intent(this, NativeVideoPlayerActivity::class.java).apply {
            putExtra(NativeVideoPlayerActivity.EXTRA_SOURCE, source)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun openNativeCompare(left: String, right: String) {
        val intent = Intent(this, NativeCompareActivity::class.java).apply {
            putExtra(NativeCompareActivity.EXTRA_LEFT, left)
            putExtra(NativeCompareActivity.EXTRA_RIGHT, right)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

}

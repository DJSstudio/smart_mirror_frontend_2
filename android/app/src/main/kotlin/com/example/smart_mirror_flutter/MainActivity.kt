package com.example.smart_mirror_flutter

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Bundle
import android.view.Display
import android.hardware.display.DisplayManager
import java.io.PrintWriter
import java.io.StringWriter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "smartmirror/native_agent"
    private val EVENT_CHANNEL = "smartmirror/native_agent_events"
    private val DEEP_LINK_CHANNEL = "smartmirror/deeplink"
    private val CRASH_PREFS = "mirror_crash"
    private val CRASH_KEY = "last_crash"
    private val MIRROR_STATUS_PREFS = "mirror_status"
    private val MIRROR_STATUS_KEY = "last_status"

    private lateinit var nativeAgent: NativeAgent
    private lateinit var mirrorDisplayManager: MirrorDisplayManager
    private var multicastLock: WifiManager.MulticastLock? = null

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
                "getLastRecorded" -> {
                    val path = nativeAgent.getLastRecordedPath()
                    result.success(path)
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
}

package com.example.smart_mirror_flutter

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "smartmirror/native_agent"
    private val EVENT_CHANNEL = "smartmirror/native_agent_events"
    private val DEEP_LINK_CHANNEL = "smartmirror/deeplink"

    private lateinit var nativeAgent: NativeAgent

    // 🔑 Holds QR token when app is opened via QR deep link
    private var initialToken: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 🔗 Handle deep link: smartmirror://activate?token=XYZ
        intent?.data?.let { uri ->
            if (uri.scheme == "smartmirror" && uri.host == "activate") {
                initialToken = uri.getQueryParameter("token")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        nativeAgent = NativeAgent.getInstance(this.applicationContext)

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
                    val ok = nativeAgent.playVideo(path)
                    result.success(ok)
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

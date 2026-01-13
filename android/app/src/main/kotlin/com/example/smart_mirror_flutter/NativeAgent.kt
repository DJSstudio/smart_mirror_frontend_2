package com.example.smart_mirror_flutter

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.EventChannel
import java.io.File

class NativeAgent private constructor(private val context: Context) {
    private var eventSink: EventChannel.EventSink? = null
    private var lastRecordedPath: String? = null
    private var lastStartMs: Long? = null
    private val mirrorDisplayManager = MirrorDisplayManager(context)

    companion object {
        private var instance: NativeAgent? = null
        fun getInstance(context: Context): NativeAgent {
            if (instance == null) {
                instance = NativeAgent(context)
            }
            return instance!!
        }
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun setCurrentDisplayId(displayId: Int) {
        mirrorDisplayManager.setCurrentDisplayId(displayId)
    }

    // START RECORDING - use CameraX/MediaRecorder in real implementation
    fun startRecording(filename: String): Boolean {
        try {
            val dir = context.getExternalFilesDir("videos") ?: context.filesDir
            val out = File(dir, filename)
            // TODO: start camera + media recorder writing to out.path
            // For now, simulate by marking path
            lastRecordedPath = out.absolutePath
            val startMs = System.currentTimeMillis()
            lastStartMs = startMs
            eventSink?.success(mapOf("event" to "recording_started", "path" to lastRecordedPath, "start_ms" to startMs))
            Log.i("NativeAgent", "startRecording -> ${out.absolutePath}")
            return true
        } catch (e: Exception) {
            eventSink?.error("record_error", e.message, null)
            return false
        }
    }

    // STOP RECORDING - stop recorder and return path
    fun stopRecording(): String? {
        // TODO: stop actual recorder
        val stopMs = System.currentTimeMillis()
        val startMs = lastStartMs
        val payload = mutableMapOf<String, Any?>("event" to "recording_stopped", "path" to lastRecordedPath, "stop_ms" to stopMs)
        if (startMs != null) {
            payload["start_ms"] = startMs
            payload["duration_ms"] = stopMs - startMs
        }
        eventSink?.success(payload)
        lastStartMs = null
        return lastRecordedPath
    }

    fun getLastRecordedPath(): String? {
        return lastRecordedPath
    }

    fun preview() {
        // Optional: show idle view on secondary display
        mirrorDisplayManager.showIdle()
        eventSink?.success(mapOf("event" to "preview_shown"))
    }

    fun playVideo(path: String?): Boolean {
        if (path == null) return false
        val ok = mirrorDisplayManager.playVideo(path)
        if (ok) {
            eventSink?.success(mapOf("event" to "play_started", "path" to path))
        } else {
            eventSink?.error("play_error", "No external display available", null)
        }
        return ok
    }

    fun compareVideos(left: String?, right: String?): Boolean {
        if (left == null || right == null) return false
        val ok = mirrorDisplayManager.compareVideos(left, right)
        if (ok) {
            eventSink?.success(mapOf("event" to "compare_started", "left" to left, "right" to right))
        } else {
            eventSink?.error("compare_error", "No external display available", null)
        }
        return ok
    }

    fun showMirrorIdle(): Boolean {
        return mirrorDisplayManager.showIdle()
    }

    fun hideMirror() {
        mirrorDisplayManager.hideMirror()
    }
}

package com.example.smart_mirror_flutter

import android.content.Context
import android.media.MediaPlayer
import android.util.Log
import io.flutter.plugin.common.EventChannel
import java.io.File

class NativeAgent private constructor(private val context: Context) {
    private var eventSink: EventChannel.EventSink? = null
    private var lastRecordedPath: String? = null
    private var mediaPlayer: MediaPlayer? = null

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

    // START RECORDING - use CameraX/MediaRecorder in real implementation
    fun startRecording(filename: String): Boolean {
        try {
            val dir = context.getExternalFilesDir("videos") ?: context.filesDir
            val out = File(dir, filename)
            // TODO: start camera + media recorder writing to out.path
            // For now, simulate by marking path
            lastRecordedPath = out.absolutePath
            eventSink?.success(mapOf("event" to "recording_started", "path" to lastRecordedPath))
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
        eventSink?.success(mapOf("event" to "recording_stopped", "path" to lastRecordedPath))
        return lastRecordedPath
    }

    fun getLastRecordedPath(): String? {
        return lastRecordedPath
    }

    fun preview() {
        // Optional: show preview activity or push to secondary display
        eventSink?.success(mapOf("event" to "preview_shown"))
    }

    fun playVideo(path: String?): Boolean {
        if (path == null) return false
        try {
            mediaPlayer?.release()
            mediaPlayer = MediaPlayer()
            mediaPlayer?.setDataSource(path)
            mediaPlayer?.isLooping = false
            mediaPlayer?.prepare()
            mediaPlayer?.start()
            eventSink?.success(mapOf("event" to "play_started", "path" to path))
            return true
        } catch (e: Exception) {
            eventSink?.error("play_error", e.message, null)
            return false
        }
    }
}

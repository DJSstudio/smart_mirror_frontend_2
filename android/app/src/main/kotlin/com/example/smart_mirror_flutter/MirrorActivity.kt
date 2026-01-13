package com.example.smart_mirror_flutter

import android.app.Activity
import android.graphics.Color
import android.media.MediaPlayer
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.VideoView

class MirrorActivity : Activity() {

    companion object {
        const val EXTRA_MODE = "mode"
        const val EXTRA_LEFT = "left"
        const val EXTRA_RIGHT = "right"
        const val EXTRA_TARGET_DISPLAY_ID = "target_display_id"

        const val MODE_IDLE = "idle"
        const val MODE_PLAY = "play"
        const val MODE_COMPARE = "compare"

        @Volatile
        private var activeInstance: MirrorActivity? = null

        fun finishIfRunning() {
            activeInstance?.finish()
        }
    }

    private val prefsName = "mirror_status"
    private val prefsKey = "last_status"

    private lateinit var root: FrameLayout
    private var singleView: VideoView? = null
    private var leftView: VideoView? = null
    private var rightView: VideoView? = null
    private var leftPrepared = false
    private var rightPrepared = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        activeInstance = this
        if (!ensureTargetDisplay()) {
            saveStatus("start_failed: wrong_display actual=${display?.displayId} target=${intent.getIntExtra(EXTRA_TARGET_DISPLAY_ID, -1)}")
            finish()
            return
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)

        root = FrameLayout(this)
        root.setBackgroundColor(Color.BLACK)
        setContentView(root)

        applyIntent()
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (!ensureTargetDisplay()) {
            saveStatus("update_failed: wrong_display actual=${display?.displayId} target=${intent.getIntExtra(EXTRA_TARGET_DISPLAY_ID, -1)}")
            finish()
            return
        }
        applyIntent()
    }

    private fun applyIntent() {
        val mode = intent.getStringExtra(EXTRA_MODE) ?: MODE_IDLE
        saveStatus("mode=$mode display=${display?.displayId}")
        when (mode) {
            MODE_PLAY -> playVideo(intent.getStringExtra(EXTRA_LEFT))
            MODE_COMPARE -> compareVideos(
                intent.getStringExtra(EXTRA_LEFT),
                intent.getStringExtra(EXTRA_RIGHT)
            )
            else -> showIdle()
        }
    }

    private fun saveStatus(text: String) {
        getSharedPreferences(prefsName, MODE_PRIVATE)
            .edit()
            .putString(prefsKey, text)
            .apply()
    }

    private fun ensureTargetDisplay(): Boolean {
        val targetId = intent.getIntExtra(EXTRA_TARGET_DISPLAY_ID, -1)
        val actualId = display?.displayId ?: -1
        if (targetId == -1) {
            return false
        }
        return actualId == targetId
    }

    private fun showIdle() {
        clearPlayers()
        root.setBackgroundColor(Color.BLACK)
    }

    private fun playVideo(source: String?) {
        if (source.isNullOrBlank()) {
            showIdle()
            return
        }
        clearPlayers()
        root.setBackgroundColor(Color.BLACK)

        val view = VideoView(this)
        view.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
            Gravity.CENTER
        )

        singleView = view
        root.addView(view)

        prepareVideo(view, source) {
            view.start()
        }
    }

    private fun compareVideos(left: String?, right: String?) {
        if (left.isNullOrBlank() || right.isNullOrBlank()) {
            showIdle()
            return
        }

        clearPlayers()
        root.setBackgroundColor(Color.BLACK)

        val row = LinearLayout(this)
        row.orientation = LinearLayout.HORIZONTAL
        row.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )

        val leftVideo = VideoView(this)
        val rightVideo = VideoView(this)
        leftVideo.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
        rightVideo.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)

        leftView = leftVideo
        rightView = rightVideo
        leftPrepared = false
        rightPrepared = false

        row.addView(leftVideo)
        row.addView(rightVideo)
        root.addView(row)

        prepareVideo(leftVideo, left) {
            leftPrepared = true
            startCompareIfReady()
        }

        prepareVideo(rightVideo, right) {
            rightPrepared = true
            startCompareIfReady()
        }
    }

    private fun startCompareIfReady() {
        if (leftPrepared && rightPrepared) {
            leftView?.seekTo(0)
            rightView?.seekTo(0)
            leftView?.start()
            rightView?.start()
        }
    }

    private fun prepareVideo(view: VideoView, source: String, onPrepared: () -> Unit) {
        if (source.startsWith("http", ignoreCase = true)) {
            view.setVideoURI(Uri.parse(source))
        } else {
            view.setVideoPath(source)
        }

        view.setOnPreparedListener { mp: MediaPlayer ->
            mp.isLooping = false
            onPrepared()
        }

        view.setOnErrorListener { _, _, _ ->
            showIdle()
            true
        }
    }

    private fun clearPlayers() {
        singleView?.stopPlayback()
        leftView?.stopPlayback()
        rightView?.stopPlayback()
        root.removeAllViews()
        singleView = null
        leftView = null
        rightView = null
        leftPrepared = false
        rightPrepared = false
    }

    override fun onDestroy() {
        clearPlayers()
        saveStatus("closed display=${display?.displayId}")
        if (activeInstance === this) {
            activeInstance = null
        }
        super.onDestroy()
    }
}

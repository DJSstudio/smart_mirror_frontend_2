package com.example.smart_mirror_flutter

import android.app.Activity
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.view.TextureView
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.video.VideoSize
import kotlin.math.min

class MirrorActivity : Activity() {

    companion object {
        const val EXTRA_MODE = "mode"
        const val EXTRA_LEFT = "left"
        const val EXTRA_RIGHT = "right"
        const val EXTRA_TARGET_DISPLAY_ID = "target_display_id"

        const val MODE_IDLE = "idle"
        const val MODE_RECORD = "record"
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
    private val settingsPrefs = "mirror_settings"
    private val rotationKey = "mirror_rotation"

    private lateinit var root: FrameLayout
    private var singleView: TextureView? = null
    private var leftView: TextureView? = null
    private var rightView: TextureView? = null
    private var singlePlayer: ExoPlayer? = null
    private var leftPlayer: ExoPlayer? = null
    private var rightPlayer: ExoPlayer? = null

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
            MODE_RECORD -> showRecording()
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

    private fun showRecording() {
        clearPlayers()
        root.setBackgroundColor(Color.BLACK)
        val label = TextView(this).apply {
            text = "Recording..."
            setTextColor(Color.WHITE)
            textSize = 24f
            gravity = Gravity.CENTER
        }
        root.addView(
            label,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )
        )
    }

    private fun playVideo(source: String?) {
        if (source.isNullOrBlank()) {
            showIdle()
            return
        }
        clearPlayers()
        root.setBackgroundColor(Color.BLACK)

        val container = FrameLayout(this)
        container.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        val view = TextureView(this)
        container.addView(
            view,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )
        )
        root.addView(container)
        singleView = view

        singlePlayer = ExoPlayer.Builder(this).build().apply {
            setVideoTextureView(view)
            setMediaItem(MediaItem.fromUri(resolveUri(source)))
            repeatMode = ExoPlayer.REPEAT_MODE_ONE
            playWhenReady = true
            addListener(object : com.google.android.exoplayer2.Player.Listener {
                override fun onVideoSizeChanged(videoSize: VideoSize) {
                    if (videoSize.height <= 0) return
                    val vw = (videoSize.width * videoSize.pixelWidthHeightRatio).toInt()
                    applyRotationAndFit(view, vw, videoSize.height, container)
                }
            })
            prepare()
        }
    }

    private fun compareVideos(left: String?, right: String?) {
        if (left.isNullOrBlank() || right.isNullOrBlank()) {
            showIdle()
            return
        }

        clearPlayers()
        root.setBackgroundColor(Color.BLACK)

        val rotation = getRotationDegrees()
        val verticalSplit = rotation == 90 || rotation == 270

        val row = LinearLayout(this).apply {
            orientation = if (verticalSplit) LinearLayout.VERTICAL else LinearLayout.HORIZONTAL
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        val leftContainer = FrameLayout(this)
        val rightContainer = FrameLayout(this)
        if (verticalSplit) {
            leftContainer.layoutParams =
                LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
            rightContainer.layoutParams =
                LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
        } else {
            leftContainer.layoutParams =
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
            rightContainer.layoutParams =
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
        }

        val leftTexture = TextureView(this)
        val rightTexture = TextureView(this)
        leftContainer.addView(
            leftTexture,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )
        )
        rightContainer.addView(
            rightTexture,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )
        )

        leftView = leftTexture
        rightView = rightTexture

        row.addView(leftContainer)
        row.addView(rightContainer)
        root.addView(row)

        leftPlayer = ExoPlayer.Builder(this).build().apply {
            setVideoTextureView(leftTexture)
            setMediaItem(MediaItem.fromUri(resolveUri(left)))
            repeatMode = ExoPlayer.REPEAT_MODE_ONE
            playWhenReady = true
            addListener(object : com.google.android.exoplayer2.Player.Listener {
                override fun onVideoSizeChanged(videoSize: VideoSize) {
                    if (videoSize.height <= 0) return
                    val vw = (videoSize.width * videoSize.pixelWidthHeightRatio).toInt()
                    applyRotationAndFit(leftTexture, vw, videoSize.height, leftContainer)
                }
            })
            prepare()
        }

        rightPlayer = ExoPlayer.Builder(this).build().apply {
            setVideoTextureView(rightTexture)
            setMediaItem(MediaItem.fromUri(resolveUri(right)))
            repeatMode = ExoPlayer.REPEAT_MODE_ONE
            playWhenReady = true
            addListener(object : com.google.android.exoplayer2.Player.Listener {
                override fun onVideoSizeChanged(videoSize: VideoSize) {
                    if (videoSize.height <= 0) return
                    val vw = (videoSize.width * videoSize.pixelWidthHeightRatio).toInt()
                    applyRotationAndFit(rightTexture, vw, videoSize.height, rightContainer)
                }
            })
            prepare()
        }
    }

    private fun getRotationDegrees(): Int {
        return getSharedPreferences(settingsPrefs, MODE_PRIVATE)
            .getInt(rotationKey, 90)
    }

    private fun applyRotationAndFit(
        view: TextureView,
        videoW: Int,
        videoH: Int,
        container: FrameLayout
    ) {
        if (videoW <= 0 || videoH <= 0) return
        val cw = container.width
        val ch = container.height
        if (cw == 0 || ch == 0) {
            container.post { applyRotationAndFit(view, videoW, videoH, container) }
            return
        }

        val rotation = getRotationDegrees()
        val aspect = videoW.toFloat() / videoH.toFloat()

        var baseW = cw.toFloat()
        var baseH = baseW / aspect
        if (baseH > ch) {
            baseH = ch.toFloat()
            baseW = baseH * aspect
        }

        val lp = FrameLayout.LayoutParams(baseW.toInt(), baseH.toInt(), Gravity.CENTER)
        view.layoutParams = lp
        view.pivotX = baseW / 2f
        view.pivotY = baseH / 2f
        view.rotation = rotation.toFloat()

        if (rotation == 90 || rotation == 270) {
            val uniform = min(cw.toFloat() / baseH, ch.toFloat() / baseW)
            view.scaleX = uniform
            view.scaleY = uniform
        } else {
            view.scaleX = 1f
            view.scaleY = 1f
        }
    }

    private fun clearPlayers() {
        singlePlayer?.release()
        leftPlayer?.release()
        rightPlayer?.release()
        singlePlayer = null
        leftPlayer = null
        rightPlayer = null
        singleView = null
        leftView = null
        rightView = null
        root.removeAllViews()
    }

    private fun resolveUri(source: String): Uri {
        return if (source.startsWith("http", ignoreCase = true)) {
            Uri.parse(source)
        } else {
            Uri.fromFile(java.io.File(source))
        }
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

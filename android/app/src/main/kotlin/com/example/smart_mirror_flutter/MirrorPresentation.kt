package com.example.smart_mirror_flutter

import android.app.Presentation
import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.TextureView
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.video.VideoSize
import kotlin.math.max
import kotlin.math.min

class MirrorPresentation(
    context: Context,
    display: android.view.Display
) : Presentation(context, display) {

    private lateinit var root: FrameLayout
    private var singleView: TextureView? = null
    private var leftView: TextureView? = null
    private var rightView: TextureView? = null
    private var singlePlayer: ExoPlayer? = null
    private var leftPlayer: ExoPlayer? = null
    private var rightPlayer: ExoPlayer? = null
    private val settingsPrefs = "mirror_settings"
    private val rotationKey = "mirror_rotation"
    private val compareFitCropKey = "mirror_compare_fit_crop"
    private val compareCropWidthFactor = 0.7f
    private val compareCropHeightFactor = 0.5f

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        root = FrameLayout(context)
        root.setBackgroundColor(Color.BLACK)
        setContentView(root)
    }

    fun showIdle() {
        clearPlayers()
        root.setBackgroundColor(Color.BLACK)
    }

    fun showRecording() {
        clearPlayers()
        root.setBackgroundColor(Color.BLACK)
        val label = TextView(context).apply {
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

    fun playVideo(source: String) {
        clearPlayers()
        root.setBackgroundColor(Color.BLACK)

        val container = FrameLayout(context)
        container.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        val view = TextureView(context)
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

        singlePlayer = ExoPlayer.Builder(context).build().apply {
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

    fun compareVideos(left: String, right: String) {
        clearPlayers()
        root.setBackgroundColor(Color.BLACK)

        val rotation = getRotationDegrees()
        val verticalSplit = rotation == 90 || rotation == 270

        val row = LinearLayout(context).apply {
            orientation = if (verticalSplit) LinearLayout.VERTICAL else LinearLayout.HORIZONTAL
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        val leftContainer = FrameLayout(context)
        val rightContainer = FrameLayout(context)
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

        val leftTexture = TextureView(context)
        val rightTexture = TextureView(context)
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

        leftPlayer = ExoPlayer.Builder(context).build().apply {
            setVideoTextureView(leftTexture)
            setMediaItem(MediaItem.fromUri(resolveUri(left)))
            repeatMode = ExoPlayer.REPEAT_MODE_ONE
            playWhenReady = true
            addListener(object : com.google.android.exoplayer2.Player.Listener {
                override fun onVideoSizeChanged(videoSize: VideoSize) {
                    if (videoSize.height <= 0) return
                    val vw = (videoSize.width * videoSize.pixelWidthHeightRatio).toInt()
                    applyRotationAndCropCenter(leftTexture, vw, videoSize.height, leftContainer)
                }
            })
            prepare()
        }

        rightPlayer = ExoPlayer.Builder(context).build().apply {
            setVideoTextureView(rightTexture)
            setMediaItem(MediaItem.fromUri(resolveUri(right)))
            repeatMode = ExoPlayer.REPEAT_MODE_ONE
            playWhenReady = true
            addListener(object : com.google.android.exoplayer2.Player.Listener {
                override fun onVideoSizeChanged(videoSize: VideoSize) {
                    if (videoSize.height <= 0) return
                    val vw = (videoSize.width * videoSize.pixelWidthHeightRatio).toInt()
                    applyRotationAndCropCenter(rightTexture, vw, videoSize.height, rightContainer)
                }
            })
            prepare()
        }
    }

    private fun getRotationDegrees(): Int {
        return context.getSharedPreferences(settingsPrefs, Context.MODE_PRIVATE)
            .getInt(rotationKey, 90)
    }

    private fun getCompareFitCrop(): Boolean {
        return context.getSharedPreferences(settingsPrefs, Context.MODE_PRIVATE)
            .getBoolean(compareFitCropKey, true)
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

    private fun applyRotationAndCropCenter(
        view: TextureView,
        videoW: Int,
        videoH: Int,
        container: FrameLayout
    ) {
        if (videoW <= 0 || videoH <= 0) return
        val cw = container.width
        val ch = container.height
        if (cw == 0 || ch == 0) {
            container.post { applyRotationAndCropCenter(view, videoW, videoH, container) }
            return
        }

        val rotation = getRotationDegrees()
        val aspect = videoW.toFloat() / videoH.toFloat()
        val quarterTurn = rotation == 90 || rotation == 270

        if (getCompareFitCrop()) {
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

            val widthScale: Float
            val heightScale: Float
            if (quarterTurn) {
                widthScale = cw.toFloat() / (baseH * compareCropWidthFactor)
                heightScale = ch.toFloat() / (baseW * compareCropHeightFactor)
            } else {
                widthScale = cw.toFloat() / (baseW * compareCropWidthFactor)
                heightScale = ch.toFloat() / (baseH * compareCropHeightFactor)
            }
            val uniform = min(widthScale, heightScale)
            view.scaleX = uniform
            view.scaleY = uniform
            return
        }
        applyRotationAndFit(view, videoW, videoH, container)
    }

    private fun resolveUri(source: String): Uri {
        return if (source.startsWith("http", ignoreCase = true)) {
            Uri.parse(source)
        } else {
            Uri.fromFile(java.io.File(source))
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

    override fun onStop() {
        clearPlayers()
        super.onStop()
    }
}

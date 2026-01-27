package com.example.smart_mirror_flutter

import android.app.Activity
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.TextureView
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.Player
import java.io.File
import kotlin.math.abs

class NativeCompareActivity : Activity() {
    companion object {
        const val EXTRA_LEFT = "left"
        const val EXTRA_RIGHT = "right"
    }

    private lateinit var leftPlayer: ExoPlayer
    private lateinit var rightPlayer: ExoPlayer
    private lateinit var leftView: TextureView
    private lateinit var rightView: TextureView
    private lateinit var playPause: ImageButton
    private lateinit var seekBar: SeekBar
    private lateinit var timeText: TextView
    private val handler = Handler(Looper.getMainLooper())
    private var isSeeking = false
    private var desiredPlaying = true
    private var leftDurationMs: Long = 0L
    private var rightDurationMs: Long = 0L
    private var maxDurationMs: Long = 0L
    private var masterIsLeft: Boolean = true

    private val updateRunnable = object : Runnable {
        override fun run() {
            updateProgress()
            handler.postDelayed(this, 250)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val left = intent.getStringExtra(EXTRA_LEFT)
        val right = intent.getStringExtra(EXTRA_RIGHT)
        if (left.isNullOrBlank() || right.isNullOrBlank()) {
            finish()
            return
        }

        val root = FrameLayout(this)
        root.setBackgroundColor(Color.BLACK)

        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        leftView = TextureView(this)
        rightView = TextureView(this)
        row.addView(leftView, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f))
        row.addView(rightView, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f))

        val videoParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        root.addView(row, videoParams)

        val back = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_menu_revert)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { finish() }
        }
        val backParams = FrameLayout.LayoutParams(100, 100, Gravity.TOP or Gravity.START)
        root.addView(back, backParams)

        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.argb(180, 0, 0, 0))
            setPadding(24, 12, 24, 16)
        }

        val controlRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        playPause = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_media_pause)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { togglePlay() }
        }
        controlRow.addView(playPause, LinearLayout.LayoutParams(100, 100))

        timeText = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 14f
            text = "00:00 / 00:00"
        }
        val timeParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        timeParams.leftMargin = 16
        controlRow.addView(timeText, timeParams)

        seekBar = SeekBar(this)
        seekBar.max = 1
        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser) {
                    val duration = if (maxDurationMs > 0) maxDurationMs else leftPlayer.duration
                    timeText.text = "${formatMs(progress.toLong())} / ${formatMs(duration)}"
                }
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) {
                isSeeking = true
            }

            override fun onStopTrackingTouch(seekBar: SeekBar?) {
                val pos = seekBar?.progress?.toLong() ?: 0L
                seekBoth(pos)
                isSeeking = false
            }
        })

        controls.addView(controlRow)
        controls.addView(seekBar, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        val controlsParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM
        )
        root.addView(controls, controlsParams)

        setContentView(root)

        leftPlayer = ExoPlayer.Builder(this).build()
        rightPlayer = ExoPlayer.Builder(this).build()
        leftPlayer.setVideoTextureView(leftView)
        rightPlayer.setVideoTextureView(rightView)
        leftPlayer.setMediaItem(MediaItem.fromUri(resolveUri(left)))
        rightPlayer.setMediaItem(MediaItem.fromUri(resolveUri(right)))
        leftPlayer.prepare()
        rightPlayer.prepare()
        leftPlayer.playWhenReady = true
        rightPlayer.playWhenReady = true
        desiredPlaying = true

        val listener = object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                playPause.setImageResource(
                    if (isPlaying) android.R.drawable.ic_media_pause
                    else android.R.drawable.ic_media_play
                )
            }
        }
        leftPlayer.addListener(listener)
        rightPlayer.addListener(listener)
    }

    override fun onStart() {
        super.onStart()
        handler.post(updateRunnable)
    }

    override fun onStop() {
        handler.removeCallbacks(updateRunnable)
        super.onStop()
    }

    override fun onDestroy() {
        leftPlayer.release()
        rightPlayer.release()
        super.onDestroy()
    }

    private fun togglePlay() {
        desiredPlaying = !desiredPlaying
        if (desiredPlaying) {
            leftPlayer.play()
            rightPlayer.play()
        } else {
            leftPlayer.pause()
            rightPlayer.pause()
        }
    }

    private fun seekBoth(posMs: Long) {
        updateDurations()
        val master = if (masterIsLeft) leftPlayer else rightPlayer
        val shortPlayer = if (masterIsLeft) rightPlayer else leftPlayer
        val shortDuration = if (masterIsLeft) rightDurationMs else leftDurationMs
        master.seekTo(posMs)
        if (shortDuration > 0) {
            shortPlayer.seekTo(posMs % shortDuration)
        } else {
            shortPlayer.seekTo(posMs)
        }
    }

    private fun updateProgress() {
        if (isSeeking) return
        updateDurations()

        val master = if (masterIsLeft) leftPlayer else rightPlayer
        val shortPlayer = if (masterIsLeft) rightPlayer else leftPlayer
        val masterDuration = if (masterIsLeft) leftDurationMs else rightDurationMs
        val shortDuration = if (masterIsLeft) rightDurationMs else leftDurationMs
        val masterPosition = master.currentPosition

        if (maxDurationMs > 0) {
            seekBar.max = maxDurationMs.toInt()
            seekBar.progress = masterPosition.coerceAtMost(maxDurationMs).toInt()
            timeText.text = "${formatMs(masterPosition)} / ${formatMs(maxDurationMs)}"
        }

        if (desiredPlaying) {
            if (master.playbackState == Player.STATE_ENDED) {
                desiredPlaying = false
                master.pause()
                shortPlayer.pause()
                return
            }

            if (!master.isPlaying) master.play()
            if (shortDuration > 0) {
                if (shortPlayer.playbackState == Player.STATE_ENDED) {
                    shortPlayer.seekTo(0)
                }
                if (!shortPlayer.isPlaying) shortPlayer.play()
            } else if (!shortPlayer.isPlaying) {
                shortPlayer.play()
            }
        } else {
            if (master.isPlaying || shortPlayer.isPlaying) {
                master.pause()
                shortPlayer.pause()
            }
        }

        if (shortDuration > 0) {
            val expectedShortPos = masterPosition % shortDuration
            val diff = abs(expectedShortPos - shortPlayer.currentPosition)
            if (diff > 150) {
                shortPlayer.seekTo(expectedShortPos)
            }
        }
    }

    private fun updateDurations() {
        val leftDur = leftPlayer.duration
        val rightDur = rightPlayer.duration
        if (leftDur > 0) leftDurationMs = leftDur
        if (rightDur > 0) rightDurationMs = rightDur
        val max = maxOf(leftDurationMs, rightDurationMs)
        if (max > 0) {
            maxDurationMs = max
            masterIsLeft = leftDurationMs >= rightDurationMs
        }
    }

    private fun resolveUri(source: String): Uri {
        return if (source.startsWith("http", ignoreCase = true)) {
            Uri.parse(source)
        } else {
            Uri.fromFile(File(source))
        }
    }

    private fun formatMs(ms: Long): String {
        if (ms <= 0) return "00:00"
        val totalSeconds = ms / 1000
        val minutes = (totalSeconds / 60).toInt()
        val seconds = (totalSeconds % 60).toInt()
        return String.format("%02d:%02d", minutes, seconds)
    }
}

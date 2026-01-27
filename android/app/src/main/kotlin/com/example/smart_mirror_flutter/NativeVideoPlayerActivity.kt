package com.example.smart_mirror_flutter

import android.app.Activity
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.TextureView
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.Player
import java.io.File

class NativeVideoPlayerActivity : Activity() {
    companion object {
        const val EXTRA_SOURCE = "source"
    }

    private lateinit var player: ExoPlayer
    private lateinit var textureView: TextureView
    private lateinit var playPause: ImageButton
    private lateinit var seekBar: SeekBar
    private lateinit var timeText: TextView
    private val handler = Handler(Looper.getMainLooper())
    private var isSeeking = false

    private val updateRunnable = object : Runnable {
        override fun run() {
            updateProgress()
            handler.postDelayed(this, 250)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val source = intent.getStringExtra(EXTRA_SOURCE)
        if (source.isNullOrBlank()) {
            finish()
            return
        }

        val root = FrameLayout(this)
        root.setBackgroundColor(Color.BLACK)

        textureView = TextureView(this)
        root.addView(
            textureView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

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

        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        playPause = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_media_pause)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { togglePlay() }
        }
        row.addView(playPause, LinearLayout.LayoutParams(100, 100))

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
        row.addView(timeText, timeParams)

        seekBar = SeekBar(this)
        seekBar.max = 1
        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser) {
                    timeText.text = "${formatMs(progress.toLong())} / ${formatMs(player.duration)}"
                }
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) {
                isSeeking = true
            }

            override fun onStopTrackingTouch(seekBar: SeekBar?) {
                val pos = seekBar?.progress?.toLong() ?: 0L
                player.seekTo(pos)
                isSeeking = false
            }
        })

        controls.addView(row)
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

        player = ExoPlayer.Builder(this).build()
        player.setVideoTextureView(textureView)
        player.setMediaItem(MediaItem.fromUri(resolveUri(source)))
        player.prepare()
        player.playWhenReady = true
        player.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                playPause.setImageResource(
                    if (isPlaying) android.R.drawable.ic_media_pause
                    else android.R.drawable.ic_media_play
                )
            }
        })
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
        player.release()
        super.onDestroy()
    }

    private fun togglePlay() {
        if (player.isPlaying) {
            player.pause()
        } else {
            player.play()
        }
    }

    private fun updateProgress() {
        if (!::player.isInitialized) return
        if (isSeeking) return
        val duration = player.duration
        val position = player.currentPosition
        if (duration > 0) {
            seekBar.max = duration.toInt()
            seekBar.progress = position.toInt()
            timeText.text = "${formatMs(position)} / ${formatMs(duration)}"
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

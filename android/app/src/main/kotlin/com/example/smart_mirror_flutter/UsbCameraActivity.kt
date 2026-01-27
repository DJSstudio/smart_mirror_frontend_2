package com.example.smart_mirror_flutter

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.media.MediaRecorder
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Size
import android.view.Gravity
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.core.app.ActivityCompat
import android.Manifest
import java.io.File
import kotlin.math.abs

class UsbCameraActivity : Activity() {

    companion object {
        const val EXTRA_OUTPUT_PATH = "output_path"
        const val EXTRA_AUTO_START = "auto_start"
        const val EXTRA_ERROR = "error"
        private const val USB_CAPTURE_PREFS = "usb_capture_status"
        private const val USB_CAPTURE_STATUS = "status"
        private const val USB_CAPTURE_ERROR = "error"
        private const val USB_CAPTURE_PATH = "path"
        private const val USB_CAPTURE_TIME = "time_ms"
    }

    private lateinit var textureView: TextureView
    private lateinit var previewLayout: AspectRatioFrameLayout
    private lateinit var recordButton: ImageButton
    private lateinit var backButton: ImageButton
    private lateinit var timerText: TextView
    private lateinit var countdownText: TextView
    private var outputPath: String? = null
    private var autoStart = true

    private var cameraId: String? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var mediaRecorder: MediaRecorder? = null

    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null

    private var previewSize: Size? = null
    private var videoSize: Size? = null
    private var isRecording = false
    private val cameraPermissionRequest = 9001
    private val uiHandler = Handler(Looper.getMainLooper())
    private var countdownValue = 0
    private var recordingStartMs: Long? = null
    private var resultSent = false
    private var previewSizeSet = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        outputPath = intent.getStringExtra(EXTRA_OUTPUT_PATH)
        autoStart = intent.getBooleanExtra(EXTRA_AUTO_START, true)
        if (outputPath.isNullOrEmpty()) {
            finishWithError("missing_output_path")
            return
        }
        writeStatus("activity_created", null, outputPath)

        val root = FrameLayout(this)
        textureView = TextureView(this)
        previewLayout = AspectRatioFrameLayout(this).apply {
            addView(
                textureView,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                )
            )
        }
        root.addView(
            previewLayout,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )
        )

        recordButton = ImageButton(this).apply {
            setImageResource(android.R.drawable.presence_video_online)
            background = ContextCompat.getDrawable(context, android.R.drawable.btn_default)
            setOnClickListener { toggleRecording() }
        }
        val buttonParams = FrameLayout.LayoutParams(160, 160, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL)
        buttonParams.bottomMargin = 40
        root.addView(recordButton, buttonParams)

        backButton = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_menu_revert)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { finish() }
        }
        val backParams = FrameLayout.LayoutParams(100, 100, Gravity.TOP or Gravity.START)
        root.addView(backButton, backParams)

        timerText = TextView(this).apply {
            setTextColor(Color.RED)
            textSize = 16f
            text = "REC 00:00"
            visibility = View.GONE
        }
        val timerParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.START
        )
        timerParams.topMargin = 20
        timerParams.leftMargin = 120
        root.addView(timerText, timerParams)

        countdownText = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 64f
            visibility = View.GONE
        }
        val countdownParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER
        )
        root.addView(countdownText, countdownParams)

        setContentView(root)
    }

    override fun onResume() {
        super.onResume()
        startBackgroundThread()
        if (!hasCameraPermission()) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CAMERA),
                cameraPermissionRequest
            )
            return
        }
        writeStatus("preview_starting", null, outputPath)
        startPreviewIfReady()
    }

    override fun onPause() {
        uiHandler.removeCallbacksAndMessages(null)
        closeCamera()
        stopBackgroundThread()
        super.onPause()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != cameraPermissionRequest) return
        if (hasCameraPermission()) {
            startPreviewIfReady()
        } else {
            finishWithError("camera_permission_denied")
        }
    }

    override fun onBackPressed() {
        if (isRecording) {
            stopRecording()
            return
        }
        super.onBackPressed()
    }

    private val surfaceListener = object : TextureView.SurfaceTextureListener {
        override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
            openCamera(surface, width, height)
        }

        override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {}
        override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {}
        override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean = true
    }

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("UsbCameraThread").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        backgroundThread?.join()
        backgroundThread = null
        backgroundHandler = null
    }

    private fun openCamera(surfaceTexture: SurfaceTexture, width: Int, height: Int) {
        val manager = getSystemService(CAMERA_SERVICE) as CameraManager
        cameraId = chooseCameraId(manager)
        if (cameraId == null) {
            finishWithError("no_camera_id")
            return
        }
        writeStatus("camera_opening", null, outputPath)

        val characteristics = manager.getCameraCharacteristics(cameraId!!)
        val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        val recorderSizes = map?.getOutputSizes(MediaRecorder::class.java)?.toList() ?: emptyList()
        videoSize = chooseVideoSize(recorderSizes)
        previewSize = videoSize

        val size = previewSize
        if (size != null) {
            surfaceTexture.setDefaultBufferSize(size.width, size.height)
            runOnUiThread {
                previewLayout.setAspectRatio(size.width.toFloat() / size.height.toFloat())
                previewLayout.requestLayout()
            }
        }

        manager.openCamera(cameraId!!, object : CameraDevice.StateCallback() {
            override fun onOpened(camera: CameraDevice) {
                cameraDevice = camera
                writeStatus("camera_opened", null, outputPath)
                createPreviewSession()
            }

            override fun onDisconnected(camera: CameraDevice) {
                camera.close()
                cameraDevice = null
                uiHandler.post { finishWithError("camera_disconnected") }
            }

            override fun onError(camera: CameraDevice, error: Int) {
                camera.close()
                cameraDevice = null
                uiHandler.post { finishWithError("camera_error_$error") }
            }
        }, backgroundHandler)
    }

    private fun startPreviewIfReady() {
        if (textureView.isAvailable) {
            val surfaceTexture = textureView.surfaceTexture ?: return
            openCamera(surfaceTexture, textureView.width, textureView.height)
        } else {
            textureView.surfaceTextureListener = surfaceListener
        }
    }

    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    private fun chooseCameraId(manager: CameraManager): String? {
        var fallback: String? = null
        for (id in manager.cameraIdList) {
            val chars = manager.getCameraCharacteristics(id)
            val facing = chars.get(CameraCharacteristics.LENS_FACING)
            if (facing == CameraCharacteristics.LENS_FACING_EXTERNAL) {
                return id
            }
            if (fallback == null) fallback = id
        }
        return fallback
    }

    private fun chooseVideoSize(choices: List<Size>): Size {
        if (choices.isEmpty()) {
            return Size(1280, 720)
        }
        val preferred = choices.firstOrNull { it.width == 1280 && it.height == 720 }
        if (preferred != null) return preferred
        return choices.minBy { abs(it.width - 1280) + abs(it.height - 720) }
    }

    private fun createPreviewSession() {
        val camera = cameraDevice ?: return
        val surfaceTexture = textureView.surfaceTexture ?: return
        val surface = Surface(surfaceTexture)

        val requestBuilder =
            camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                addTarget(surface)
            }

        camera.createCaptureSession(listOf(surface), object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(session: CameraCaptureSession) {
                captureSession = session
                session.setRepeatingRequest(requestBuilder.build(), null, backgroundHandler)
                writeStatus("preview_ready", null, outputPath)
                if (autoStart) {
                    uiHandler.post { startCountdown() }
                }
            }

            override fun onConfigureFailed(session: CameraCaptureSession) {
                uiHandler.post { finishWithError("preview_config_failed") }
            }
        }, backgroundHandler)

        if (!previewSizeSet && previewSize != null) {
            previewSizeSet = true
            val size = previewSize!!
            runOnUiThread {
                previewLayout.setAspectRatio(size.width.toFloat() / size.height.toFloat())
                previewLayout.requestLayout()
            }
        }
    }

    private fun toggleRecording() {
        if (isRecording) {
            stopRecording()
        } else {
            startCountdown()
        }
    }

    private fun startRecording() {
        val camera = cameraDevice ?: return
        val surfaceTexture = textureView.surfaceTexture ?: return
        val size = videoSize ?: return
        val path = outputPath ?: return

        mediaRecorder = MediaRecorder().apply {
            setVideoSource(MediaRecorder.VideoSource.SURFACE)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setOutputFile(path)
            setVideoEncodingBitRate(5_000_000)
            setVideoFrameRate(30)
            setVideoSize(size.width, size.height)
            setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            setOrientationHint(90)
            prepare()
        }

        surfaceTexture.setDefaultBufferSize(size.width, size.height)
        val previewSurface = Surface(surfaceTexture)
        val recorderSurface = mediaRecorder!!.surface

        val requestBuilder =
            camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD).apply {
                addTarget(previewSurface)
                addTarget(recorderSurface)
            }

        camera.createCaptureSession(
            listOf(previewSurface, recorderSurface),
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    captureSession = session
                    session.setRepeatingRequest(requestBuilder.build(), null, backgroundHandler)
                    mediaRecorder?.start()
                    isRecording = true
                    writeStatus("recording_started", null, outputPath)
                    uiHandler.post {
                        recordButton.setImageResource(android.R.drawable.presence_video_busy)
                        timerText.visibility = View.VISIBLE
                        recordingStartMs = System.currentTimeMillis()
                        startTimer()
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    uiHandler.post { finishWithError("record_config_failed") }
                }
            },
            backgroundHandler
        )
    }

    private fun stopRecording() {
        if (!isRecording) return
        try {
            captureSession?.stopRepeating()
        } catch (_: Exception) {}
        try {
            mediaRecorder?.stop()
        } catch (_: Exception) {}
        mediaRecorder?.reset()
        mediaRecorder?.release()
        mediaRecorder = null
        isRecording = false
        writeStatus("recording_stopped", null, outputPath)
        recordButton.setImageResource(android.R.drawable.presence_video_online)
        timerText.visibility = View.GONE
        recordingStartMs = null
        closeCamera()
        val result = Intent().apply {
            putExtra(EXTRA_OUTPUT_PATH, outputPath)
        }
        resultSent = true
        setResult(Activity.RESULT_OK, result)
        finish()
    }

    private fun startCountdown() {
        if (isRecording || countdownValue > 0) return
        countdownValue = 3
        countdownText.text = countdownValue.toString()
        countdownText.visibility = View.VISIBLE
        recordButton.isEnabled = false
        uiHandler.postDelayed(object : Runnable {
            override fun run() {
                countdownValue -= 1
                if (countdownValue <= 0) {
                    countdownValue = 0
                    countdownText.visibility = View.GONE
                    recordButton.isEnabled = true
                    startRecording()
                } else {
                    countdownText.text = countdownValue.toString()
                    uiHandler.postDelayed(this, 1000)
                }
            }
        }, 1000)
    }

    private fun startTimer() {
        uiHandler.post(object : Runnable {
            override fun run() {
                if (!isRecording || recordingStartMs == null) return
                val elapsedMs = System.currentTimeMillis() - recordingStartMs!!
                timerText.text = "REC ${formatMs(elapsedMs)}"
                uiHandler.postDelayed(this, 1000)
            }
        })
    }

    private fun formatMs(ms: Long): String {
        if (ms <= 0) return "00:00"
        val totalSeconds = ms / 1000
        val minutes = (totalSeconds / 60).toInt()
        val seconds = (totalSeconds % 60).toInt()
        return String.format("%02d:%02d", minutes, seconds)
    }

    private fun closeCamera() {
        captureSession?.close()
        captureSession = null
        cameraDevice?.close()
        cameraDevice = null
    }

    private fun finishWithError(message: String) {
        writeStatus("failed", message, outputPath)
        val result = Intent().apply {
            putExtra(EXTRA_ERROR, message)
        }
        resultSent = true
        setResult(Activity.RESULT_CANCELED, result)
        finish()
    }

    private fun writeStatus(status: String, error: String?, path: String?) {
        getSharedPreferences(USB_CAPTURE_PREFS, MODE_PRIVATE)
            .edit()
            .putString(USB_CAPTURE_STATUS, status)
            .putString(USB_CAPTURE_ERROR, error)
            .putString(USB_CAPTURE_PATH, path)
            .putLong(USB_CAPTURE_TIME, System.currentTimeMillis())
            .apply()
    }

    override fun onDestroy() {
        uiHandler.removeCallbacksAndMessages(null)
        if (!resultSent) {
            writeStatus("activity_destroyed", null, outputPath)
        }
        super.onDestroy()
    }
}

package com.example.smart_mirror_flutter

import android.app.Activity
import android.app.Presentation
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.hardware.display.DisplayManager
import android.media.MediaRecorder
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Size
import android.view.Display
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
import kotlin.math.abs
import kotlin.math.min

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
    private lateinit var rotateButton: ImageButton
    private lateinit var rotationText: TextView
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
    private var mirrorPresentation: MirrorPreviewPresentation? = null
    private var mirrorSurface: Surface? = null
    private var mirrorTextureView: TextureView? = null
    private var mirrorGridView: View? = null
    private var mirrorContentView: FrameLayout? = null
    private var mirrorPreviewFrameView: FrameLayout? = null

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

        rotationText = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 13f
            text = "ROT ${getMirrorRotationDegrees()}°"
            setBackgroundColor(0x55000000)
            setPadding(16, 8, 16, 8)
        }
        val rotationTextParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.END
        )
        rotationTextParams.topMargin = 18
        rotationTextParams.rightMargin = 110
        root.addView(rotationText, rotationTextParams)

        rotateButton = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_menu_rotate)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { cycleMirrorRotation() }
        }
        val rotateParams = FrameLayout.LayoutParams(100, 100, Gravity.TOP or Gravity.END)
        rotateParams.topMargin = 0
        rotateParams.rightMargin = 0
        root.addView(rotateButton, rotateParams)

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
        showMirrorPreview()
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
        dismissMirrorPreview()
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
            mirrorTextureView?.surfaceTexture?.setDefaultBufferSize(size.width, size.height)
            runOnUiThread {
                previewLayout.setAspectRatio(size.width.toFloat() / size.height.toFloat())
                previewLayout.requestLayout()
                applyMirrorPreviewRotation()
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
        val surfaceTexture = textureView.surfaceTexture
        val uiSurface = if (surfaceTexture != null) Surface(surfaceTexture) else null

        val outputs = mutableListOf<Surface>()
        if (uiSurface != null) {
            outputs.add(uiSurface)
        }
        mirrorSurface?.let { outputs.add(it) }
        if (outputs.isEmpty()) return
        val requestBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
            outputs.forEach { addTarget(it) }
        }

        camera.createCaptureSession(outputs, object : CameraCaptureSession.StateCallback() {
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

        val previewSurface = mirrorSurface ?: run {
            val surfaceTexture = textureView.surfaceTexture ?: return
            surfaceTexture.setDefaultBufferSize(size.width, size.height)
            Surface(surfaceTexture)
        }
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

    private fun showMirrorPreview() {
        val dm = getSystemService(DISPLAY_SERVICE) as DisplayManager
        val displays = dm.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
        if (displays.isEmpty()) return

        val currentId = display?.displayId ?: Display.DEFAULT_DISPLAY
        val preferredId = getSharedPreferences("mirror_settings", MODE_PRIVATE)
            .getInt("mirror_display_id", -1)
        val target = displays.firstOrNull { it.displayId == preferredId }
            ?: displays.firstOrNull { it.displayId != currentId }
            ?: return

        mirrorPresentation = MirrorPreviewPresentation(this, target).also { pres ->
            pres.setOnSurfaceReady { tv, grid, content, previewFrame ->
                mirrorTextureView = tv
                mirrorGridView = grid
                mirrorContentView = content
                mirrorPreviewFrameView = previewFrame
                val tex = tv.surfaceTexture ?: return@setOnSurfaceReady
                previewSize?.let { tex.setDefaultBufferSize(it.width, it.height) }
                mirrorSurface?.release()
                mirrorSurface = Surface(tex)
                applyMirrorPreviewRotation()
                if (!isRecording && cameraDevice != null) {
                    createPreviewSession()
                }
            }
            pres.show()
        }
    }

    private fun dismissMirrorPreview() {
        mirrorSurface?.release()
        mirrorSurface = null
        mirrorTextureView = null
        mirrorGridView = null
        mirrorContentView = null
        mirrorPreviewFrameView = null
        mirrorPresentation?.dismiss()
        mirrorPresentation = null
    }

    private fun getMirrorRotationDegrees(): Int {
        return getSharedPreferences("mirror_settings", MODE_PRIVATE)
            .getInt("mirror_rotation", 0)
    }

    private fun setMirrorRotationDegrees(value: Int) {
        val normalized = when (value) {
            90, 180, 270 -> value
            else -> 0
        }
        getSharedPreferences("mirror_settings", MODE_PRIVATE)
            .edit()
            .putInt("mirror_rotation", normalized)
            .apply()
        if (::rotationText.isInitialized) {
            rotationText.text = "ROT ${normalized}°"
        }
    }

    private fun cycleMirrorRotation() {
        val current = getMirrorRotationDegrees()
        val next = ((current / 90 + 1) % 4) * 90
        setMirrorRotationDegrees(next)
        applyMirrorPreviewRotation()
    }

    private fun applyMirrorPreviewRotation() {
        val texture = mirrorTextureView ?: return
        val grid = mirrorGridView ?: return
        val content = mirrorContentView ?: return
        val previewFrame = mirrorPreviewFrameView ?: return
        val size = previewSize ?: videoSize ?: return

        val cw = content.width
        val ch = content.height
        if (cw <= 0 || ch <= 0) {
            content.post { applyMirrorPreviewRotation() }
            return
        }

        val userRotation = getMirrorRotationDegrees()
        val contentRotation = userRotation.toFloat()

        content.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
            Gravity.CENTER
        )

        val portraitAspect = size.height.toFloat() / size.width.toFloat()
        var frameW = cw.toFloat()
        var frameH = frameW / portraitAspect
        if (frameH > ch) {
            frameH = ch.toFloat()
            frameW = frameH * portraitAspect
        }

        previewFrame.layoutParams = FrameLayout.LayoutParams(
            frameW.toInt(),
            frameH.toInt(),
            Gravity.CENTER
        )

        val childLp = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
            Gravity.CENTER
        )
        texture.layoutParams = childLp
        grid.layoutParams = childLp

        previewFrame.pivotX = frameW / 2f
        previewFrame.pivotY = frameH / 2f
        previewFrame.rotation = contentRotation
        if (userRotation == 90 || userRotation == 270) {
            val uniform = min(cw.toFloat() / frameH, ch.toFloat() / frameW)
            previewFrame.scaleX = uniform
            previewFrame.scaleY = uniform
        } else {
            previewFrame.scaleX = 1f
            previewFrame.scaleY = 1f
        }

        listOf(texture, grid).forEach { view ->
            view.rotation = 0f
            view.scaleX = 1f
            view.scaleY = 1f
        }
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

    private class MirrorPreviewPresentation(
        context: Context,
        display: Display
    ) : Presentation(context, display) {
        private var onSurfaceReady: ((TextureView, View, FrameLayout, FrameLayout) -> Unit)? = null
        private lateinit var texture: TextureView
        private lateinit var grid: GridOverlayView
        private lateinit var content: FrameLayout
        private lateinit var previewFrame: FrameLayout

        fun setOnSurfaceReady(cb: (TextureView, View, FrameLayout, FrameLayout) -> Unit) {
            onSurfaceReady = cb
        }

        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            val root = FrameLayout(context).apply {
                setBackgroundColor(Color.BLACK)
            }
            content = FrameLayout(context)
            previewFrame = FrameLayout(context)
            texture = TextureView(context)
            previewFrame.addView(
                texture,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    Gravity.CENTER
                )
            )
            grid = GridOverlayView(context)
            previewFrame.addView(
                grid,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    Gravity.CENTER
                )
            )
            content.addView(
                previewFrame,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    Gravity.CENTER
                )
            )
            root.addView(
                content,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    Gravity.CENTER
                )
            )
            setContentView(root)

            texture.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
                override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
                    onSurfaceReady?.invoke(texture, grid, content, previewFrame)
                }

                override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {}
                override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {}
                override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean = true
            }
        }
    }

    private class GridOverlayView(context: Context) : View(context) {
        private val paint = Paint().apply {
            color = Color.WHITE
            alpha = 160
            strokeWidth = 2f
            style = Paint.Style.STROKE
            pathEffect = DashPathEffect(floatArrayOf(12f, 10f), 0f)
        }

        override fun onDraw(canvas: android.graphics.Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()

            val v1 = w * 0.25f
            val v2 = w * 0.75f
            val h1 = h * 0.15f
            val h2 = h * 0.85f

            canvas.drawLine(v1, 0f, v1, h, paint)
            canvas.drawLine(v2, 0f, v2, h, paint)
            canvas.drawLine(0f, h1, w, h1, paint)
            canvas.drawLine(0f, h2, w, h2, paint)
        }
    }
}

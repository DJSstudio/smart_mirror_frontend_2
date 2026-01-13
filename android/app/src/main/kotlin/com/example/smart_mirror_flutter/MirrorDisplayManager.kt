package com.example.smart_mirror_flutter

import android.app.ActivityOptions
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.util.Log
import android.view.Display

class MirrorDisplayManager(private val context: Context) {

    private var presentation: MirrorPresentation? = null
    private var currentDisplayId: Int = Display.DEFAULT_DISPLAY

    fun setCurrentDisplayId(displayId: Int) {
        currentDisplayId = displayId
    }

    fun showIdle(): Boolean {
        val display = findExternalDisplay() ?: return false
        return if (isPresentationDisplay(display.displayId)) {
            val p = ensurePresentation(display) ?: return false
            p.showIdle()
            true
        } else {
            launchMirrorActivity(display.displayId, MirrorActivity.MODE_IDLE, null, null)
        }
    }

    fun playVideo(source: String): Boolean {
        val display = findExternalDisplay() ?: return false
        return if (isPresentationDisplay(display.displayId)) {
            val p = ensurePresentation(display) ?: return false
            p.playVideo(source)
            true
        } else {
            launchMirrorActivity(display.displayId, MirrorActivity.MODE_PLAY, source, null)
        }
    }

    fun compareVideos(left: String, right: String): Boolean {
        val display = findExternalDisplay() ?: return false
        return if (isPresentationDisplay(display.displayId)) {
            val p = ensurePresentation(display) ?: return false
            p.compareVideos(left, right)
            true
        } else {
            launchMirrorActivity(display.displayId, MirrorActivity.MODE_COMPARE, left, right)
        }
    }

    fun hideMirror() {
        presentation?.dismiss()
        presentation = null
        MirrorActivity.finishIfRunning()
    }

    private fun ensurePresentation(display: Display): MirrorPresentation? {
        if (presentation != null) {
            if (presentation?.display?.displayId == display.displayId &&
                presentation?.isShowing == true
            ) {
                return presentation
            }
            presentation?.dismiss()
            presentation = null
        }

        val displayContext = context.createDisplayContext(display)
        return try {
            presentation = MirrorPresentation(displayContext, display)
            presentation?.show()
            presentation
        } catch (e: Exception) {
            Log.e("MirrorDisplay", "Failed to show presentation: ${e.message}")
            presentation = null
            null
        }
    }

    private fun findExternalDisplay(): Display? {
        val displayManager =
            context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val displays = displayManager.displays

        Log.i("MirrorDisplay", "Current display id=$currentDisplayId total=${displays.size}")
        for (d in displays) {
            Log.i("MirrorDisplay", "Display id=${d.displayId} name=${d.name} flags=${d.flags}")
        }

        val external = displays.firstOrNull { it.displayId != currentDisplayId }
        if (external == null) {
            Log.w("MirrorDisplay", "No external display found (count=${displays.size})")
        } else {
            Log.i("MirrorDisplay", "Using external display id=${external.displayId} name=${external.name}")
        }
        return external
    }

    private fun isPresentationDisplay(displayId: Int): Boolean {
        val displayManager =
            context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        return displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
            .any { it.displayId == displayId }
    }

    private fun launchMirrorActivity(
        displayId: Int,
        mode: String,
        left: String?,
        right: String?
    ): Boolean {
        return try {
            val intent = Intent(context, MirrorActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(MirrorActivity.EXTRA_MODE, mode)
                putExtra(MirrorActivity.EXTRA_LEFT, left)
                putExtra(MirrorActivity.EXTRA_RIGHT, right)
                putExtra(MirrorActivity.EXTRA_TARGET_DISPLAY_ID, displayId)
            }
            val options = ActivityOptions.makeBasic().setLaunchDisplayId(displayId)
            context.startActivity(intent, options.toBundle())
            true
        } catch (e: Exception) {
            Log.e("MirrorDisplay", "Failed to launch mirror activity: ${e.message}")
            false
        }
    }
}

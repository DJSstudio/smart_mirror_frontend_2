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
    private var preferredDisplayId: Int = -1
    private val settingsPrefs = "mirror_settings"
    private val displayKey = "mirror_display_id"

    fun setCurrentDisplayId(displayId: Int) {
        currentDisplayId = displayId
    }

    fun setPreferredDisplayId(displayId: Int) {
        preferredDisplayId = displayId
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

    fun showRecording(): Boolean {
        val display = findExternalDisplay() ?: return false
        return if (isPresentationDisplay(display.displayId)) {
            val p = ensurePresentation(display) ?: return false
            p.showRecording()
            true
        } else {
            launchMirrorActivity(display.displayId, MirrorActivity.MODE_RECORD, null, null)
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
        val presentationDisplays =
            displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).toList()

        // Pull latest preference from storage so every caller uses the same pinned target.
        val storedPreferred = context
            .getSharedPreferences(settingsPrefs, Context.MODE_PRIVATE)
            .getInt(displayKey, -1)
        if (storedPreferred != -1) {
            preferredDisplayId = storedPreferred
        }

        Log.i("MirrorDisplay", "Current display id=$currentDisplayId total=${displays.size}")
        for (d in displays) {
            Log.i("MirrorDisplay", "Display id=${d.displayId} name=${d.name} flags=${d.flags}")
        }

        if (preferredDisplayId != -1) {
            val preferred = displays.firstOrNull { it.displayId == preferredDisplayId }
            if (preferred != null) {
                if (preferred.displayId == currentDisplayId) {
                    Log.w("MirrorDisplay", "Preferred display is current display; ignoring")
                    return null
                } else if (presentationDisplays.any { it.displayId == preferred.displayId }) {
                    Log.i("MirrorDisplay", "Using preferred display id=${preferred.displayId} name=${preferred.name}")
                    return preferred
                } else {
                    Log.w("MirrorDisplay", "Preferred display is not a presentation display")
                    return null
                }
            } else {
                Log.w("MirrorDisplay", "Preferred display id=$preferredDisplayId not found")
                return null
            }
        }

        // First-run auto-selection: pick largest presentation display that is not current.
        val candidates = presentationDisplays.filter { it.displayId != currentDisplayId }
        if (candidates.isEmpty()) {
            Log.w("MirrorDisplay", "No presentation display candidate found")
            return null
        }
        val selected = candidates.maxByOrNull {
            val m = it.mode
            m.physicalWidth * m.physicalHeight
        } ?: return null
        preferredDisplayId = selected.displayId
        context.getSharedPreferences(settingsPrefs, Context.MODE_PRIVATE)
            .edit()
            .putInt(displayKey, preferredDisplayId)
            .apply()
        Log.i(
            "MirrorDisplay",
            "Auto-selected mirror display id=${selected.displayId} name=${selected.name}"
        )
        return selected
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

package com.example.smart_mirror_flutter

import android.content.Context
import android.hardware.display.DisplayManager
import android.view.Display

class MirrorDisplayManager(private val context: Context) {

    private var presentation: MirrorPresentation? = null

    fun showMirror() {
        if (presentation != null) return

        val displayManager =
            context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

        val displays = displayManager.displays

        val externalDisplay = displays.firstOrNull {
            it.displayId != Display.DEFAULT_DISPLAY
        }

        if (externalDisplay != null) {
            presentation = MirrorPresentation(context, externalDisplay)
            presentation?.show()
        }
    }

    fun hideMirror() {
        presentation?.dismiss()
        presentation = null
    }
}

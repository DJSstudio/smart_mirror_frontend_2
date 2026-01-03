package com.example.smart_mirror_flutter

import android.app.Presentation
import android.content.Context
import android.os.Bundle
import android.view.View
import android.view.WindowManager

class MirrorPresentation(
    context: Context,
    display: android.view.Display
) : Presentation(context, display) {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Fullscreen, black screen
        window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)

        val view = View(context)
        view.setBackgroundColor(0xFF000000.toInt())
        setContentView(view)
    }
}

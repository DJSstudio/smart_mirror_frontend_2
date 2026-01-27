package com.example.smart_mirror_flutter

import android.content.Context
import android.util.AttributeSet
import android.widget.FrameLayout

class AspectRatioFrameLayout @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : FrameLayout(context, attrs) {
    private var aspectRatio = 0f

    fun setAspectRatio(ratio: Float) {
        if (ratio <= 0f || ratio.isNaN()) return
        if (aspectRatio != ratio) {
            aspectRatio = ratio
            requestLayout()
        }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val height = MeasureSpec.getSize(heightMeasureSpec)
        if (aspectRatio > 0f && width > 0 && height > 0) {
            val viewAspect = width.toFloat() / height.toFloat()
            var measuredWidth = width
            var measuredHeight = height
            if (viewAspect > aspectRatio) {
                measuredWidth = (height * aspectRatio).toInt()
            } else {
                measuredHeight = (width / aspectRatio).toInt()
            }
            val wSpec = MeasureSpec.makeMeasureSpec(measuredWidth, MeasureSpec.EXACTLY)
            val hSpec = MeasureSpec.makeMeasureSpec(measuredHeight, MeasureSpec.EXACTLY)
            super.onMeasure(wSpec, hSpec)
            return
        }
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }
}

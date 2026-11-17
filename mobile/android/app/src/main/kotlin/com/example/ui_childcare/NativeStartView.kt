package com.example.track_children

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ImageDecoder
import android.graphics.Paint
import android.graphics.DashPathEffect
import android.graphics.drawable.ShapeDrawable
import android.graphics.drawable.shapes.PathShape
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.Animatable
import android.graphics.drawable.AnimatedImageDrawable
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.util.Log
import android.util.Xml
import androidx.core.graphics.PathParser
import org.xmlpull.v1.XmlPullParser
import android.view.View
import android.view.WindowInsets
import java.util.concurrent.Executors
import kotlin.math.min

/** This view has no Flutter dependency and paints the complete first app frame. */
class NativeStartView(context: Context) : View(context) {
    companion object {
        const val BACKGROUND = 0xfff0f5e7.toInt()
        private const val ASSETS = "flutter_assets/assets/images/scenery/backgrounds/start-assets"
    }

    var onFirstDraw: (() -> Unit)? = null
    private var firstDraw = true
    private var sceneWidth = 0f
    private var sceneHeight = 0f
    private val location = IntArray(2)
    private val started = SystemClock.uptimeMillis()
    private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val titlePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xff29451e.toInt()
        typeface = font(900)
    }
    private val sloganPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xff538b29.toInt()
        typeface = font(600)
    }
    private val background = drawable(R.drawable.start_start_background)
    private val foreground = drawable(R.drawable.start_foreground)
    private val underline = drawable(R.drawable.start_underline)
    private val circle = drawable(R.drawable.start_circle)
    private val shadow = drawable(R.drawable.start_ground_shadow)
    private val heart = drawable(R.drawable.start_heart)
    private val rays = drawable(R.drawable.start_rays)
    private val jumpMarks = drawable(R.drawable.start_jump_marks)
    private val sparkles = drawable(R.drawable.start_sparkles)
    private val dashedCurve = dashedCurveDrawable()
    private val poses = mutableMapOf("idle" to loadPose("idle"))
    private val decoder = Executors.newSingleThreadExecutor()
    private var disposed = false
    private var welcomeRequested = false
    private var welcomeDrawn = false
    private var onWelcomePresented: (() -> Unit)? = null
    private val finishWelcome = Runnable {
        if (!disposed) {
            val callback = onWelcomePresented
            onWelcomePresented = null
            callback?.invoke()
        }
    }
    private val reducedMotion = Settings.Global.getFloat(
        context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f
    ) == 0f
    private val loadingAnimation: Drawable? = if (Build.VERSION.SDK_INT >= 28 && !reducedMotion) {
        ImageDecoder.decodeDrawable(ImageDecoder.createSource(resources, R.drawable.start_mascot_loading)).also {
            it.callback = this
            (it as AnimatedImageDrawable).repeatCount = AnimatedImageDrawable.REPEAT_INFINITE
            it.start()
        }
    } else null

    init {
        setBackgroundColor(BACKGROUND)
        isClickable = true
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
        contentDescription = "B\u00e9 l\u1edbn kh\u00f4n. C\u00f9ng con l\u1edbn kh\u00f4n m\u1ed7i ng\u00e0y"
        for (pose in listOf("happy", "welcome")) {
            decoder.execute {
                val bitmap = loadPose(pose)
                post {
                    if (!disposed) {
                        poses[pose] = bitmap
                        invalidate()
                    }
                }
            }
        }
    }

    private fun font(weight: Int): Typeface {
        val path = "flutter_assets/assets/fonts/nunito/Nunito-Variable.ttf"
        return if (Build.VERSION.SDK_INT >= 26) {
            Typeface.Builder(context.assets, path)
                .setFontVariationSettings("'wght' $weight").build()
        } else {
            Typeface.create(Typeface.createFromAsset(context.assets, path), Typeface.BOLD)
        }
    }

    private fun drawable(id: Int): Drawable = context.getDrawable(id)!!

    private fun dashedCurveDrawable(): Drawable {
        // VectorDrawable cannot represent SVG stroke-dasharray. Keep the actual
        // SVG path and use Canvas's dashed stroke rather than losing the dashes.
        val parser = Xml.newPullParser()
        context.assets.open("$ASSETS/decorations/dashed_curve.svg").use { stream ->
            parser.setInput(stream, "UTF-8")
            while (parser.next() != XmlPullParser.END_DOCUMENT) {
                if (parser.eventType == XmlPullParser.START_TAG && parser.name == "path") {
                    val path = PathParser.createPathFromPathData(parser.getAttributeValue(null, "d"))!!
                    return ShapeDrawable(PathShape(path, 240f, 120f)).apply {
                        paint.color = 0xff538b29.toInt()
                        paint.style = Paint.Style.STROKE
                        paint.strokeWidth = 4f
                        paint.strokeCap = Paint.Cap.ROUND
                        paint.pathEffect = DashPathEffect(floatArrayOf(9f, 12f), 0f)
                        paint.isAntiAlias = true
                    }
                }
            }
        }
        error("Missing dashed_curve SVG path")
    }

    private fun loadPose(pose: String): Bitmap? = try {
        context.assets.open("$ASSETS/mascot/$pose.png").use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = 1 })
        }
    } catch (_: java.io.IOException) { null }

    private fun drawIn(canvas: Canvas, image: Drawable, box: RectF) {
        image.setBounds(box.left.toInt(), box.top.toInt(), box.right.toInt(), box.bottom.toInt())
        image.draw(canvas)
    }

    private fun drawCover(canvas: Canvas, image: Drawable) {
        // Same cover/bottom-center fit as the Flutter Start assets (1080 x 2400).
        val factor = maxOf(sceneWidth / 1080f, sceneHeight / 2400f)
        val w = 1080 * factor
        val h = 2400 * factor
        drawIn(canvas, image, RectF((sceneWidth - w) / 2, sceneHeight - h, (sceneWidth + w) / 2, sceneHeight))
    }

    /** End the loading loop only after welcome has actually been drawn. */
    fun showWelcome(onPresented: () -> Unit) {
        if (disposed) return
        welcomeRequested = true
        welcomeDrawn = false
        onWelcomePresented = onPresented
        (loadingAnimation as? Animatable)?.stop()
        removeCallbacks(finishWelcome)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        // Flutter's PlatformPlugin can turn on edge-to-edge while loading.
        // Keep the native scene in the same physical safe rectangle on both sides
        // of that change instead of recomputing its composition against full screen.
        getLocationOnScreen(location)
        val insets = rootWindowInsets
        val topInset: Int
        val bottomInset: Int
        if (Build.VERSION.SDK_INT >= 30) {
            val bars = insets?.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars())
            topInset = bars?.top ?: 0
            bottomInset = bars?.bottom ?: 0
        } else {
            @Suppress("DEPRECATION")
            topInset = insets?.systemWindowInsetTop ?: 0
            @Suppress("DEPRECATION")
            bottomInset = insets?.systemWindowInsetBottom ?: 0
        }
        val safeTop = (topInset - location[1]).coerceAtLeast(0)
        val safeBottom = (location[1] + height - (rootView.height - bottomInset)).coerceAtLeast(0)
        sceneWidth = width.toFloat()
        sceneHeight = (height - safeTop - safeBottom).coerceAtLeast(1).toFloat()
        canvas.save()
        canvas.clipRect(0f, safeTop.toFloat(), sceneWidth, safeTop + sceneHeight)
        canvas.translate(0f, safeTop.toFloat())
        val density = resources.displayMetrics.density
        val scale = min(min(sceneWidth / density / 360f, sceneHeight / density / 752f), 1.35f)
        val unit = density * scale
        val textUnit = resources.displayMetrics.scaledDensity * 1.15f * min(1f, scale)
        val center = sceneWidth / 2f
        drawCover(canvas, background)

        var top = sceneHeight * .17f
        titlePaint.textSize = 40f * textUnit
        val title = "B\u00e9 l\u1edbn kh\u00f4n"
        val availableWidth = width - 32 * density
        if (titlePaint.measureText(title) > availableWidth) {
            titlePaint.textSize *= availableWidth / titlePaint.measureText(title)
        }
        val titleLeft = center - titlePaint.measureText(title) / 2
        val titleRight = center + titlePaint.measureText(title) / 2
        val curveLeft = (titleRight - 14 * unit).coerceIn(16 * density,
            (sceneWidth - 16 * density - 64 * unit).coerceAtLeast(16 * density))
        drawIn(canvas, dashedCurve, RectF(curveLeft, top - 18 * unit,
            curveLeft + 64 * unit, top + 14 * unit))
        val marksLeft = (titleLeft - 12 * unit).coerceIn(0f, (sceneWidth - 32 * unit).coerceAtLeast(0f))
        val marksBox = RectF(marksLeft, top - 23 * unit, marksLeft + 32 * unit, top - unit)
        canvas.save()
        canvas.rotate(-30f, marksBox.centerX(), marksBox.centerY())
        drawIn(canvas, jumpMarks, marksBox)
        canvas.restore()
        val lineHeight = titlePaint.textSize * 1.2f
        val baseline = top + (lineHeight - titlePaint.fontMetrics.bottom - titlePaint.fontMetrics.top) / 2
        canvas.drawText(title, center - titlePaint.measureText(title) / 2, baseline, titlePaint)
        top += lineHeight
        drawIn(canvas, underline, RectF(center - 75 * unit, top, center + 75 * unit, top + 20 * unit))
        top += 20 * unit

        sloganPaint.textSize = 15 * textUnit
        val sloganText = "C\u00f9ng con l\u1edbn kh\u00f4n m\u1ed7i ng\u00e0y"
        val slogan = StaticLayout.Builder.obtain(
            sloganText, 0, sloganText.length, sloganPaint, availableWidth.toInt()
        ).setAlignment(Layout.Alignment.ALIGN_CENTER).setIncludePad(false).build()
        canvas.save()
        canvas.translate((width - availableWidth) / 2, top)
        slogan.draw(canvas)
        canvas.restore()
        top += slogan.height + 12 * unit

        val mascotSize = min(245 * unit, (sceneHeight - top - 24 * density).coerceAtLeast(0f))
        val mascotCenterY = top + mascotSize / 2
        val circleSize = mascotSize * 225 / 245
        drawIn(canvas, circle, RectF(center - circleSize / 2, mascotCenterY - circleSize / 2,
            center + circleSize / 2, mascotCenterY + circleSize / 2))
        drawIn(canvas, shadow, RectF(center - 55 * unit, top + mascotSize - 20 * unit,
            center + 55 * unit, top + mascotSize))

        val elapsed = SystemClock.uptimeMillis() - started
        val cycle = elapsed % 1200L
        val pose = when {
            welcomeRequested -> "welcome"
            reducedMotion -> "idle"
            cycle < 600 -> "idle"
            else -> "happy"
        }
        val bitmap = poses[pose] ?: poses["idle"]
        // The animated idle frame contains the 1.067/1.16 size compensation.
        // Keep the animation's draw size constant so it can run on RenderThread.
        val poseScale = if (!welcomeRequested && loadingAnimation != null) 1.16f
            else if (pose == "idle") 1.067f else 1.16f
        val poseSize = mascotSize * poseScale
        val poseTop = top + (mascotSize - poseSize) / 2
        if (!welcomeRequested && loadingAnimation != null) {
            // AnimatedImageDrawable decodes/advances on framework render threads,
            // so engine initialization blocking the UI thread cannot freeze it.
            drawIn(canvas, loadingAnimation, RectF(center - poseSize / 2, poseTop,
                center + poseSize / 2, poseTop + poseSize))
        } else if (bitmap != null) {
            canvas.drawBitmap(bitmap, null, RectF(center - poseSize / 2, poseTop,
                center + poseSize / 2, poseTop + poseSize), bitmapPaint)
        }
        val heartBox = RectF(center - mascotSize / 2 - unit, top + 84 * unit,
            center - mascotSize / 2 + 25 * unit, top + 112 * unit)
        canvas.save()
        canvas.rotate(-12f, heartBox.centerX(), heartBox.centerY())
        drawIn(canvas, heart, heartBox)
        canvas.restore()
        drawIn(canvas, rays, RectF(center + mascotSize / 2 - 26 * unit, top + 74 * unit,
            center + mascotSize / 2 + 2 * unit, top + 104 * unit))
        drawIn(canvas, sparkles, RectF(center + mascotSize / 2 - 89 * unit, top - 4 * unit,
            center + mascotSize / 2 - 67 * unit, top + 18 * unit))
        drawCover(canvas, foreground)
        canvas.restore()

        if (firstDraw) {
            firstDraw = false
            post { onFirstDraw?.invoke() }
        }
        if (welcomeRequested && !welcomeDrawn && poses.containsKey("welcome")) {
            // Start the hold after this frame, not when decoding/requesting it.
            // A missing asset still releases using the idle fallback.
            welcomeDrawn = true
            Log.i("StartLaunch", "mascot_welcome_drawn")
            post { if (!disposed) postDelayed(finishWelcome, 600) }
        }
        if (loadingAnimation == null && !reducedMotion && !welcomeRequested && windowVisibility == VISIBLE) {
            postInvalidateDelayed(33)
        }
    }

    override fun onWindowVisibilityChanged(visibility: Int) {
        super.onWindowVisibilityChanged(visibility)
        loadingAnimation?.setVisible(visibility == VISIBLE, false)
        if (visibility == VISIBLE && !welcomeRequested) (loadingAnimation as? Animatable)?.start()
        else (loadingAnimation as? Animatable)?.stop()
        if (visibility == VISIBLE) invalidate()
    }

    override fun verifyDrawable(who: Drawable): Boolean =
        who === loadingAnimation || super.verifyDrawable(who)

    fun dispose() {
        disposed = true
        onFirstDraw = null
        onWelcomePresented = null
        removeCallbacks(finishWelcome)
        (loadingAnimation as? Animatable)?.stop()
        loadingAnimation?.callback = null
        decoder.shutdownNow()
        // Bitmaps can still be referenced by a RenderThread display list. Let GC reclaim them.
        poses.clear()
    }
}

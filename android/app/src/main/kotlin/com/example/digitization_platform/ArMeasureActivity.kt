package com.example.digitization_platform

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.drawable.GradientDrawable
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.google.ar.core.Anchor
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Camera
import com.google.ar.core.Config
import com.google.ar.core.DepthPoint
import com.google.ar.core.Frame
import com.google.ar.core.HitResult
import com.google.ar.core.Plane
import com.google.ar.core.Point
import com.google.ar.core.Pose
import com.google.ar.core.Session
import com.google.ar.core.TrackingFailureReason
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.UnavailableDeviceNotCompatibleException
import com.google.ar.core.exceptions.UnavailableException
import com.google.ar.core.exceptions.UnavailableUserDeclinedInstallationException
import java.util.Locale
import java.util.concurrent.atomic.AtomicReference
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.hypot

/**
 * Measures how wide a target is on the wall: aim at its left edge, then at its
 * right edge. Thoth Guide AI gives this width to its image tracker, in metres.
 *
 * The width is the **horizontal** distance between the two points. ARCore's
 * world Y axis follows gravity, so leaving Y out means two tapped points at
 * slightly different heights can't inflate it.
 *
 * It is read from anchors, not from where the points were first placed: ARCore
 * goes on correcting an anchor as it learns the room, and that correction is
 * what makes a span too long to fit in one view trustworthy.
 *
 * See `ArMeasureChannel` in Dart for how this screen's result is used.
 */
class ArMeasureActivity : Activity(), GLSurfaceView.Renderer {
    private enum class Action { PRIMARY, UNDO }

    /** What the views show, built on the GL thread each frame. */
    private data class Controls(
        val hint: String,
        val distance: String?,
        val primaryLabel: String,
        val primaryEnabled: Boolean,
        val canUndo: Boolean,
    )

    private lateinit var surfaceView: GLSurfaceView
    private lateinit var overlay: MeasureOverlay
    private lateinit var hintView: TextView
    private lateinit var distanceView: TextView
    private lateinit var primaryButton: Button
    private lateinit var undoButton: Button

    private val background = ArCameraBackground()

    private var session: Session? = null
    private var installRequested = false
    private var permissionRequested = false

    // Touched only on the GL thread, like every ARCore call made while running.
    private var leftAnchor: Anchor? = null
    private var rightAnchor: Anchor? = null
    private var lostTrackOfPoints = false
    private var viewportWidth = 0
    private var viewportHeight = 0
    private var viewportChanged = false

    private val pendingAction = AtomicReference<Action?>(null)
    private var shownControls: Controls? = null

    private val viewMatrix = FloatArray(16)
    private val projectionMatrix = FloatArray(16)
    private val viewProjectionMatrix = FloatArray(16)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(buildContent())
    }

    private fun buildContent(): View {
        surfaceView = GLSurfaceView(this).apply {
            preserveEGLContextOnPause = true
            setEGLContextClientVersion(2)
            setEGLConfigChooser(8, 8, 8, 8, 16, 0)
            setRenderer(this@ArMeasureActivity)
            renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        }
        overlay = MeasureOverlay(this)

        distanceView = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 40f)
            gravity = Gravity.CENTER
            visibility = View.GONE
        }
        hintView = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER
            text = "Starting the camera…"
        }
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(SCRIM)
            addView(distanceView)
            addView(hintView)
        }

        undoButton = button("Undo", filled = false).apply {
            visibility = View.GONE
            setOnClickListener { pendingAction.set(Action.UNDO) }
        }
        primaryButton = button("Set left edge", filled = true).apply {
            isEnabled = false
            setOnClickListener { pendingAction.set(Action.PRIMARY) }
        }
        val bottom = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(SCRIM)
            addView(undoButton, LinearLayout.LayoutParams(0, dp(52), 1f).apply { marginEnd = dp(12) })
            addView(primaryButton, LinearLayout.LayoutParams(0, dp(52), 2f))
        }

        val root = FrameLayout(this)
        root.addView(surfaceView, FrameLayout.LayoutParams(MATCH, MATCH))
        root.addView(overlay, FrameLayout.LayoutParams(MATCH, MATCH))
        root.addView(top, FrameLayout.LayoutParams(MATCH, WRAP, Gravity.TOP))
        root.addView(bottom, FrameLayout.LayoutParams(MATCH, WRAP, Gravity.BOTTOM))

        // Drawn under the system bars on current Android, so keep the controls clear of them.
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            top.setPadding(dp(16), bars.top + dp(12), dp(16), dp(12))
            bottom.setPadding(dp(16), dp(12), dp(16), bars.bottom + dp(12))
            insets
        }
        return root
    }

    private fun button(label: String, filled: Boolean) = Button(this).apply {
        text = label
        isAllCaps = false
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
        setTextColor(if (filled) Color.BLACK else Color.WHITE)
        background = GradientDrawable().apply {
            cornerRadius = dp(12).toFloat()
            if (filled) setColor(Color.WHITE) else setStroke(dp(1), Color.WHITE)
        }
    }

    override fun onResume() {
        super.onResume()
        if (session == null && !startSession()) return

        try {
            session?.resume()
        } catch (e: CameraNotAvailableException) {
            finishUnavailable("The camera is being used by something else.")
            return
        }
        surfaceView.onResume()
    }

    /** False when the screen is waiting for the operator, or has already closed. */
    private fun startSession(): Boolean {
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            if (!permissionRequested) {
                permissionRequested = true
                requestPermissions(arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA)
            }
            return false
        }

        try {
            // Installs or updates Google Play Services for AR through the Play Store.
            // ARCore pauses this screen for that, and onResume arrives here again.
            when (ArCoreApk.getInstance().requestInstall(this, !installRequested)) {
                ArCoreApk.InstallStatus.INSTALL_REQUESTED -> {
                    installRequested = true
                    return false
                }
                ArCoreApk.InstallStatus.INSTALLED -> Unit
            }

            val created = Session(this)
            created.configure(
                Config(created).apply {
                    planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                    focusMode = Config.FocusMode.AUTO
                    updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                    if (created.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                        depthMode = Config.DepthMode.AUTOMATIC
                    }
                },
            )
            session = created
            return true
        } catch (e: UnavailableUserDeclinedInstallationException) {
            finishUnavailable("Google Play Services for AR wasn't installed.")
        } catch (e: UnavailableDeviceNotCompatibleException) {
            finishUnavailable("This phone doesn't support AR.")
        } catch (e: UnavailableException) {
            Log.w(TAG, "ARCore is unavailable", e)
            finishUnavailable("AR isn't available on this phone right now.")
        }
        return false
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val denied = grantResults.isEmpty() || grantResults[0] != PackageManager.PERMISSION_GRANTED
        if (requestCode == REQUEST_CAMERA && denied) {
            finishUnavailable("AR needs permission to use the camera.")
        }
    }

    override fun onPause() {
        super.onPause()
        // In this order: the GL thread has to stop calling session.update() first.
        surfaceView.onPause()
        session?.pause()
    }

    override fun onDestroy() {
        session?.close()
        session = null
        super.onDestroy()
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        background.createOnGlThread()
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        viewportWidth = width
        viewportHeight = height
        viewportChanged = true
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val session = session ?: return

        if (viewportChanged) {
            @Suppress("DEPRECATION")
            session.setDisplayGeometry(windowManager.defaultDisplay.rotation, viewportWidth, viewportHeight)
            viewportChanged = false
        }
        session.setCameraTextureName(background.textureId)

        val frame = try {
            session.update()
        } catch (e: CameraNotAvailableException) {
            Log.w(TAG, "The camera went away during a frame", e)
            return
        }

        background.draw(frame)

        val camera = frame.camera
        val tracking = camera.trackingState == TrackingState.TRACKING
        val hit = if (tracking) surfaceAtCentre(frame) else null

        dropAnchorsIfLost()
        handleAction(pendingAction.getAndSet(null), hit, tracking)

        val left = leftAnchor
        val right = rightAnchor
        val measuredTo = right?.pose ?: hit?.hitPose.takeIf { left != null }
        val distance = if (left != null && measuredTo != null) horizontalDistance(left.pose, measuredTo) else null

        if (tracking) {
            camera.getViewMatrix(viewMatrix, 0)
            camera.getProjectionMatrix(projectionMatrix, 0, NEAR_METERS, FAR_METERS)
            Matrix.multiplyMM(viewProjectionMatrix, 0, projectionMatrix, 0, viewMatrix, 0)
        }

        overlay.update(
            MeasureOverlay.Marks(
                surfaceFound = hit != null,
                left = if (tracking) left?.let { toScreen(it.pose) } else null,
                right = if (tracking) measuredTo?.let { toScreen(it) } else null,
            ),
        )
        showControls(controlsFor(camera, hit != null, tracking, left != null, right != null, distance))
    }

    /** The nearest real surface under the reticle, or null when ARCore can't see one there. */
    private fun surfaceAtCentre(frame: Frame): HitResult? =
        frame.hitTest(viewportWidth / 2f, viewportHeight / 2f).firstOrNull { hit ->
            when (val trackable = hit.trackable) {
                is Plane -> trackable.isPoseInPolygon(hit.hitPose)
                is DepthPoint -> true
                is Point -> trackable.orientationMode == Point.OrientationMode.ESTIMATED_SURFACE_NORMAL
                else -> false
            }
        }

    /** ARCore gives up on an anchor for good when it loses the room. Those points mean nothing now. */
    private fun dropAnchorsIfLost() {
        val anchors = listOfNotNull(leftAnchor, rightAnchor)
        if (anchors.any { it.trackingState == TrackingState.STOPPED }) {
            anchors.forEach { it.detach() }
            leftAnchor = null
            rightAnchor = null
            lostTrackOfPoints = true
        }
    }

    private fun handleAction(action: Action?, hit: HitResult?, tracking: Boolean) {
        when (action) {
            null -> Unit
            Action.PRIMARY -> {
                val left = leftAnchor
                val right = rightAnchor
                if (left != null && right != null) {
                    if (tracking) finishWithWidth(horizontalDistance(left.pose, right.pose))
                } else if (hit != null) {
                    val anchor = hit.createAnchor()
                    if (left == null) leftAnchor = anchor else rightAnchor = anchor
                    lostTrackOfPoints = false
                }
            }
            Action.UNDO -> {
                val last = rightAnchor ?: leftAnchor
                last?.detach()
                if (rightAnchor != null) rightAnchor = null else leftAnchor = null
            }
        }
    }

    private fun finishWithWidth(meters: Double) {
        runOnUiThread {
            setResult(RESULT_OK, Intent().putExtra(EXTRA_METERS, meters))
            finish()
        }
    }

    private fun horizontalDistance(a: Pose, b: Pose): Double =
        hypot((a.tx() - b.tx()).toDouble(), (a.tz() - b.tz()).toDouble())

    private fun toScreen(pose: Pose): PointF? {
        val clip = FloatArray(4)
        Matrix.multiplyMV(clip, 0, viewProjectionMatrix, 0, floatArrayOf(pose.tx(), pose.ty(), pose.tz(), 1f), 0)
        if (clip[3] <= 0f) return null // Behind the camera.
        return PointF(
            (clip[0] / clip[3] + 1f) / 2f * viewportWidth,
            (1f - clip[1] / clip[3]) / 2f * viewportHeight,
        )
    }

    private fun controlsFor(
        camera: Camera,
        surfaceFound: Boolean,
        tracking: Boolean,
        leftSet: Boolean,
        rightSet: Boolean,
        distance: Double?,
    ): Controls {
        val distanceText = distance?.let { String.format(Locale.US, "%.2f m", it) }
        val measurable = distance != null && distance >= MIN_METERS

        val hint = when {
            !tracking -> trackingHint(camera.trackingFailureReason)
            lostTrackOfPoints -> "Tracking was lost. Set the edges again."
            rightSet -> "Check the line runs along the edges, then use this width."
            !surfaceFound -> "Move slowly and keep the wall in view until the ring turns green."
            leftSet -> "Walk along the wall if you need to. Aim the ring at the right edge."
            else -> "Aim the ring at the left edge of what the target shows."
        }

        return Controls(
            hint = hint,
            distance = distanceText,
            primaryLabel = when {
                rightSet -> "Use ${distanceText ?: "this width"}"
                leftSet -> "Set right edge"
                else -> "Set left edge"
            },
            primaryEnabled = if (rightSet) tracking && measurable else tracking && surfaceFound,
            canUndo = leftSet,
        )
    }

    private fun trackingHint(reason: TrackingFailureReason): String = when (reason) {
        TrackingFailureReason.INSUFFICIENT_LIGHT -> "Too dark. Add some light if you can."
        TrackingFailureReason.EXCESSIVE_MOTION -> "Moving too fast. Move the phone slowly."
        TrackingFailureReason.INSUFFICIENT_FEATURES -> "Point at carved or patterned stone, not a plain area."
        TrackingFailureReason.CAMERA_UNAVAILABLE -> "The camera is being used by something else."
        else -> "Move the phone slowly from side to side."
    }

    /** Only when something changed: this runs every frame. */
    private fun showControls(controls: Controls) {
        if (controls == shownControls) return
        shownControls = controls
        runOnUiThread {
            hintView.text = controls.hint
            distanceView.text = controls.distance
            distanceView.visibility = if (controls.distance == null) View.GONE else View.VISIBLE
            primaryButton.text = controls.primaryLabel
            primaryButton.isEnabled = controls.primaryEnabled
            primaryButton.alpha = if (controls.primaryEnabled) 1f else 0.4f
            undoButton.visibility = if (controls.canUndo) View.VISIBLE else View.GONE
        }
    }

    private fun finishUnavailable(reason: String) {
        setResult(RESULT_UNAVAILABLE, Intent().putExtra(EXTRA_REASON, reason))
        finish()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    /** The reticle, the two points and the line between them, as seen from the phone right now. */
    private class MeasureOverlay(context: Context) : View(context) {
        data class Marks(val surfaceFound: Boolean, val left: PointF?, val right: PointF?)

        private val marks = AtomicReference(Marks(false, null, null))
        private val density = resources.displayMetrics.density

        private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 3f * density
        }
        private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            strokeWidth = 3f * density
        }
        private val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.WHITE
        }

        fun update(next: Marks) {
            marks.set(next)
            postInvalidateOnAnimation()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val current = marks.get()
            val left = current.left
            val right = current.right

            if (left != null && right != null) {
                canvas.drawLine(left.x, left.y, right.x, right.y, line)
            }
            left?.let { canvas.drawCircle(it.x, it.y, 6f * density, dot) }
            right?.let { canvas.drawCircle(it.x, it.y, 6f * density, dot) }

            val cx = width / 2f
            val cy = height / 2f
            ring.color = if (current.surfaceFound) FOUND else Color.WHITE
            canvas.drawCircle(cx, cy, 18f * density, ring)
            canvas.drawCircle(cx, cy, 2f * density, ring)
        }

        private companion object {
            val FOUND: Int = Color.rgb(76, 217, 100)
        }
    }

    companion object {
        const val EXTRA_METERS = "meters"
        const val EXTRA_REASON = "reason"
        const val RESULT_UNAVAILABLE = RESULT_FIRST_USER

        private const val TAG = "ArMeasure"
        private const val REQUEST_CAMERA = 1
        private const val NEAR_METERS = 0.1f
        private const val FAR_METERS = 100f

        /** Thoth drops a narrower target, so it isn't offered as a result. */
        private const val MIN_METERS = 0.01

        private val SCRIM = Color.argb(150, 0, 0, 0)
        private const val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
        private const val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT
    }
}

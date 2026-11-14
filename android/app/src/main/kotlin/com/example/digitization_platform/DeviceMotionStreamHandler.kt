package com.example.digitization_platform

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel
import kotlin.math.sqrt

/**
 * Streams where the back camera points and how fast the phone is turning, for Dart's
 * `DeviceMotionChannel`. The 3D scan screen uses it to know which side of an object the
 * operator has reached and whether the phone is still enough to photograph it.
 *
 * Each event is `[x, y, z, rate]`: the camera's viewing direction as a unit vector in a frame
 * whose z axis points up, and the turning rate in radians per second.
 *
 * The game rotation vector, not the plain one: it leaves the compass out, so the steel of a
 * display case or a building cannot swing the heading. Its horizontal zero is arbitrary, which
 * is all a scan needs: angles are only ever compared with the scan's own first photograph.
 */
class DeviceMotionStreamHandler(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val rotationMatrix = FloatArray(9)
    private var events: EventChannel.EventSink? = null
    private var turningRate = 0.0

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        val attitude = sensorManager.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
        val gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        if (attitude == null || gyroscope == null) {
            sink.error(UNAVAILABLE, "This phone has no motion sensors.", null)
            return
        }
        events = sink
        sensorManager.registerListener(this, attitude, SensorManager.SENSOR_DELAY_GAME)
        sensorManager.registerListener(this, gyroscope, SensorManager.SENSOR_DELAY_GAME)
    }

    override fun onCancel(arguments: Any?) {
        sensorManager.unregisterListener(this)
        events = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_GYROSCOPE) {
            val (x, y, z) = event.values
            turningRate = sqrt((x * x + y * y + z * z).toDouble())
            return
        }

        // Some phones append an accuracy value the conversion below rejects.
        val quaternion =
            if (event.values.size > QUATERNION_SIZE) event.values.copyOf(QUATERNION_SIZE) else event.values
        SensorManager.getRotationMatrixFromVector(rotationMatrix, quaternion)

        // The matrix takes the phone's axes to the world's. The back camera looks along the
        // phone's -z, so its direction in the world is minus the matrix's third column.
        events?.success(
            listOf(
                -rotationMatrix[2].toDouble(),
                -rotationMatrix[5].toDouble(),
                -rotationMatrix[8].toDouble(),
                turningRate,
            ),
        )
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    companion object {
        const val UNAVAILABLE = "unavailable"
        private const val QUATERNION_SIZE = 4
    }
}

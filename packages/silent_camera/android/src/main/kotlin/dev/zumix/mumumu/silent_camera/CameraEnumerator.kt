package dev.zumix.mumumu.silent_camera

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager

/** 端末が備えるカメラを列挙する。 */
object CameraEnumerator {
    fun availableCameras(context: Context): List<Map<String, Any>> {
        val manager = context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
            ?: return emptyList()

        return try {
            manager.cameraIdList.map { id ->
                val characteristics = manager.getCameraCharacteristics(id)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                val maxZoom = characteristics
                    .get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM)
                    ?.toDouble() ?: 1.0

                CameraDescriptionData(
                    id = id,
                    lensDirection = when (facing) {
                        CameraCharacteristics.LENS_FACING_FRONT -> LensDirection.FRONT
                        CameraCharacteristics.LENS_FACING_BACK -> LensDirection.BACK
                        else -> LensDirection.EXTERNAL
                    },
                    sensorOrientation = characteristics
                        .get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90,
                    minZoom = 1.0,
                    maxZoom = maxZoom,
                    zoomPresets = listOf(1.0, 2.0).filter { it <= maxZoom },
                    hasFlash = characteristics
                        .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false,
                ).toMap()
            }
        } catch (_: Exception) {
            emptyList()
        }
    }
}

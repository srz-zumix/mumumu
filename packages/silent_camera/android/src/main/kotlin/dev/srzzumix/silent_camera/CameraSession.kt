package dev.srzzumix.silent_camera

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.params.MeteringRectangle
import android.hardware.camera2.params.OutputConfiguration
import android.hardware.camera2.params.SessionConfiguration
import android.media.ImageReader
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Size
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.io.ByteArrayOutputStream
import java.util.Date
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Camera2 を用いたキャプチャセッション。
 *
 * プレビュー用の `SurfaceTexture` と静止画切り出し用の `ImageReader` を
 * 同じリピートリクエストに接続し、シャッター音を伴う撮影 API を使わずに
 * 最新フレームから静止画を生成する。
 */
internal class CameraSession(
    private val context: Context,
    private val activity: Activity,
    private val textureEntry: TextureRegistry.SurfaceTextureEntry,
) {

    companion object {
        private const val MAX_CAPTURE_PIXELS = 12_000_000

        /** 端末で利用できるカメラの一覧。 */
        fun availableCameras(context: Context): List<Map<String, Any?>> {
            val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            return manager.cameraIdList.mapNotNull { id ->
                val characteristics = manager.getCameraCharacteristics(id)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING) ?: return@mapNotNull null
                val maxZoom = characteristics
                    .get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM) ?: 1f
                val zoomRange = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    characteristics.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)
                } else {
                    null
                }
                val minZoom = zoomRange?.lower?.toDouble() ?: 1.0
                val upperZoom = zoomRange?.upper?.toDouble() ?: maxZoom.toDouble()
                mapOf(
                    "id" to id,
                    "lensDirection" to lensDirectionName(facing),
                    "minZoom" to minZoom,
                    "maxZoom" to upperZoom,
                    "zoomPresets" to zoomPresets(minZoom, upperZoom),
                )
            }
        }

        private fun lensDirectionName(facing: Int): String = when (facing) {
            CameraCharacteristics.LENS_FACING_FRONT -> "front"
            CameraCharacteristics.LENS_FACING_EXTERNAL -> "external"
            else -> "back"
        }

        private fun zoomPresets(minZoom: Double, maxZoom: Double): List<Double> {
            val presets = mutableListOf<Double>()
            if (minZoom <= 0.6) {
                presets.add(0.5)
            }
            presets.add(1.0)
            for (candidate in listOf(2.0, 5.0)) {
                if (candidate <= maxZoom) {
                    presets.add(candidate)
                }
            }
            return presets
        }
    }

    private val cameraManager =
        context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val backgroundThread = HandlerThread("silent-camera").apply { start() }
    private val backgroundHandler = Handler(backgroundThread.looper)
    private val executor: Executor = Executors.newSingleThreadExecutor()

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var previewSurface: Surface? = null
    private var characteristics: CameraCharacteristics? = null
    private var requestBuilder: CaptureRequest.Builder? = null
    private var lensDirection: String = "back"
    private var silentMode: Boolean = true
    private var captureSize: Size = Size(0, 0)
    private var flashMode: String = "off"
    private var zoomLevel: Float = 1f
    private var locked: Boolean = false
    private var pendingCapture: PendingCapture? = null

    private class PendingCapture(
        val quality: Int,
        val mirror: Boolean,
        val gallery: MediaStoreGallery,
        val onSaved: (Map<String, Any?>) -> Unit,
        val onError: (String) -> Unit,
    )

    /** カメラを開いてプレビューを開始する。 */
    fun open(
        lensDirection: String,
        captureMode: String,
        aspectRatio: String,
        onReady: (Map<String, Any?>) -> Unit,
        onError: (String) -> Unit,
    ) {
        try {
            this.lensDirection = lensDirection
            silentMode = captureMode != "photo"
            val cameraId = findCameraId(lensDirection)
                ?: throw IllegalStateException("No camera found for $lensDirection")
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            this.characteristics = characteristics

            val ratio = aspectRatioValue(aspectRatio)
            val format = if (silentMode) ImageFormat.YUV_420_888 else ImageFormat.JPEG
            val map = characteristics.get(
                CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP,
            ) ?: throw IllegalStateException("Stream configuration is unavailable.")

            captureSize = chooseSize(map.getOutputSizes(format), ratio, MAX_CAPTURE_PIXELS)
            val previewSize = chooseSize(
                map.getOutputSizes(android.graphics.SurfaceTexture::class.java),
                ratio,
                1920 * 1080,
            )

            val surfaceTexture = textureEntry.surfaceTexture().apply {
                setDefaultBufferSize(previewSize.width, previewSize.height)
            }
            previewSurface = Surface(surfaceTexture)
            imageReader = ImageReader.newInstance(
                captureSize.width,
                captureSize.height,
                format,
                2,
            ).apply {
                setOnImageAvailableListener(::onImageAvailable, backgroundHandler)
            }

            cameraManager.openCamera(
                cameraId,
                object : CameraDevice.StateCallback() {
                    override fun onOpened(device: CameraDevice) {
                        cameraDevice = device
                        startCaptureSession(device, previewSize, onReady, onError)
                    }

                    override fun onDisconnected(device: CameraDevice) {
                        close()
                    }

                    override fun onError(device: CameraDevice, error: Int) {
                        close()
                        onError("Failed to open the camera (code=$error).")
                    }
                },
                backgroundHandler,
            )
        } catch (error: Exception) {
            onError(error.message ?: error.toString())
        }
    }

    /** セッションを閉じ、リソースを解放する。 */
    fun close() {
        pendingCapture = null
        captureSession?.close()
        captureSession = null
        cameraDevice?.close()
        cameraDevice = null
        imageReader?.close()
        imageReader = null
        previewSurface?.release()
        previewSurface = null
        textureEntry.release()
        backgroundThread.quitSafely()
    }

    /** フラッシュ動作を設定する。 */
    fun setFlashMode(mode: String) {
        flashMode = mode
        applyFlash()
        repeatRequest()
    }

    /** ズーム倍率を設定する。 */
    fun setZoomLevel(zoom: Float) {
        val characteristics = characteristics ?: return
        val builder = requestBuilder ?: return
        zoomLevel = zoom
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val range = characteristics.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)
            val clamped = if (range == null) {
                zoom
            } else {
                min(max(zoom, range.lower), range.upper)
            }
            builder.set(CaptureRequest.CONTROL_ZOOM_RATIO, clamped)
        } else {
            val active = characteristics.get(
                CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE,
            ) ?: return
            val maxDigitalZoom = characteristics
                .get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM) ?: 1f
            val clamped = min(max(zoom, 1f), maxDigitalZoom)
            val cropWidth = (active.width() / clamped).toInt()
            val cropHeight = (active.height() / clamped).toInt()
            val left = (active.width() - cropWidth) / 2
            val top = (active.height() - cropHeight) / 2
            builder.set(
                CaptureRequest.SCALER_CROP_REGION,
                Rect(left, top, left + cropWidth, top + cropHeight),
            )
        }
        repeatRequest()
    }

    /** プレビュー座標（0.0〜1.0）にフォーカスと露出を合わせる。 */
    fun setFocusPoint(x: Float, y: Float) {
        val characteristics = characteristics ?: return
        val builder = requestBuilder ?: return
        val active = characteristics.get(
            CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE,
        ) ?: return
        val pointX = (active.width() * x.coerceIn(0f, 1f)).toInt()
        val pointY = (active.height() * y.coerceIn(0f, 1f)).toInt()
        val halfSize = min(active.width(), active.height()) / 12
        val region = MeteringRectangle(
            max(pointX - halfSize, 0),
            max(pointY - halfSize, 0),
            halfSize * 2,
            halfSize * 2,
            MeteringRectangle.METERING_WEIGHT_MAX - 1,
        )
        val regions = arrayOf(region)
        if ((characteristics.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AF) ?: 0) > 0) {
            builder.set(CaptureRequest.CONTROL_AF_REGIONS, regions)
            builder.set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_AUTO)
            builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_START)
        }
        if ((characteristics.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AE) ?: 0) > 0) {
            builder.set(CaptureRequest.CONTROL_AE_REGIONS, regions)
        }
        repeatRequest()
        builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_IDLE)
    }

    /** AE/AF ロックを設定する。 */
    fun setFocusExposureLocked(locked: Boolean) {
        val builder = requestBuilder ?: return
        this.locked = locked
        builder.set(CaptureRequest.CONTROL_AE_LOCK, locked)
        builder.set(
            CaptureRequest.CONTROL_AF_MODE,
            if (locked) {
                CameraMetadata.CONTROL_AF_MODE_AUTO
            } else {
                CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE
            },
        )
        repeatRequest()
    }

    /** 露出補正（EV）を設定する。 */
    fun setExposureOffset(offset: Double) {
        val characteristics = characteristics ?: return
        val builder = requestBuilder ?: return
        val step = characteristics.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP)
            ?: return
        val range = characteristics.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
            ?: return
        val steps = (offset / step.toDouble()).toInt()
        builder.set(
            CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION,
            steps.coerceIn(range.lower, range.upper),
        )
        repeatRequest()
    }

    /** 最新フレームから静止画を生成して保存する。 */
    fun capture(
        format: String,
        quality: Int,
        mirrorFrontCamera: Boolean,
        gallery: MediaStoreGallery,
        onSaved: (Map<String, Any?>) -> Unit,
        onError: (String) -> Unit,
    ) {
        if (captureSession == null) {
            onError("Camera session is not ready.")
            return
        }
        if (format == "heic") {
            // Android では HEIC 保存を提供せず JPEG にフォールバックする。
            android.util.Log.i("SilentCamera", "HEIC is not supported on Android; saving as JPEG.")
        }
        pendingCapture = PendingCapture(
            quality = quality.coerceIn(50, 100),
            mirror = mirrorFrontCamera && lensDirection == "front",
            gallery = gallery,
            onSaved = { info -> runOnUiThread { onSaved(info) } },
            onError = { message -> runOnUiThread { onError(message) } },
        )
        if (!silentMode) {
            triggerStillCapture()
        }
    }

    private fun onImageAvailable(reader: ImageReader) {
        val image = reader.acquireLatestImage() ?: return
        image.use {
            val request = pendingCapture ?: return
            pendingCapture = null
            try {
                val isJpeg = it.format == ImageFormat.JPEG
                val bytes = if (isJpeg) {
                    ImageConverter.jpegBytes(it)
                } else {
                    ImageConverter.yuv420ToJpeg(it, request.quality)
                }
                // 写真モードでは JPEG_ORIENTATION により回転済みのため、回転は適用しない。
                val rotation = if (isJpeg) 0 else jpegOrientation()
                val oriented = applyOrientation(bytes, rotation, request.mirror, request.quality)
                val decodeOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(oriented, 0, oriented.size, decodeOptions)
                request.onSaved(
                    request.gallery.saveJpeg(
                        bytes = oriented,
                        width = decodeOptions.outWidth,
                        height = decodeOptions.outHeight,
                        capturedAt = Date(),
                    ),
                )
            } catch (error: Exception) {
                request.onError(error.message ?: error.toString())
            }
        }
    }

    private fun startCaptureSession(
        device: CameraDevice,
        previewSize: Size,
        onReady: (Map<String, Any?>) -> Unit,
        onError: (String) -> Unit,
    ) {
        val preview = previewSurface ?: return
        val reader = imageReader ?: return
        val outputs = listOf(OutputConfiguration(preview), OutputConfiguration(reader.surface))
        val builder = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
            addTarget(preview)
            if (silentMode) {
                addTarget(reader.surface)
            }
            set(
                CaptureRequest.CONTROL_AF_MODE,
                CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE,
            )
        }
        requestBuilder = builder
        applyFlash()

        device.createCaptureSession(
            SessionConfiguration(
                SessionConfiguration.SESSION_REGULAR,
                outputs,
                executor,
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        captureSession = session
                        repeatRequest()
                        runOnUiThread { onReady(sessionInfo(previewSize)) }
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        runOnUiThread { onError("Failed to configure the capture session.") }
                    }
                },
            ),
        )
    }

    private fun sessionInfo(previewSize: Size): Map<String, Any?> {
        val characteristics = characteristics
        val maxZoom = characteristics
            ?.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM)?.toDouble() ?: 1.0
        val zoomRange = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            characteristics?.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)
        } else {
            null
        }
        val minZoom = zoomRange?.lower?.toDouble() ?: 1.0
        val upperZoom = zoomRange?.upper?.toDouble() ?: maxZoom
        val step = characteristics?.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP)
        val range = characteristics?.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
        val evStep = step?.toDouble() ?: 0.0
        return mapOf(
            "textureId" to textureEntry.id(),
            "previewWidth" to previewSize.width.toDouble(),
            "previewHeight" to previewSize.height.toDouble(),
            "captureMode" to if (silentMode) "silent" else "photo",
            "minExposureOffset" to (range?.lower?.times(evStep) ?: -2.0),
            "maxExposureOffset" to (range?.upper?.times(evStep) ?: 2.0),
            "camera" to mapOf(
                "id" to (cameraDevice?.id ?: ""),
                "lensDirection" to lensDirection,
                "minZoom" to minZoom,
                "maxZoom" to upperZoom,
                "zoomPresets" to zoomPresets(minZoom, upperZoom),
            ),
        )
    }

    private fun triggerStillCapture() {
        val session = captureSession ?: return
        val device = cameraDevice ?: return
        val reader = imageReader ?: return
        val builder = device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE).apply {
            addTarget(reader.surface)
            requestBuilder?.let { source ->
                source.get(CaptureRequest.CONTROL_ZOOM_RATIO)?.let {
                    set(CaptureRequest.CONTROL_ZOOM_RATIO, it)
                }
                source.get(CaptureRequest.SCALER_CROP_REGION)?.let {
                    set(CaptureRequest.SCALER_CROP_REGION, it)
                }
                source.get(CaptureRequest.CONTROL_AE_MODE)?.let {
                    set(CaptureRequest.CONTROL_AE_MODE, it)
                }
                source.get(CaptureRequest.FLASH_MODE)?.let {
                    set(CaptureRequest.FLASH_MODE, it)
                }
            }
            set(CaptureRequest.JPEG_ORIENTATION, jpegOrientation())
        }
        session.capture(builder.build(), null, backgroundHandler)
    }

    private fun applyFlash() {
        val builder = requestBuilder ?: return
        when (flashMode) {
            "on" -> {
                builder.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON_ALWAYS_FLASH)
                builder.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_SINGLE)
            }
            "auto" -> {
                builder.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON_AUTO_FLASH)
                builder.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_OFF)
            }
            "torch" -> {
                builder.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON)
                builder.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_TORCH)
            }
            else -> {
                builder.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON)
                builder.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_OFF)
            }
        }
    }

    private fun repeatRequest() {
        val session = captureSession ?: return
        val builder = requestBuilder ?: return
        session.setRepeatingRequest(builder.build(), null, backgroundHandler)
    }

    /** 端末の向きとセンサー向きから、保存画像に必要な回転角を求める。 */
    @Suppress("DEPRECATION")
    private fun jpegOrientation(): Int {
        val characteristics = characteristics ?: return 0
        val sensorOrientation =
            characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
        val deviceRotation = when (activity.windowManager.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> 90
            Surface.ROTATION_180 -> 180
            Surface.ROTATION_270 -> 270
            else -> 0
        }
        return if (lensDirection == "front") {
            (sensorOrientation + deviceRotation) % 360
        } else {
            (sensorOrientation - deviceRotation + 360) % 360
        }
    }

    private fun applyOrientation(
        jpeg: ByteArray,
        rotation: Int,
        mirror: Boolean,
        quality: Int,
    ): ByteArray {
        if (rotation == 0 && !mirror) {
            return jpeg
        }
        val bitmap = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size) ?: return jpeg
        val matrix = Matrix().apply {
            if (rotation != 0) {
                postRotate(rotation.toFloat())
            }
            if (mirror) {
                postScale(-1f, 1f)
            }
        }
        val rotated = Bitmap.createBitmap(
            bitmap,
            0,
            0,
            bitmap.width,
            bitmap.height,
            matrix,
            true,
        )
        val output = ByteArrayOutputStream()
        rotated.compress(Bitmap.CompressFormat.JPEG, quality, output)
        bitmap.recycle()
        rotated.recycle()
        return output.toByteArray()
    }

    private fun findCameraId(lensDirection: String): String? {
        val target = when (lensDirection) {
            "front" -> CameraCharacteristics.LENS_FACING_FRONT
            "external" -> CameraCharacteristics.LENS_FACING_EXTERNAL
            else -> CameraCharacteristics.LENS_FACING_BACK
        }
        return cameraManager.cameraIdList.firstOrNull { id ->
            cameraManager.getCameraCharacteristics(id)
                .get(CameraCharacteristics.LENS_FACING) == target
        }
    }

    private fun aspectRatioValue(preset: String): Double = when (preset) {
        "ratio16x9" -> 16.0 / 9.0
        "ratio1x1" -> 1.0
        else -> 4.0 / 3.0
    }

    private fun chooseSize(sizes: Array<Size>?, ratio: Double, maxPixels: Int): Size {
        val candidates = sizes?.filter { it.width * it.height <= maxPixels } ?: emptyList()
        if (candidates.isEmpty()) {
            return sizes?.maxByOrNull { it.width * it.height } ?: Size(1280, 720)
        }
        // アスペクト比が近いものを優先し、その中で最大解像度を選ぶ。
        val bestRatioDiff = candidates.minOf { abs(it.width.toDouble() / it.height - ratio) }
        return candidates
            .filter { abs(it.width.toDouble() / it.height - ratio) <= bestRatioDiff + 0.01 }
            .maxByOrNull { it.width * it.height }
            ?: candidates.first()
    }

    private fun runOnUiThread(block: () -> Unit) {
        activity.runOnUiThread(block)
    }
}

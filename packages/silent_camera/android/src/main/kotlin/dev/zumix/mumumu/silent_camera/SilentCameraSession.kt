package dev.zumix.mumumu.silent_camera

import android.annotation.SuppressLint
import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CaptureRequest
import android.util.Size
import androidx.camera.camera2.interop.Camera2CameraControl
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.CaptureRequestOptions
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.Camera
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceOrientedMeteringPointFactory
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import io.flutter.view.TextureRegistry
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.roundToInt

/**
 * CameraX を用いた撮影セッション。
 *
 * 無音撮影では [ImageAnalysis] のフレームを 1 枚取り出して静止画にする。
 */
@SuppressLint("RestrictedApi")
class SilentCameraSession(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
    private val lensDirection: LensDirection,
    private val resolution: CaptureResolution,
    private val captureMode: CaptureMode,
) {
    /** セッション専用のライフサイクル。CameraX のバインドに用いる。 */
    private class SessionLifecycleOwner : LifecycleOwner {
        private val registry = LifecycleRegistry(this)
        override val lifecycle: Lifecycle get() = registry

        fun resume() {
            registry.currentState = Lifecycle.State.RESUMED
        }

        fun destroy() {
            registry.currentState = Lifecycle.State.DESTROYED
        }
    }

    private val lifecycleOwner = SessionLifecycleOwner()
    private val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val scheduler: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor()
    private val mainExecutor = ContextCompat.getMainExecutor(context)
    private val pendingCapture = AtomicReference<((ImageProxy) -> Unit)?>(null)

    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var imageCapture: ImageCapture? = null
    private var surfaceProducer: TextureRegistry.SurfaceProducer? = null
    private var flashMode: FlashMode = FlashMode.OFF
    private var isPreviewPaused = false
    private var previewResolution: Size = Size(1080, 1920)

    val textureId: Long
        get() = surfaceProducer?.id() ?: -1L

    /**
     * カメラをバインドする。
     *
     * @param onResult 初期化結果、または失敗時の例外を受け取る。
     */
    fun initialize(onResult: (Result<Map<String, Any?>>) -> Unit) {
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            try {
                val provider = future.get()
                cameraProvider = provider
                bind(provider)
                onResult(Result.success(initializationMap()))
            } catch (e: Exception) {
                onResult(Result.failure(e))
            }
        }, mainExecutor)
    }

    private fun bind(provider: ProcessCameraProvider) {
        val producer = textureRegistry.createSurfaceProducer()
        surfaceProducer = producer

        val selector = ResolutionSelector.Builder()
            .setAllowedResolutionMode(
                ResolutionSelector.PREFER_HIGHER_RESOLUTION_OVER_CAPTURE_RATE
            )
            .setResolutionStrategy(resolutionStrategy())
            .build()

        val previewUseCase = Preview.Builder()
            .setResolutionSelector(selector)
            .build()
        previewUseCase.setSurfaceProvider { request ->
            val size = request.resolution
            previewResolution = size
            producer.setSize(size.width, size.height)
            request.provideSurface(producer.surface, analysisExecutor) { }
        }
        preview = previewUseCase

        val analysisUseCase = ImageAnalysis.Builder()
            .setResolutionSelector(selector)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()
        analysisUseCase.setAnalyzer(analysisExecutor) { imageProxy ->
            val consumer = pendingCapture.getAndSet(null)
            if (consumer == null) {
                imageProxy.close()
            } else {
                try {
                    consumer(imageProxy)
                } finally {
                    imageProxy.close()
                }
            }
        }
        imageAnalysis = analysisUseCase

        val useCases = mutableListOf(previewUseCase, analysisUseCase)
        if (captureMode == CaptureMode.PHOTO) {
            val captureUseCase = ImageCapture.Builder()
                .setResolutionSelector(selector)
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                .build()
            imageCapture = captureUseCase
            useCases.add(captureUseCase)
        }

        provider.unbindAll()
        lifecycleOwner.resume()
        camera = provider.bindToLifecycle(
            lifecycleOwner,
            lensDirection.toCameraSelector(),
            *useCases.toTypedArray(),
        )
    }

    private fun resolutionStrategy(): ResolutionStrategy = when (resolution) {
        CaptureResolution.MAX -> ResolutionStrategy.HIGHEST_AVAILABLE_STRATEGY
        CaptureResolution.HIGH -> ResolutionStrategy(
            Size(1920, 1080),
            ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
        )

        CaptureResolution.MEDIUM -> ResolutionStrategy(
            Size(1280, 720),
            ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
        )

        CaptureResolution.LOW -> ResolutionStrategy(
            Size(640, 480),
            ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
        )
    }

    @OptIn(ExperimentalCamera2Interop::class)
    private fun initializationMap(): Map<String, Any?> {
        val info = camera?.cameraInfo
        val sensorOrientation = info?.let {
            Camera2CameraInfo.from(it)
                .getCameraCharacteristic(CameraCharacteristics.SENSOR_ORIENTATION)
        } ?: 90
        val quarterTurns = ((sensorOrientation / 90) % 4 + 4) % 4

        // 回転後（画面に表示される向き）のサイズを返す。
        val displayWidth =
            if (quarterTurns % 2 == 1) previewResolution.height else previewResolution.width
        val displayHeight =
            if (quarterTurns % 2 == 1) previewResolution.width else previewResolution.height

        val exposureState = info?.exposureState
        val step = exposureState?.exposureCompensationStep?.toDouble() ?: 0.0
        val range = exposureState?.exposureCompensationRange

        return mapOf(
            "textureId" to textureId,
            "previewWidth" to displayWidth.toDouble(),
            "previewHeight" to displayHeight.toDouble(),
            "previewQuarterTurns" to quarterTurns,
            // CameraX の出力は前面カメラでも鏡像にならないため、表示側で反転する。
            "previewFlipHorizontally" to (lensDirection == LensDirection.FRONT),
            "description" to describeCamera(sensorOrientation).toMap(),
            "minExposureOffset" to (range?.lower ?: 0) * step,
            "maxExposureOffset" to (range?.upper ?: 0) * step,
            "exposureOffsetStep" to step,
        )
    }

    private fun describeCamera(sensorOrientation: Int): CameraDescriptionData {
        val info = camera?.cameraInfo
        val zoomState = info?.zoomState?.value
        val minZoom = zoomState?.minZoomRatio?.toDouble() ?: 1.0
        val maxZoom = zoomState?.maxZoomRatio?.toDouble() ?: 1.0

        val presets = buildList {
            if (minZoom < 1.0) add(maxOf(minZoom, 0.5))
            add(1.0)
            if (maxZoom >= 2.0) add(2.0)
            if (maxZoom >= 5.0) add(5.0)
        }.map { (it * 10).roundToInt() / 10.0 }
            .distinct()
            .filter { it in minZoom..maxZoom }

        return CameraDescriptionData(
            id = lensDirection.value,
            lensDirection = lensDirection,
            sensorOrientation = sensorOrientation,
            minZoom = minZoom,
            maxZoom = maxZoom,
            zoomPresets = presets,
            hasFlash = info?.hasFlashUnit() ?: false,
        )
    }

    // MARK: - 操作

    fun pausePreview() {
        isPreviewPaused = true
        preview?.setSurfaceProvider(null)
    }

    fun resumePreview() {
        if (!isPreviewPaused) return
        isPreviewPaused = false
        val producer = surfaceProducer ?: return
        preview?.setSurfaceProvider { request ->
            val size = request.resolution
            previewResolution = size
            producer.setSize(size.width, size.height)
            request.provideSurface(producer.surface, analysisExecutor) { }
        }
    }

    fun setZoomLevel(zoom: Double) {
        camera?.cameraControl?.setZoomRatio(zoom.toFloat())
    }

    /**
     * フォーカスと露出の測定点を設定する。
     *
     * 引数は画面表示上の 0.0-1.0 座標であり、センサー座標へ変換する。
     */
    fun setFocusAndExposurePoint(x: Double, y: Double, quarterTurns: Int) {
        val control = camera?.cameraControl ?: return
        val (sensorX, sensorY) = when (quarterTurns) {
            1 -> y to (1.0 - x)
            2 -> (1.0 - x) to (1.0 - y)
            3 -> (1.0 - y) to x
            else -> x to y
        }

        val factory = SurfaceOrientedMeteringPointFactory(1f, 1f)
        val point = factory.createPoint(sensorX.toFloat(), sensorY.toFloat())
        val action = FocusMeteringAction.Builder(
            point,
            FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE,
        ).build()
        control.startFocusAndMetering(action)
    }

    @OptIn(ExperimentalCamera2Interop::class)
    fun setFocusAndExposureLocked(locked: Boolean) {
        val control = camera?.cameraControl ?: return
        if (!locked) {
            control.cancelFocusAndMetering()
        }
        val options = CaptureRequestOptions.Builder()
            .setCaptureRequestOption(CaptureRequest.CONTROL_AE_LOCK, locked)
            .setCaptureRequestOption(CaptureRequest.CONTROL_AWB_LOCK, locked)
            .setCaptureRequestOption(
                CaptureRequest.CONTROL_AF_MODE,
                if (locked) {
                    CaptureRequest.CONTROL_AF_MODE_OFF
                } else {
                    CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE
                },
            )
            .build()
        Camera2CameraControl.from(control).setCaptureRequestOptions(options)
    }

    fun setExposureOffset(offsetEv: Double) {
        val control = camera?.cameraControl ?: return
        val state = camera?.cameraInfo?.exposureState ?: return
        val step = state.exposureCompensationStep.toDouble()
        if (step <= 0.0) return
        val index = (offsetEv / step).roundToInt()
            .coerceIn(state.exposureCompensationRange.lower, state.exposureCompensationRange.upper)
        control.setExposureCompensationIndex(index)
    }

    fun setFlashMode(mode: FlashMode) {
        flashMode = mode
        imageCapture?.flashMode = when (mode) {
            FlashMode.ON, FlashMode.TORCH -> ImageCapture.FLASH_MODE_ON
            FlashMode.AUTO -> ImageCapture.FLASH_MODE_AUTO
            FlashMode.OFF -> ImageCapture.FLASH_MODE_OFF
        }
        // 静音撮影では発光の代わりにトーチを用いる。
        camera?.cameraControl?.enableTorch(mode == FlashMode.TORCH)
    }

    // MARK: - 撮影

    fun capture(options: CaptureOptions, onResult: (Result<Map<String, Any?>>) -> Unit) {
        if (captureMode == CaptureMode.PHOTO && imageCapture != null) {
            capturePhoto(options, onResult)
        } else {
            captureFrame(options, onResult)
        }
    }

    private fun captureFrame(
        options: CaptureOptions,
        onResult: (Result<Map<String, Any?>>) -> Unit,
    ) {
        val useTorch = needsTorchForCapture()
        if (useTorch) {
            camera?.cameraControl?.enableTorch(true)
        }

        val consumer: (ImageProxy) -> Unit = { imageProxy ->
            try {
                val bitmap = imageProxy.toBitmap()
                val rotation = imageProxy.imageInfo.rotationDegrees
                val result = ImageWriter.write(
                    context = context,
                    bitmap = bitmap,
                    rotationDegrees = rotation,
                    mirror = lensDirection == LensDirection.FRONT && options.mirrorFrontCamera,
                    options = options,
                )
                onResult(Result.success(result))
            } catch (e: Exception) {
                onResult(Result.failure(e))
            } finally {
                if (useTorch) {
                    mainExecutor.execute { camera?.cameraControl?.enableTorch(false) }
                }
            }
        }

        if (useTorch) {
            // トーチ点灯直後は露出が安定しないため、わずかに待ってからフレームを取得する。
            scheduler.schedule(
                { pendingCapture.set(consumer) },
                TORCH_SETTLE_MILLIS,
                TimeUnit.MILLISECONDS,
            )
        } else {
            pendingCapture.set(consumer)
        }
    }

    private fun capturePhoto(
        options: CaptureOptions,
        onResult: (Result<Map<String, Any?>>) -> Unit,
    ) {
        val useCase = imageCapture ?: run {
            onResult(Result.failure(IllegalStateException("写真モードが初期化されていません。")))
            return
        }
        useCase.takePicture(
            analysisExecutor,
            object : ImageCapture.OnImageCapturedCallback() {
                override fun onCaptureSuccess(image: ImageProxy) {
                    try {
                        val bitmap = image.toBitmap()
                        val result = ImageWriter.write(
                            context = context,
                            bitmap = bitmap,
                            rotationDegrees = image.imageInfo.rotationDegrees,
                            mirror = lensDirection == LensDirection.FRONT &&
                                options.mirrorFrontCamera,
                            options = options,
                        )
                        onResult(Result.success(result))
                    } catch (e: Exception) {
                        onResult(Result.failure(e))
                    } finally {
                        image.close()
                    }
                }

                override fun onError(exception: ImageCaptureException) {
                    onResult(Result.failure(exception))
                }
            },
        )
    }

    /** 撮影時にトーチ照射が必要かどうかを判定する。 */
    private fun needsTorchForCapture(): Boolean = when (flashMode) {
        FlashMode.ON -> true
        // TORCH は既に点灯済み。OFF / AUTO では静音優先で追加照射しない。
        else -> false
    }

    fun release() {
        pendingCapture.set(null)
        camera?.cameraControl?.enableTorch(false)
        imageAnalysis?.clearAnalyzer()
        preview?.setSurfaceProvider(null)
        cameraProvider?.unbindAll()
        lifecycleOwner.destroy()
        surfaceProducer?.release()
        surfaceProducer = null
        camera = null
        scheduler.shutdown()
        analysisExecutor.shutdown()
    }

    private companion object {
        const val TORCH_SETTLE_MILLIS = 220L
    }
}

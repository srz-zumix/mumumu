package dev.zumix.mumumu.silent_camera

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * 無音キャプチャプラグインの Android 実装。
 *
 * 仕様書 2.2 のとおり、`ImageAnalysis` のフレームから静止画を切り出す方式を基本とする。
 */
class SilentCameraPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context
    private lateinit var textureRegistry: TextureRegistry

    private val mainHandler = Handler(Looper.getMainLooper())
    private var activity: Activity? = null
    private var session: SilentCameraSession? = null
    private var previewQuarterTurns = 1

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        textureRegistry = binding.textureRegistry
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        releaseSession()
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()

        when (call.method) {
            "getSilenceCapability" -> result.success(SilenceCapability.current())

            "availableCameras" ->
                result.success(CameraEnumerator.availableCameras(applicationContext))

            "initialize" -> initialize(args, result)

            "dispose" -> {
                releaseSession()
                result.success(null)
            }

            "pausePreview" -> {
                session?.pausePreview()
                result.success(null)
            }

            "resumePreview" -> {
                session?.resumePreview()
                result.success(null)
            }

            "capture" -> capture(args, result)

            "setZoomLevel" -> withSession(result) {
                it.setZoomLevel(args["zoom"] as? Double ?: 1.0)
            }

            "setFocusAndExposurePoint" -> withSession(result) {
                it.setFocusAndExposurePoint(
                    args["x"] as? Double ?: 0.5,
                    args["y"] as? Double ?: 0.5,
                    previewQuarterTurns,
                )
            }

            "setFocusAndExposureLocked" -> withSession(result) {
                it.setFocusAndExposureLocked(args["locked"] as? Boolean ?: false)
            }

            "setExposureOffset" -> withSession(result) {
                it.setExposureOffset(args["offset"] as? Double ?: 0.0)
            }

            "setFlashMode" -> withSession(result) {
                it.setFlashMode(FlashMode.from(args["mode"] as? String))
            }

            "openInGallery" -> {
                val uri = args["uri"] as? String
                if (uri == null) {
                    result.error(ERROR_INVALID_ARGUMENT, "uri が指定されていません。", null)
                } else {
                    openInGallery(uri, result)
                }
            }

            "deleteFromGallery" -> {
                val uri = args["uri"] as? String
                if (uri == null) {
                    result.error(ERROR_INVALID_ARGUMENT, "uri が指定されていません。", null)
                } else {
                    try {
                        result.success(MediaStoreSaver.delete(applicationContext, uri))
                    } catch (e: Exception) {
                        result.error("delete_failed", e.message, null)
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun initialize(args: Map<*, *>, result: MethodChannel.Result) {
        releaseSession()

        val newSession = SilentCameraSession(
            context = applicationContext,
            textureRegistry = textureRegistry,
            lensDirection = LensDirection.from(args["lensDirection"] as? String),
            resolution = CaptureResolution.from(args["resolution"] as? String),
            captureMode = CaptureMode.from(args["captureMode"] as? String),
        )
        session = newSession

        newSession.initialize { outcome ->
            mainHandler.post {
                outcome
                    .onSuccess { map ->
                        previewQuarterTurns = map["previewQuarterTurns"] as? Int ?: 1
                        result.success(map)
                    }
                    .onFailure { error ->
                        releaseSession()
                        result.error("initialize_failed", error.message, null)
                    }
            }
        }
    }

    private fun capture(args: Map<*, *>, result: MethodChannel.Result) {
        val current = session
        if (current == null) {
            result.error(ERROR_NOT_INITIALIZED, "カメラが初期化されていません。", null)
            return
        }

        current.capture(CaptureOptions.from(args)) { outcome ->
            mainHandler.post {
                outcome
                    .onSuccess { result.success(it) }
                    .onFailure { result.error("capture_failed", it.message, null) }
            }
        }
    }

    private fun openInGallery(uriString: String, result: MethodChannel.Result) {
        val current = activity
        if (current == null) {
            result.error(ERROR_NOT_INITIALIZED, "Activity が利用できません。", null)
            return
        }
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(uriString), "image/*")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            current.startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("open_failed", e.message, null)
        }
    }

    private fun withSession(result: MethodChannel.Result, body: (SilentCameraSession) -> Unit) {
        val current = session
        if (current == null) {
            result.error(ERROR_NOT_INITIALIZED, "カメラが初期化されていません。", null)
            return
        }
        try {
            body(current)
            result.success(null)
        } catch (e: Exception) {
            result.error("camera_error", e.message, null)
        }
    }

    private fun releaseSession() {
        session?.release()
        session = null
    }

    private companion object {
        const val CHANNEL_NAME = "dev.zumix.mumumu/silent_camera"
        const val ERROR_NOT_INITIALIZED = "not_initialized"
        const val ERROR_INVALID_ARGUMENT = "invalid_argument"
    }
}

package dev.srzzumix.silent_camera

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Camera2 の ImageReader から取得したフレームを静止画化することで、
 * シャッター音を鳴らさずに撮影する mumumu 専用プラグイン。
 */
class SilentCameraPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    private companion object {
        const val CHANNEL_NAME = "dev.srzzumix.mumumu/silent_camera"
    }

    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context
    private lateinit var textureRegistry: TextureRegistry
    private var activity: Activity? = null
    private var session: CameraSession? = null
    private val gallery: MediaStoreGallery by lazy { MediaStoreGallery(applicationContext) }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        textureRegistry = binding.textureRegistry
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        closeSession()
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        closeSession()
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "availableCameras" -> result.success(CameraSession.availableCameras(applicationContext))
                "silenceCapability" -> result.success(SilenceCapability.describe())
                "initialize" -> initialize(call, result)
                "dispose" -> {
                    closeSession()
                    result.success(null)
                }
                "capture" -> capture(call, result)
                "setFlashMode" -> withSession(result) {
                    it.setFlashMode(call.argument<String>("mode") ?: "off")
                    result.success(null)
                }
                "setZoomLevel" -> withSession(result) {
                    it.setZoomLevel(requireDouble(call, "zoom").toFloat())
                    result.success(null)
                }
                "setFocusPoint" -> withSession(result) {
                    it.setFocusPoint(
                        requireDouble(call, "x").toFloat(),
                        requireDouble(call, "y").toFloat(),
                    )
                    result.success(null)
                }
                "setFocusExposureLocked" -> withSession(result) {
                    it.setFocusExposureLocked(call.argument<Boolean>("locked") ?: false)
                    result.success(null)
                }
                "setExposureOffset" -> withSession(result) {
                    it.setExposureOffset(requireDouble(call, "offset"))
                    result.success(null)
                }
                "openInGallery" -> {
                    val uri = call.argument<String>("uri")
                        ?: throw IllegalArgumentException("uri is required")
                    gallery.openInGallery(activity, uri)
                    result.success(null)
                }
                "deleteCapture" -> {
                    val uri = call.argument<String>("uri")
                        ?: throw IllegalArgumentException("uri is required")
                    gallery.delete(uri)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("silent_camera_error", error.message, null)
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("no_activity", "Activity is not attached.", null)
            return
        }
        closeSession()
        val newSession = CameraSession(
            context = applicationContext,
            activity = currentActivity,
            textureEntry = textureRegistry.createSurfaceTexture(),
        )
        session = newSession
        newSession.open(
            lensDirection = call.argument<String>("lensDirection") ?: "back",
            captureMode = call.argument<String>("captureMode") ?: "silent",
            aspectRatio = call.argument<String>("aspectRatio") ?: "ratio4x3",
            onReady = { info -> result.success(info) },
            onError = { message ->
                closeSession()
                result.error("initialize_failed", message, null)
            },
        )
    }

    private fun capture(call: MethodCall, result: MethodChannel.Result) {
        val current = session
        if (current == null) {
            result.error("no_session", "Camera session is not initialized.", null)
            return
        }
        current.capture(
            format = call.argument<String>("format") ?: "jpeg",
            quality = call.argument<Int>("jpegQuality") ?: 95,
            mirrorFrontCamera = call.argument<Boolean>("mirrorFrontCamera") ?: false,
            gallery = gallery,
            onSaved = { info -> result.success(info) },
            onError = { message -> result.error("capture_failed", message, null) },
        )
    }

    private inline fun withSession(
        result: MethodChannel.Result,
        block: (CameraSession) -> Unit,
    ) {
        val current = session
        if (current == null) {
            result.error("no_session", "Camera session is not initialized.", null)
            return
        }
        block(current)
    }

    private fun requireDouble(call: MethodCall, key: String): Double =
        call.argument<Double>(key) ?: throw IllegalArgumentException("$key is required")

    private fun closeSession() {
        session?.close()
        session = null
    }
}

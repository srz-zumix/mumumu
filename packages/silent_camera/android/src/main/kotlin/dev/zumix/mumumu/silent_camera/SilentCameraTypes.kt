package dev.zumix.mumumu.silent_camera

import android.os.Build
import androidx.camera.core.CameraSelector
import java.util.Locale

/** Dart 側 `CameraLensDirection` に対応する。 */
enum class LensDirection(val value: String) {
    FRONT("front"),
    BACK("back"),
    EXTERNAL("external");

    fun toCameraSelector(): CameraSelector = when (this) {
        FRONT -> CameraSelector.DEFAULT_FRONT_CAMERA
        else -> CameraSelector.DEFAULT_BACK_CAMERA
    }

    companion object {
        fun from(value: String?): LensDirection =
            entries.firstOrNull { it.value == value } ?: BACK

        fun fromFacing(facing: Int?): LensDirection = when (facing) {
            CameraSelector.LENS_FACING_FRONT -> FRONT
            CameraSelector.LENS_FACING_BACK -> BACK
            else -> EXTERNAL
        }
    }
}

/** Dart 側 `FlashMode` に対応する。 */
enum class FlashMode(val value: String) {
    OFF("off"),
    ON("on"),
    AUTO("auto"),
    TORCH("torch");

    companion object {
        fun from(value: String?): FlashMode = entries.firstOrNull { it.value == value } ?: OFF
    }
}

/** Dart 側 `CaptureMode` に対応する。 */
enum class CaptureMode(val value: String) {
    SILENT_VIDEO_FRAME("silentVideoFrame"),
    PHOTO("photo");

    companion object {
        fun from(value: String?): CaptureMode =
            entries.firstOrNull { it.value == value } ?: SILENT_VIDEO_FRAME
    }
}

/** Dart 側 `CaptureResolution` に対応する。 */
enum class CaptureResolution(val value: String, val targetHeight: Int) {
    LOW("low", 480),
    MEDIUM("medium", 720),
    HIGH("high", 1080),
    MAX("max", Int.MAX_VALUE);

    companion object {
        fun from(value: String?): CaptureResolution =
            entries.firstOrNull { it.value == value } ?: MAX
    }
}

/** Dart 側 `CaptureAspectRatio` に対応する。 */
enum class CaptureAspectRatio(val value: String, val ratio: Float) {
    RATIO_4X3("ratio4x3", 4f / 3f),
    RATIO_16X9("ratio16x9", 16f / 9f),
    RATIO_1X1("ratio1x1", 1f);

    companion object {
        fun from(value: String?): CaptureAspectRatio =
            entries.firstOrNull { it.value == value } ?: RATIO_4X3
    }
}

/** Dart 側 `CaptureFormat` に対応する。 */
enum class CaptureFormat(val value: String) {
    JPEG("jpeg"),
    HEIC("heic");

    companion object {
        fun from(value: String?): CaptureFormat =
            entries.firstOrNull { it.value == value } ?: JPEG
    }
}

/** Dart 側 `CaptureOptions` に対応する。 */
data class CaptureOptions(
    val saveToGallery: Boolean,
    val jpegQuality: Int,
    val format: CaptureFormat,
    val aspectRatio: CaptureAspectRatio,
    val mirrorFrontCamera: Boolean,
    val includeLocation: Boolean,
    val albumName: String,
) {
    companion object {
        fun from(arguments: Map<*, *>): CaptureOptions = CaptureOptions(
            saveToGallery = arguments["saveToGallery"] as? Boolean ?: true,
            jpegQuality = (arguments["jpegQuality"] as? Int ?: 95).coerceIn(1, 100),
            format = CaptureFormat.from(arguments["format"] as? String),
            aspectRatio = CaptureAspectRatio.from(arguments["aspectRatio"] as? String),
            mirrorFrontCamera = arguments["mirrorFrontCamera"] as? Boolean ?: false,
            includeLocation = arguments["includeLocation"] as? Boolean ?: false,
            albumName = arguments["albumName"] as? String ?: "mumumu",
        )
    }
}

/** Dart 側 `CameraDescription` に対応する。 */
data class CameraDescriptionData(
    val id: String,
    val lensDirection: LensDirection,
    val sensorOrientation: Int,
    val minZoom: Double,
    val maxZoom: Double,
    val zoomPresets: List<Double>,
    val hasFlash: Boolean,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "id" to id,
        "lensDirection" to lensDirection.value,
        "sensorOrientation" to sensorOrientation,
        "minZoom" to minZoom,
        "maxZoom" to maxZoom,
        "zoomPresets" to zoomPresets,
        "hasFlash" to hasFlash,
    )
}

/**
 * 端末の無音撮影対応状況。仕様書 2.2 / 2.3 に対応する。
 *
 * Android では地域・端末によりシャッター音がシステム強制となるため、
 * ImageAnalysis のフレーム切り出し方式を無音撮影の基本とする。
 */
object SilenceCapability {
    fun current(): Map<String, Any> {
        val region = Locale.getDefault().country
        val enforced = region == "JP" || region == "KR"
        return mapOf(
            "isSilentCaptureSupported" to true,
            "isShutterSoundEnforcedByOs" to enforced,
            "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "note" to if (enforced) {
                "この端末では写真モードのシャッター音を抑止できない場合があります。静音撮影モードをご利用ください。"
            } else {
                ""
            },
        )
    }
}

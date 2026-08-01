package dev.zumix.mumumu.silent_camera

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Matrix
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.core.content.ContextCompat
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * ビットマップの整形・Exif 付与・保存を行う。
 *
 * 仕様書 7「データ / 保存仕様」に対応する。
 */
object ImageWriter {
    private const val TEMP_DIR_NAME = "mumumu_captures"

    /**
     * 撮影結果を一時ファイルへ書き出し、必要に応じてギャラリーへ保存する。
     *
     * @return Dart 側 `CaptureResult` に対応する Map。
     */
    fun write(
        context: Context,
        bitmap: Bitmap,
        rotationDegrees: Int,
        mirror: Boolean,
        options: CaptureOptions,
    ): Map<String, Any?> {
        val oriented = transform(bitmap, rotationDegrees, mirror)
        val cropped = crop(oriented, options.aspectRatio)

        val capturedAt = Date()
        val fileName = FileNameGenerator.make(capturedAt)
        val file = temporaryFile(context, fileName)

        FileOutputStream(file).use { output ->
            cropped.compress(Bitmap.CompressFormat.JPEG, options.jpegQuality, output)
        }

        writeExif(
            file = file,
            capturedAt = capturedAt,
            location = if (options.includeLocation) lastKnownLocation(context) else null,
        )

        val galleryUri = if (options.saveToGallery) {
            MediaStoreSaver.save(context, file, fileName, options.albumName)
        } else {
            null
        }

        return mapOf(
            "filePath" to file.absolutePath,
            "width" to cropped.width,
            "height" to cropped.height,
            "capturedAtEpochMs" to capturedAt.time,
            "fileName" to fileName,
            "galleryUri" to galleryUri,
        )
    }

    /** 回転と左右反転を適用する。 */
    private fun transform(bitmap: Bitmap, rotationDegrees: Int, mirror: Boolean): Bitmap {
        if (rotationDegrees == 0 && !mirror) return bitmap
        val matrix = Matrix().apply {
            if (rotationDegrees != 0) postRotate(rotationDegrees.toFloat())
            if (mirror) postScale(-1f, 1f)
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    /** 指定アスペクト比へ中央クロップする。 */
    private fun crop(bitmap: Bitmap, aspectRatio: CaptureAspectRatio): Bitmap {
        val isPortrait = bitmap.height >= bitmap.width
        // `CaptureAspectRatio` は横基準の比率なので、縦位置では逆数を使う。
        val targetRatio = if (isPortrait) 1f / aspectRatio.ratio else aspectRatio.ratio
        val currentRatio = bitmap.width.toFloat() / bitmap.height.toFloat()
        if (kotlin.math.abs(currentRatio - targetRatio) < 0.001f) return bitmap

        var width = bitmap.width
        var height = bitmap.height
        if (currentRatio > targetRatio) {
            width = (bitmap.height * targetRatio).toInt()
        } else {
            height = (bitmap.width / targetRatio).toInt()
        }
        val x = (bitmap.width - width) / 2
        val y = (bitmap.height - height) / 2
        return Bitmap.createBitmap(bitmap, x, y, width, height)
    }

    private fun temporaryFile(context: Context, fileName: String): File {
        val directory = File(context.cacheDir, TEMP_DIR_NAME)
        if (!directory.exists()) {
            directory.mkdirs()
        }
        return File(directory, fileName)
    }

    private fun writeExif(file: File, capturedAt: Date, location: Location?) {
        val formatter = SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US)
        val timestamp = formatter.format(capturedAt)

        val exif = ExifInterface(file.absolutePath)
        exif.setAttribute(ExifInterface.TAG_DATETIME, timestamp)
        exif.setAttribute(ExifInterface.TAG_DATETIME_ORIGINAL, timestamp)
        exif.setAttribute(ExifInterface.TAG_DATETIME_DIGITIZED, timestamp)
        exif.setAttribute(ExifInterface.TAG_MAKE, Build.MANUFACTURER)
        exif.setAttribute(ExifInterface.TAG_MODEL, Build.MODEL)
        exif.setAttribute(ExifInterface.TAG_SOFTWARE, "mumumu")
        exif.setAttribute(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL.toString(),
        )
        location?.let { exif.setLatLong(it.latitude, it.longitude) }
        exif.saveAttributes()
    }

    /**
     * Exif 付与用の直近位置を取得する。
     *
     * 仕様書 5.2 のとおり、設定が有効かつ権限が付与されている場合のみ利用する。
     */
    private fun lastKnownLocation(context: Context): Location? {
        val granted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) return null

        val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            ?: return null
        return try {
            manager.getProviders(true)
                .mapNotNull { manager.getLastKnownLocation(it) }
                .maxByOrNull { it.time }
        } catch (_: SecurityException) {
            null
        }
    }
}

/** 仕様書 7 の命名規則 `IMG_yyyyMMdd_HHmmss[_n]` に従うファイル名を生成する。 */
object FileNameGenerator {
    private var lastBaseName = ""
    private var sequence = 0

    @Synchronized
    fun make(date: Date): String {
        val formatter = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US)
        val base = "IMG_${formatter.format(date)}"
        if (base == lastBaseName) {
            sequence += 1
        } else {
            lastBaseName = base
            sequence = 0
        }
        val suffix = if (sequence == 0) "" else "_$sequence"
        return "$base$suffix.jpg"
    }
}

/**
 * MediaStore への保存・削除を担当する。
 *
 * 仕様書 7 のとおり `Pictures/mumumu` へ保存する。
 */
object MediaStoreSaver {
    fun save(context: Context, file: File, fileName: String, albumName: String): String? {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/$albumName")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }

        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: return null

        try {
            resolver.openOutputStream(uri)?.use { output ->
                file.inputStream().use { input -> input.copyTo(output) }
            } ?: run {
                resolver.delete(uri, null, null)
                return null
            }
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }

        val done = ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }
        resolver.update(uri, done, null, null)
        return uri.toString()
    }

    fun delete(context: Context, uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        return context.contentResolver.delete(uri, null, null) > 0
    }
}

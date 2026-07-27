package dev.srzzumix.silent_camera

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.app.Activity
import android.net.Uri
import android.provider.MediaStore
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** 撮影結果を MediaStore（`Pictures/mumumu`）へ保存する。 */
internal class MediaStoreGallery(private val context: Context) {

    private companion object {
        const val ALBUM = "mumumu"
        const val RELATIVE_PATH = "Pictures/$ALBUM"
    }

    /** JPEG バイト列を保存し、Dart へ返す情報を組み立てる。 */
    fun saveJpeg(bytes: ByteArray, width: Int, height: Int, capturedAt: Date): Map<String, Any?> {
        val displayName = fileName(capturedAt)
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            put(MediaStore.Images.Media.RELATIVE_PATH, RELATIVE_PATH)
            put(MediaStore.Images.Media.DATE_TAKEN, capturedAt.time)
            put(MediaStore.Images.Media.WIDTH, width)
            put(MediaStore.Images.Media.HEIGHT, height)
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Failed to create a MediaStore entry.")
        try {
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Failed to open the MediaStore entry.")
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
        values.clear()
        values.put(MediaStore.Images.Media.IS_PENDING, 0)
        resolver.update(uri, values, null, null)

        val cacheFile = writeCacheCopy(bytes, displayName)
        return mapOf(
            "uri" to uri.toString(),
            "filePath" to cacheFile.absolutePath,
            "width" to width,
            "height" to height,
            "capturedAt" to capturedAt.time,
        )
    }

    /** システムギャラリーで [uri] を開く。 */
    fun openInGallery(activity: Activity?, uri: String) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (activity == null) {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }
        (activity ?: context).startActivity(intent)
    }

    /** [uri] の画像を削除する。 */
    fun delete(uri: String) {
        val parsed = Uri.parse(uri)
        // 自アプリが作成したエントリのみ削除できる。
        val deleted = context.contentResolver.delete(parsed, null, null)
        if (deleted <= 0) {
            throw IllegalStateException("The image could not be deleted.")
        }
    }

    /** ビューア表示用のキャッシュを最新 1 件だけ残す。 */
    private fun writeCacheCopy(bytes: ByteArray, displayName: String): File {
        val directory = File(context.cacheDir, "captures").apply { mkdirs() }
        directory.listFiles()?.forEach { it.delete() }
        val file = File(directory, displayName)
        file.writeBytes(bytes)
        return file
    }

    private fun fileName(capturedAt: Date): String {
        val formatter = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US)
        return "IMG_${formatter.format(capturedAt)}.jpg"
    }
}

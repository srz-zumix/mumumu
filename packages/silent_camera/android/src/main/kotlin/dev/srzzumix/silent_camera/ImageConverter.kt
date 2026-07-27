package dev.srzzumix.silent_camera

import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import java.io.ByteArrayOutputStream

/** `Image` から JPEG バイト列へ変換するユーティリティ。 */
internal object ImageConverter {

    /** YUV_420_888 の [image] を JPEG バイト列へ変換する。 */
    fun yuv420ToJpeg(image: Image, quality: Int): ByteArray {
        val nv21 = yuv420ToNv21(image)
        val yuvImage = YuvImage(nv21, ImageFormat.NV21, image.width, image.height, null)
        val output = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, image.width, image.height), quality, output)
        return output.toByteArray()
    }

    /** JPEG フォーマットの [image] からバイト列を取り出す。 */
    fun jpegBytes(image: Image): ByteArray {
        val buffer = image.planes[0].buffer
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)
        return bytes
    }

    private fun yuv420ToNv21(image: Image): ByteArray {
        val width = image.width
        val height = image.height
        val ySize = width * height
        val output = ByteArray(ySize + ySize / 2)

        val yPlane = image.planes[0]
        val uPlane = image.planes[1]
        val vPlane = image.planes[2]

        // Y プレーンを行ごとにコピーする（row stride が width と異なる端末があるため）。
        var outputOffset = 0
        val yBuffer = yPlane.buffer
        val yRowStride = yPlane.rowStride
        val yPixelStride = yPlane.pixelStride
        for (row in 0 until height) {
            if (yPixelStride == 1) {
                yBuffer.position(row * yRowStride)
                yBuffer.get(output, outputOffset, width)
                outputOffset += width
            } else {
                for (col in 0 until width) {
                    output[outputOffset++] = yBuffer.get(row * yRowStride + col * yPixelStride)
                }
            }
        }

        // NV21 は VU の順でインターリーブする。
        val uBuffer = uPlane.buffer
        val vBuffer = vPlane.buffer
        val uvHeight = height / 2
        val uvWidth = width / 2
        for (row in 0 until uvHeight) {
            for (col in 0 until uvWidth) {
                val vIndex = row * vPlane.rowStride + col * vPlane.pixelStride
                val uIndex = row * uPlane.rowStride + col * uPlane.pixelStride
                output[outputOffset++] = vBuffer.get(vIndex)
                output[outputOffset++] = uBuffer.get(uIndex)
            }
        }
        return output
    }
}

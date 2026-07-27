package dev.srzzumix.silent_camera

import android.os.Build

/**
 * 端末が無音撮影に対応しているかを判定する。
 *
 * Android では `ro.camera.sound.forced` が 1 の端末（主に日本・韓国向け）で
 * 写真モードのシャッター音が OS により強制される。フレーム切り出し方式では
 * この制約を受けないが、写真モードでは音が鳴る点をアプリ内で明示する。
 */
internal object SilenceCapability {

    fun describe(): Map<String, Any?> {
        val forced = isShutterSoundForced()
        return mapOf(
            "isSilent" to true,
            "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "reason" to if (forced) {
                "この端末は写真モードでのシャッター音が OS により強制されます。無音で撮影するには「無音（フレーム切り出し）」方式をご利用ください。"
            } else {
                null
            },
        )
    }

    private fun isShutterSoundForced(): Boolean = try {
        val systemProperties = Class.forName("android.os.SystemProperties")
        val get = systemProperties.getMethod("get", String::class.java, String::class.java)
        val value = get.invoke(null, "ro.camera.sound.forced", "0") as? String
        value == "1"
    } catch (error: ReflectiveOperationException) {
        false
    }
}

package io.github.sweetbbak.ivonaport

import android.content.Context
import android.util.Log
import java.io.File

/**
 * The IVONA engine with the Amy voice, loaded once per process. The voice data ships in the
 * APK's assets and is copied to app storage on first use: the engine maps it by path.
 */
object IvonaEngine {
    private const val TAG = "ivona-port"
    private val VOICE_FILES = listOf("vox_en_gb_amy22i", "lang_en_gb.dat")

    /** receives each synthesized chunk of 16-bit mono PCM; returns false to stop */
    fun interface AudioSink {
        fun onAudio(buffer: ByteArray, length: Int): Boolean
    }

    init {
        // the bridge needs the engine; older Android versions do not resolve app libraries
        System.loadLibrary("ttsivonavoice")
        System.loadLibrary("ivona_jni")
    }

    private var handle = 0L

    val sampleRate: Int
        get() = if (handle != 0L) nativeSampleRate(handle) else 22050

    /** loads the voice if needed; false when it cannot be loaded */
    @Synchronized
    fun load(context: Context): Boolean {
        if (handle != 0L)
            return true
        val dir = File(context.filesDir, "voice")
        try {
            installVoice(context, dir)
        } catch (e: Exception) {
            Log.e(TAG, "cannot copy the voice data", e)
            return false
        }
        // the certificate check is bypassed in this build: any readable file will do
        val cert = File(context.filesDir, "certificate.txt")
        if (!cert.exists())
            cert.writeText("")
        val lib = File(context.applicationInfo.nativeLibraryDir, "libvoice_en_gb_amy.so")
        handle = nativeInit(lib.path, File(dir, VOICE_FILES[0]).path, cert.path)
        return handle != 0L
    }

    private fun installVoice(context: Context, dir: File) {
        dir.mkdirs()
        for (name in VOICE_FILES) {
            val out = File(dir, name)
            val size = context.assets.openFd("voice/$name").use { it.length }
            if (out.length() == size)
                continue
            val tmp = File(dir, "$name.tmp")
            context.assets.open("voice/$name").use { input ->
                tmp.outputStream().use { input.copyTo(it, 1 shl 20) }
            }
            tmp.renameTo(out)
        }
    }

    /**
     * Synthesizes text into sink. rate, pitch and volume are factors (1 = normal). Returns 0 when
     * done, 1 when stopped, -1 on error. Calls are serialized; stop() may come from any thread.
     */
    @Synchronized
    fun speak(text: String, rate: Float, pitch: Float, volume: Float, sink: AudioSink): Int =
        if (handle == 0L) -1 else nativeSpeak(handle, text, rate, pitch, volume, sink)

    fun stop() {
        val h = handle
        if (h != 0L)
            nativeStop(h)
    }

    @JvmStatic private external fun nativeInit(lib: String, vox: String, cert: String): Long
    @JvmStatic private external fun nativeSampleRate(handle: Long): Int
    @JvmStatic private external fun nativeSpeak(handle: Long, text: String, rate: Float, pitch: Float,
                                                volume: Float, sink: AudioSink): Int
    @JvmStatic private external fun nativeStop(handle: Long)
    @JvmStatic private external fun nativeRelease(handle: Long)
}

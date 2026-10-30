package io.github.sweetbbak.ivonaport

import android.media.AudioFormat
import android.speech.tts.SynthesisCallback
import android.speech.tts.SynthesisRequest
import android.speech.tts.TextToSpeech
import android.speech.tts.TextToSpeechService
import android.speech.tts.Voice
import java.util.Locale

/** Android's system text-to-speech engine interface for the IVONA Amy voice (British English). */
class IvonaTtsService : TextToSpeechService() {
    private val locale = Locale.UK
    private val voiceName = "en-GB-amy"

    override fun onCreate() {
        super.onCreate()
        IvonaEngine.load(this)
    }

    override fun onIsLanguageAvailable(lang: String?, country: String?, variant: String?): Int {
        if (lang == null || !isEnglish(lang))
            return TextToSpeech.LANG_NOT_SUPPORTED
        return if (country != null && (country.equals("GBR", true) || country.equals("GB", true)))
            TextToSpeech.LANG_COUNTRY_AVAILABLE
        else
            TextToSpeech.LANG_AVAILABLE
    }

    override fun onGetLanguage(): Array<String> = arrayOf("eng", "GBR", "")

    override fun onLoadLanguage(lang: String?, country: String?, variant: String?): Int =
        onIsLanguageAvailable(lang, country, variant)

    override fun onGetVoices(): List<Voice> = listOf(
        Voice(voiceName, locale, Voice.QUALITY_HIGH, Voice.LATENCY_LOW, false, emptySet())
    )

    override fun onIsValidVoiceName(voiceName: String?): Int =
        if (voiceName == this.voiceName) TextToSpeech.SUCCESS else TextToSpeech.ERROR

    override fun onLoadVoice(voiceName: String?): Int = onIsValidVoiceName(voiceName)

    override fun onGetDefaultVoiceNameFor(lang: String?, country: String?, variant: String?): String? =
        if (lang != null && isEnglish(lang)) voiceName else null

    override fun onStop() {
        IvonaEngine.stop()
    }

    override fun onSynthesizeText(request: SynthesisRequest, callback: SynthesisCallback) {
        if (!IvonaEngine.load(this)) {
            callback.error(TextToSpeech.ERROR_SERVICE)
            return
        }
        val text = request.charSequenceText?.toString() ?: request.text ?: ""
        // Android's 100 is normal; the engine takes factors (rate about 0.67..4, pitch 0.5..2)
        val rate = (request.speechRate / 100f).coerceIn(0.67f, 4f)
        val pitch = (request.pitch / 100f).coerceIn(0.5f, 2f)
        if (callback.start(IvonaEngine.sampleRate, AudioFormat.ENCODING_PCM_16BIT, 1) != TextToSpeech.SUCCESS)
            return
        val max = callback.maxBufferSize
        val result = IvonaEngine.speak(text, rate, pitch, 1f) { buf, len ->
            var off = 0
            var ok = true
            while (ok && off < len) {
                val n = minOf(max, len - off)
                ok = callback.audioAvailable(buf, off, n) == TextToSpeech.SUCCESS
                off += n
            }
            ok
        }
        if (result < 0)
            callback.error(TextToSpeech.ERROR_SYNTHESIS)
        else
            callback.done()
    }

    private fun isEnglish(lang: String) = lang.equals("eng", true) || lang.equals("en", true)
}

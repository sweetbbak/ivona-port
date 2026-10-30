package io.github.sweetbbak.ivonaport

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.tts.TextToSpeech

/** Tells the TTS settings which languages are installed: British English. */
class CheckVoiceData : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val available = arrayListOf("eng-GBR")
        setResult(TextToSpeech.Engine.CHECK_VOICE_DATA_PASS, Intent()
            .putStringArrayListExtra(TextToSpeech.Engine.EXTRA_AVAILABLE_VOICES, available)
            .putStringArrayListExtra(TextToSpeech.Engine.EXTRA_UNAVAILABLE_VOICES, arrayListOf()))
        finish()
    }
}

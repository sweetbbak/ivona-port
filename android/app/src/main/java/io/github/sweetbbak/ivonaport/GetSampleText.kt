package io.github.sweetbbak.ivonaport

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.tts.TextToSpeech

/** The sentence the TTS settings play to demonstrate the voice. */
class GetSampleText : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(TextToSpeech.LANG_AVAILABLE,
                  Intent().putExtra("sampleText", getString(R.string.sample_text)))
        finish()
    }
}

package io.github.sweetbbak.ivonaport

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import java.io.File

/**
 * Try the voice, and open the system TTS settings to make it the default engine.
 *
 * For testing, started with a "text" extra it synthesizes that text through the system TTS
 * framework into the app's external files directory (out.wav) and logs "synthesized" when done:
 *   adb shell am start -n io.github.sweetbbak.ivonaport/.MainActivity --es text "Hello world."
 * An optional "rate" float extra (1 = normal) overrides the system speech rate for this test.
 */
class MainActivity : Activity() {
    private var tts: TextToSpeech? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val pad = (16 * resources.displayMetrics.density).toInt()
        val status = TextView(this).apply { text = "Loading the voice…" }
        val input = EditText(this).apply { setText(getString(R.string.sample_text)) }
        val speak = Button(this).apply { text = "Speak"; isEnabled = false }
        val settings = Button(this).apply { text = "Text-to-speech settings" }
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad, pad, pad)
            listOf(status, input, speak, settings).forEach { addView(it, MATCH_PARENT, WRAP_CONTENT) }
        })

        tts = TextToSpeech(this, { result ->
            runOnUiThread {
                val ok = result == TextToSpeech.SUCCESS
                status.text = if (ok) "IVONA Amy is ready." else "The engine could not start."
                speak.isEnabled = ok
                intent.getStringExtra("text")?.let {
                    if (intent.hasExtra("rate"))
                        tts?.setSpeechRate(intent.getFloatExtra("rate", 1f))
                    if (ok) synthesizeToFile(it)
                }
            }
        }, packageName)
        speak.setOnClickListener {
            tts?.speak(input.text.toString(), TextToSpeech.QUEUE_FLUSH, null, "test")
        }
        settings.setOnClickListener {
            startActivity(Intent("com.android.settings.TTS_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    private fun synthesizeToFile(text: String) {
        val out = File(getExternalFilesDir(null), "out.wav")
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) {}
            override fun onDone(id: String?) { Log.i("ivona-port", "synthesized ${out.path}") }
            @Deprecated("Deprecated in Java")
            override fun onError(id: String?) { Log.e("ivona-port", "synthesis failed") }
        })
        tts?.synthesizeToFile(text, null, out, "file")
    }

    override fun onDestroy() {
        tts?.shutdown()
        super.onDestroy()
    }
}

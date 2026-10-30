# Android TTS engine

An Android app that installs the IVONA engine with the Amy voice (British English) as a
system-wide text-to-speech engine. It implements Android's `TextToSpeechService`, so TalkBack,
reading apps and anything else using `android.speech.tts` can use it. It runs on Android 5.0
(API 21) or later, on arm64-v8a and x86_64 (the emulator).

## Build

You need the Android SDK with an NDK, and JDK 17 or later. The Gradle wrapper fetches Gradle
8.9.

```
cd android
echo "sdk.dir=$HOME/.local/share/Android/Sdk" > local.properties    # once
./gradlew assembleRelease -Pivona.voiceDir=/path/to/eng.gbr.amy.1.6.101.3
adb install -r app/build/outputs/apk/release/app-release.apk
```

- **Native code.** The build runs the port's `make android-arm64 android-x86_64` for the engine,
  the voice and the JNI bridge.
- **Voice data.** The build copies `vox_en_gb_amy22i` and `lang_en_gb.dat` from `ivona.voiceDir`
  into the APK. You can also set that in `gradle.properties` or with `IVONA_VOICE_DIR`.
- **Do not publish the APK.** It contains the voice data.
- **Signing.** The release build is signed with the debug key, so it installs without any
  signing setup.

Then choose **IVONA Amy (port)** under Settings → Accessibility (or System → Languages) →
Text-to-speech output → Preferred engine. The app's own screen can speak a test sentence and
open those settings.

## How it works

- **`IvonaTtsService`.** The engine for language `eng-GBR`, voice `en-GB-amy`. Android's speech
  rate and pitch (100 = normal) map onto the engine's rate and pitch factors.
- **Streaming and stop.** Audio streams to Android in 0.1 s chunks. Stop requests interrupt
  synthesis between chunks.
- **`IvonaEngine`.** Loads the engine and voice once per process. On first use it copies the
  voice data from the APK's assets to app storage, because the engine maps it by path. Native
  libraries are extracted at install time (`useLegacyPackaging`) for the same reason: the engine
  loads the voice library by path.
- **`ivona_jni.c`.** The JNI bridge, built with the engine by the port's Makefile.
- **`CheckVoiceData`, `GetSampleText`.** The activities the TTS settings call.

Test through the system TTS framework, with no audio device needed:

```
adb shell am start -n io.github.sweetbbak.ivonaport/.MainActivity --es text "'Hello world.'"
adb logcat -s ivona-port            # "synthesized .../files/out.wav"
adb pull /sdcard/Android/data/io.github.sweetbbak.ivonaport/files/out.wav
```

On an Android 35 emulator this output is sample for sample identical to the original IVONA
libraries, with both the x86_64 libraries and the arm64 ones (`adb install --abi arm64-v8a`,
under ARM translation).

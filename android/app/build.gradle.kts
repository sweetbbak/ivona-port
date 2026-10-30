plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// the port's root (android/..): the native libraries are built there by its Makefile
val portRoot: File = rootDir.parentFile
val voiceDir: String? = (findProperty("ivona.voiceDir") as String?) ?: System.getenv("IVONA_VOICE_DIR")
val jniOut = layout.buildDirectory.dir("generated/ivonaJniLibs")
val assetsOut = layout.buildDirectory.dir("generated/ivonaAssets")
val abis = mapOf("arm64-v8a" to "aarch64-linux-android21", "x86_64" to "x86_64-linux-android21")

android {
    namespace = "io.github.sweetbbak.ivonaport"
    compileSdk = 35

    defaultConfig {
        applicationId = "io.github.sweetbbak.ivonaport"
        minSdk = 21
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        ndk { abiFilters += abis.keys }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // a personal build: sign release with the debug key so it installs without setup
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // the engine loads the voice library by path, so the libraries must be extracted on install
    packaging { jniLibs { useLegacyPackaging = true } }
    // the voice data is copied out of the APK on first use; storing it uncompressed is faster
    androidResources { noCompress += listOf("amy22i", "dat") }

    sourceSets["main"].jniLibs.srcDir(jniOut)
    sourceSets["main"].assets.srcDir(assetsOut)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}

// the engine, the voice and the JNI bridge for every ABI, built by the port's Makefile
val buildNative by tasks.registering(Exec::class) {
    workingDir = portRoot
    commandLine("make", "-j${Runtime.getRuntime().availableProcessors()}",
                "android-arm64", "android-x86_64")
}

val copyNative by tasks.registering(Copy::class) {
    dependsOn(buildNative)
    abis.forEach { (abi, triple) ->
        from(portRoot.resolve("build/$triple")) {
            include("libttsivonavoice.so", "libvoice_en_gb_amy.so", "libivona_jni.so")
            into(abi)
        }
    }
    into(jniOut)
}

// the voice data is not in the repository: it comes from ivona.voiceDir / IVONA_VOICE_DIR
val copyVoice by tasks.registering(Copy::class) {
    doFirst {
        if (voiceDir == null || !File(voiceDir, "vox_en_gb_amy22i").isFile ||
            !File(voiceDir, "lang_en_gb.dat").isFile)
            throw GradleException("set ivona.voiceDir (gradle.properties or -P) or IVONA_VOICE_DIR " +
                                  "to the directory with vox_en_gb_amy22i and lang_en_gb.dat")
    }
    from(voiceDir ?: "voice-dir-not-set") { include("vox_en_gb_amy22i", "lang_en_gb.dat") }
    into(assetsOut.map { it.dir("voice") })
}

tasks.named("preBuild") { dependsOn(copyNative, copyVoice) }

/*
 * JNI bridge between the Android TTS service (IvonaEngine.kt) and the IVONA engine: load a
 * voice, synthesize text in chunks handed to a Java callback, stop from another thread.
 */
#include <jni.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <android/log.h>
#include "ivona_tts.h"

#define TAG "ivona-port"

typedef struct engine {
    tts_instance *tts;
    tts_voice *voice;
    int sample_rate;
    atomic_int stop;
} engine;

static void set_param(engine *e, const char *name, float value)
{
    char cmd[64];

    snprintf(cmd, sizeof cmd, "set:%s", name);
    if (!tts_voice_param(e->voice, cmd, &value))
        __android_log_print(ANDROID_LOG_WARN, TAG, "%s = %g: %s", name, value, tts_errmsg());
}

JNIEXPORT jlong JNICALL
Java_io_github_sweetbbak_ivonaport_IvonaEngine_nativeInit(JNIEnv *env, jclass cls,
                                                          jstring jlib, jstring jvox,
                                                          jstring jcert)
{
    const char *lib = (*env)->GetStringUTFChars(env, jlib, NULL);
    const char *vox = (*env)->GetStringUTFChars(env, jvox, NULL);
    const char *cert = (*env)->GetStringUTFChars(env, jcert, NULL);
    engine *e = calloc(1, sizeof(engine));

    (void)cls;
    if (e && (e->tts = tts_create()) && tts_load_certificate_file(e->tts, cert)
        && (e->voice = tts_load_voice(e->tts, lib, vox))) {
        e->sample_rate = tts_voice_sample_rate(e->voice);
    } else {
        __android_log_print(ANDROID_LOG_ERROR, TAG, "cannot load the voice (%s, %s): %s", lib,
                            vox, tts_errmsg());
        if (e && e->tts)
            tts_destroy(e->tts);
        free(e);
        e = NULL;
    }
    (*env)->ReleaseStringUTFChars(env, jlib, lib);
    (*env)->ReleaseStringUTFChars(env, jvox, vox);
    (*env)->ReleaseStringUTFChars(env, jcert, cert);
    return (jlong)(intptr_t)e;
}

JNIEXPORT jint JNICALL
Java_io_github_sweetbbak_ivonaport_IvonaEngine_nativeSampleRate(JNIEnv *env, jclass cls, jlong h)
{
    (void)env, (void)cls;
    return ((engine *)(intptr_t)h)->sample_rate;
}

/* synthesizes text; each chunk goes to callback.onAudio(byte[], int) until it returns false or
 * stop is requested. Returns 0 when done, 1 when stopped, -1 on error. */
JNIEXPORT jint JNICALL
Java_io_github_sweetbbak_ivonaport_IvonaEngine_nativeSpeak(JNIEnv *env, jclass cls, jlong h,
                                                           jstring jtext, jfloat rate,
                                                           jfloat pitch, jfloat volume,
                                                           jobject callback)
{
    engine *e = (engine *)(intptr_t)h;
    jclass cbc = (*env)->GetObjectClass(env, callback);
    jmethodID on_audio = (*env)->GetMethodID(env, cbc, "onAudio", "([BI)Z");
    const char *text = (*env)->GetStringUTFChars(env, jtext, NULL);
    jbyteArray buf = NULL;
    jsize cap = 0;
    tts_streamer *st;
    tts_wave *w;
    int ret = 0;

    (void)cls;
    atomic_store(&e->stop, 0);
    set_param(e, "rate_factor", rate);
    set_param(e, "pitch_factor", pitch);
    set_param(e, "volume_factor", volume);
    st = tts_streamer_start(e->voice, text, -1.0f);
    (*env)->ReleaseStringUTFChars(env, jtext, text);
    if (st == NULL) {
        __android_log_print(ANDROID_LOG_ERROR, TAG, "tts_streamer_start: %s", tts_errmsg());
        return -1;
    }
    while ((w = tts_streamer_synth(st, e->sample_rate / 10)) != NULL) {
        jsize n = (jsize)(w->num_samples * 2);

        if (atomic_load(&e->stop)) {
            tts_wave_delete(w);
            ret = 1;
            break;
        }
        if (n > cap) {
            if (buf)
                (*env)->DeleteLocalRef(env, buf);
            cap = n;
            buf = (*env)->NewByteArray(env, cap);
        }
        (*env)->SetByteArrayRegion(env, buf, 0, n, (const jbyte *)w->samples);
        tts_wave_delete(w);
        if (n && !(*env)->CallBooleanMethod(env, callback, on_audio, buf, n)) {
            ret = 1;
            break;
        }
    }
    if (ret == 0 && tts_errno() != TTS_STATUS_OK)
        ret = -1;
    tts_streamer_stop(st);
    if (buf)
        (*env)->DeleteLocalRef(env, buf);
    return ret;
}

JNIEXPORT void JNICALL
Java_io_github_sweetbbak_ivonaport_IvonaEngine_nativeStop(JNIEnv *env, jclass cls, jlong h)
{
    (void)env, (void)cls;
    atomic_store(&((engine *)(intptr_t)h)->stop, 1);
}

JNIEXPORT void JNICALL
Java_io_github_sweetbbak_ivonaport_IvonaEngine_nativeRelease(JNIEnv *env, jclass cls, jlong h)
{
    engine *e = (engine *)(intptr_t)h;

    (void)env, (void)cls;
    tts_unload_voice(e->voice);
    tts_destroy(e->tts);
    free(e);
}

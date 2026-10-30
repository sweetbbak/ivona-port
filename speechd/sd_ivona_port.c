/*
 * sd_ivona_port: a speech-dispatcher output module for the IVONA engine and the Amy voice.
 *
 * Speaks synchronously (module_speak_sync): the text, which the server sends as SSML, is split at
 * <mark>s and stripped of the remaining tags; each piece is synthesized in short chunks that go
 * to the server as audio (module_tts_output_server), so playback starts at once. Between chunks
 * the module polls the server for STOP. Rate, pitch and volume map onto the engine's voice
 * parameters.
 *
 * Configuration (ivona-port.conf): VoiceDir, the directory with vox_en_gb_amy22i and
 * lang_en_gb.dat, and VoiceLib, the path of libvoice_en_gb_amy.so. Defaults are compiled in.
 */
#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <speech-dispatcher/spd_module_main.h>
#include "ivona_tts.h"

#ifndef IVONA_VOICE_DIR
#define IVONA_VOICE_DIR "/usr/share/ivona-port/voice"
#endif
#ifndef IVONA_VOICE_LIB
#define IVONA_VOICE_LIB "/usr/lib/ivona-port/libvoice_en_gb_amy.so"
#endif

static char voice_dir[1024] = IVONA_VOICE_DIR;
static char voice_lib[1024] = IVONA_VOICE_LIB;
static tts_instance *tts;
static tts_voice *voice;
static int sample_rate;
static volatile int stop_requested;
/* module_process() may handle QUIT while we synthesize (it is called between chunks to see STOP):
 * module_close() then only asks to stop, and the engine is released once synthesis unwinds */
static int speaking, close_pending;
static FILE *debug_fp;

/* speech-dispatcher's -100..100 settings, applied before each message */
static int rate, pitch, volume;

#define DBG(...) do { if (debug_fp) { fprintf(debug_fp, __VA_ARGS__); fputc('\n', debug_fp); \
                                      fflush(debug_fp); } } while (0)

/* ---- configuration ---- */

int module_config(const char *configfile)
{
    char line[1200], key[64], val[1100];
    FILE *f;

    if (configfile == NULL || (f = fopen(configfile, "r")) == NULL)
        return 0;     /* the compiled-in defaults */
    while (fgets(line, sizeof line, f)) {
        if (line[0] == '#' || sscanf(line, "%63s %1099[^\n]", key, val) != 2)
            continue;
        /* values may be quoted */
        if (val[0] == '"') {
            size_t n = strlen(val);
            memmove(val, val + 1, n);
            if (n > 1 && val[n - 2] == '"')
                val[n - 2] = '\0';
        }
        if (strcmp(key, "VoiceDir") == 0)
            snprintf(voice_dir, sizeof voice_dir, "%s", val);
        else if (strcmp(key, "VoiceLib") == 0)
            snprintf(voice_lib, sizeof voice_lib, "%s", val);
    }
    fclose(f);
    return 0;
}

int module_init(char **msg)
{
    char vox[1100];

    snprintf(vox, sizeof vox, "%s/vox_en_gb_amy22i", voice_dir);
    if ((tts = tts_create()) == NULL
        || !tts_load_certificate_file(tts, "/dev/null")   /* the check is bypassed */
        || (voice = tts_load_voice(tts, voice_lib, vox)) == NULL) {
        char buf[2600];

        snprintf(buf, sizeof buf, "IVONA: cannot load the voice (%s, %s): %s", voice_lib, vox,
                 tts_errmsg());
        *msg = strdup(buf);
        return -1;
    }
    sample_rate = tts_voice_sample_rate(voice);
    module_audio_set_server();
    *msg = strdup("IVONA Amy (en-GB) ready");
    return 0;
}

SPDVoice **module_list_voices(void)
{
    static SPDVoice amy = { "Amy", "en-GB", "none" };
    static SPDVoice *voices[] = { &amy, NULL };

    return voices;
}

/* ---- parameters ---- */

int module_set(const char *var, const char *val)
{
    if (strcmp(var, "rate") == 0)
        rate = atoi(val);
    else if (strcmp(var, "pitch") == 0)
        pitch = atoi(val);
    else if (strcmp(var, "volume") == 0)
        volume = atoi(val);
    /* voice, language, punctuation, spelling, cap_let_recogn: one voice, nothing to change */
    return 0;
}

static void set_param(const char *name, float value)
{
    char cmd[64];

    snprintf(cmd, sizeof cmd, "set:%s", name);
    if (!tts_voice_param(voice, cmd, &value))
        DBG("%s = %g: %s", name, value, tts_errmsg());
}

static void apply_params(void)
{
    /* the engine's ranges: rate about 0.67..4, pitch 0.5..2, volume 0..1.6 */
    float r = rate >= 0 ? 1.0f + rate / 100.0f * 2.0f : 1.0f + rate / 100.0f * 0.33f;
    float p = powf(2.0f, pitch / 100.0f);
    float v = volume >= 0 ? 1.0f + volume / 100.0f * 0.6f : 1.0f + volume / 100.0f;

    set_param("rate_factor", r);
    set_param("pitch_factor", p);
    set_param("volume_factor", v);
}

int module_audio_set(const char *var, const char *val)
{
    (void)var, (void)val;
    return 0;         /* audio goes to the server */
}

int module_audio_init(char **status_info)
{
    *status_info = strdup("audio is played by the server");
    return 0;
}

int module_loglevel_set(const char *var, const char *val)
{
    (void)var, (void)val;
    return 0;
}

int module_debug(int enable, const char *file)
{
    if (debug_fp) {
        fclose(debug_fp);
        debug_fp = NULL;
    }
    if (enable && file)
        debug_fp = fopen(file, "w");
    return 0;
}

/* ---- speaking ---- */

/* the text of SSML from p to end, tags removed and entities decoded, into out */
static size_t ssml_text(const char *p, const char *end, char *out)
{
    static const struct { const char *ent; char c; } ents[] = {
        { "&lt;", '<' }, { "&gt;", '>' }, { "&amp;", '&' }, { "&quot;", '"' }, { "&apos;", '\'' },
    };
    char *o = out;
    size_t i;

    while (p < end) {
        if (*p == '<') {
            const char *q = memchr(p, '>', end - p);

            p = q ? q + 1 : end;
            *o++ = ' ';
            continue;
        }
        if (*p == '&') {
            for (i = 0; i < sizeof ents / sizeof ents[0]; i++) {
                size_t n = strlen(ents[i].ent);

                if ((size_t)(end - p) >= n && memcmp(p, ents[i].ent, n) == 0) {
                    *o++ = ents[i].c;
                    p += n;
                    break;
                }
            }
            if (i < sizeof ents / sizeof ents[0])
                continue;
        }
        *o++ = *p++;
    }
    *o = '\0';
    return o - out;
}

/* synthesizes text, sending the audio to the server; 0, or -1 when stopped */
static int speak_text(const char *text)
{
    tts_streamer *st;
    tts_wave *w;
    AudioTrack track;
    const char *s;

    for (s = text; *s && isspace((unsigned char)*s); s++)
        ;
    if (*s == '\0')
        return 0;
    if ((st = tts_streamer_start(voice, text, -1.0f)) == NULL) {
        DBG("tts_streamer_start: %s", tts_errmsg());
        return 0;
    }
    while (!stop_requested && (w = tts_streamer_synth(st, sample_rate / 10)) != NULL) {
        track.bits = 16;
        track.num_channels = 1;
        track.sample_rate = sample_rate;
        track.num_samples = w->num_samples;
        track.samples = (short *)w->samples;
        if (w->num_samples)
            module_tts_output_server(&track, SPD_AUDIO_LE);
        tts_wave_delete(w);
        module_process(STDIN_FILENO, 0);    /* lets the server stop us */
    }
    tts_streamer_stop(st);
    return stop_requested ? -1 : 0;
}

void module_speak_sync(const char *data, size_t bytes, SPDMessageType msgtype)
{
    const char *p = data, *end = data + bytes, *m;
    char *text = malloc(bytes + 1), name[256];

    if (text == NULL) {
        module_speak_error();
        return;
    }
    stop_requested = 0;
    speaking = 1;
    apply_params();
    module_speak_ok();
    module_report_event_begin();
    if (msgtype == SPD_MSGTYPE_SOUND_ICON) {
        module_report_icon(data);
        goto done;
    }
    /* the pieces between <mark name="..."/>s, each followed by its mark */
    while (p < end && !stop_requested) {
        m = strstr(p, "<mark");
        if (m == NULL || m >= end)
            m = end;
        ssml_text(p, m, text);
        if (speak_text(text) < 0)
            break;
        if (m == end)
            break;
        name[0] = '\0';
        sscanf(m, "<mark name=\"%255[^\"]\"", name);
        p = strchr(m, '>');
        p = p ? p + 1 : end;
        if (name[0])
            module_report_index_mark(name);
    }
done:
    speaking = 0;
    free(text);
    if (stop_requested)
        module_report_event_stop();
    else
        module_report_event_end();
    if (close_pending) {
        /* the server said QUIT while we spoke: finish as the library would have */
        module_close();
        exit(0);
    }
}

size_t module_pause(void)
{
    stop_requested = 1;   /* the server resumes from the last index mark */
    return 0;
}

int module_stop(void)
{
    stop_requested = 1;
    return 0;
}

int module_loop(void)
{
    return module_process(STDIN_FILENO, 1);
}

int module_close(void)
{
    if (speaking) {
        stop_requested = 1;
        close_pending = 1;
        return 0;
    }
    close_pending = 0;
    if (voice)
        tts_unload_voice(voice);
    if (tts)
        tts_destroy(tts);
    voice = NULL;
    tts = NULL;
    return 0;
}

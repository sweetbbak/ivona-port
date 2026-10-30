/*
 * Speaks text with the ported engine and voice into a 16-bit mono WAV file.
 *
 *   speak [--voice-lib PATH] [--marks FILE] VOICE_DIR "text" out.wav
 *
 * VOICE_DIR holds the voice data (vox_en_gb_amy22i, lang_en_gb.dat). The voice library
 * defaults to libvoice_en_gb_amy.so next to this program. --marks writes the word, sentence and
 * viseme marks as "type name start end sample" lines, like the decomp's tests/run/tts_run.c, so
 * the two can be compared.
 */
#include <libgen.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "ivona_tts.h"

static void put32(FILE *f, unsigned int v)
{
    unsigned char b[4] = { v, v >> 8, v >> 16, v >> 24 };
    fwrite(b, 1, 4, f);
}

static void put16(FILE *f, unsigned int v)
{
    unsigned char b[2] = { v, v >> 8 };
    fwrite(b, 1, 2, f);
}

static void fail(const char *what)
{
    fprintf(stderr, "%s: %s (status %d)\n", what, tts_errmsg(), tts_errno());
    exit(1);
}

int main(int argc, char **argv)
{
    char self[PATH_MAX], lib[PATH_MAX + 32], vox[PATH_MAX + 32];
    const char *voice_lib = NULL;
    FILE *out, *marks = NULL;
    tts_instance *tts;
    tts_voice *voice;
    tts_streamer *st;
    tts_wave *w;
    unsigned int total = 0, k;
    int rate;
    ssize_t n;

    while (argc > 2 && strncmp(argv[1], "--", 2) == 0) {
        if (strcmp(argv[1], "--voice-lib") == 0)
            voice_lib = argv[2];
        else if (strcmp(argv[1], "--marks") == 0) {
            if ((marks = fopen(argv[2], "w")) == NULL) {
                perror(argv[2]);
                return 1;
            }
        } else {
            fprintf(stderr, "unknown option %s\n", argv[1]);
            return 2;
        }
        argc -= 2;
        argv += 2;
    }
    if (argc != 4) {
        fprintf(stderr, "usage: speak [--voice-lib PATH] [--marks FILE] VOICE_DIR \"text\" out.wav\n");
        return 2;
    }
    if (!voice_lib) {
        if ((n = readlink("/proc/self/exe", self, sizeof self - 1)) < 0) {
            perror("/proc/self/exe");
            return 1;
        }
        self[n] = '\0';
        snprintf(lib, sizeof lib, "%s/libvoice_en_gb_amy.so", dirname(self));
        voice_lib = lib;
    }
    snprintf(vox, sizeof vox, "%s/vox_en_gb_amy22i", argv[1]);

    if ((tts = tts_create()) == NULL)
        fail("tts_create");
    /* the certificate check is bypassed (IVONA_NO_CERT_CHECK): any readable file does */
    if (!tts_load_certificate_file(tts, "/dev/null"))
        fail("tts_load_certificate_file");
    if ((voice = tts_load_voice(tts, voice_lib, vox)) == NULL)
        fail("tts_load_voice");
    rate = tts_voice_sample_rate(voice);
    if ((st = tts_streamer_start(voice, argv[2], -1.0f)) == NULL)
        fail("tts_streamer_start");
    if ((out = fopen(argv[3], "wb")) == NULL) {
        perror(argv[3]);
        return 1;
    }
    fwrite("RIFF\0\0\0\0WAVEfmt ", 1, 16, out);
    put32(out, 16), put16(out, 1), put16(out, 1), put32(out, rate), put32(out, rate * 2);
    put16(out, 2), put16(out, 16);
    fwrite("data\0\0\0\0", 1, 8, out);
    while ((w = tts_streamer_synth(st, (int)(rate * 0.1f))) != NULL) {
        fwrite(w->samples, 2, w->num_samples, out);
        if (marks)
            for (k = 0; k < w->num_marks; k++)
                fprintf(marks, "%d %s %u %u %u\n", (int)w->marks[k].type,
                        w->marks[k].name ? w->marks[k].name : "-", w->marks[k].start_text_offset,
                        w->marks[k].end_text_offset, total + w->marks[k].sample_offset);
        total += w->num_samples;
        tts_wave_delete(w);
    }
    if (tts_errno() != TTS_STATUS_OK)
        fail("tts_streamer_synth");
    fseek(out, 4, SEEK_SET), put32(out, 36 + total * 2);
    fseek(out, 40, SEEK_SET), put32(out, total * 2);
    fclose(out);
    if (marks)
        fclose(marks);
    fprintf(stderr, "%u samples written to %s\n", total, argv[3]);
    tts_streamer_stop(st);
    tts_unload_voice(voice);
    tts_destroy(tts);
    return 0;
}

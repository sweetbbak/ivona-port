#ifndef LANG_CORE_H
#define LANG_CORE_H

#include "cst_features.h"

/* What a language library's init/fini (tts_lang_desc part_init/part_fini) receive: the
 * engine fills it from lang_<lang>.dat (lang_tag.c). One definition for the engine and the voice
 * library; the decomp's copies used int placeholders for the pointers (32-bit only). */
typedef struct lang_core {
    const char *code;               /* the language code, e.g. "en-GB" */
    unsigned char *lex_data;        /* the main lexicon's entries ("lex_data" section) */
    int lex_num_bytes;
    unsigned char *nopsa_data;      /* "lex_nopsa_data" */
    int nopsa_num_bytes;
    cst_features *features;
    cst_features *params;           /* feature functions */
} lang_core;

#endif

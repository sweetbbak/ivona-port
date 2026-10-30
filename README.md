# ivona-port

IVONA's TTS engine (`libttsivonavoice`) and the British English "Amy" voice
(`libvoice_en_gb_amy`), from the matching decompilation of the 32-bit ARM Android libraries,
being ported to 64-bit: x86_64 Linux first, then arm64 Android.

## Where the code comes from

`src/`, `include/`, `exports/` and `build.mk` are **exported** from the decomp repo
(`llm/decomp` in `sweetbbak/open-ivona`) by its `tools/export_port.py`; `EXPORTED_FROM` names
the commit. They are exactly the sources the decomp's runnable 32-bit build compiles. That
build reproduces the original voice library's output byte for byte (the decomp's
`tools/difftest.sh`).

- **Don't edit exported files here.** Fix them in the decomp and re-export
  (`tools/export_port.py ~/dev/ivona-port`). A portability fix there must leave the 32-bit ARM
  code unchanged, for example with an `#ifdef __arm__` guard, so the decomp keeps matching.
- **Port-only files live here:** `Makefile`, `third_party/`, `README.md`, and later platform
  shims and tests.
- **Voice data stays out of git.** That's `vox_en_gb_amy22i` and `lang_en_gb.dat` (from
  `eng.gbr.amy.1.6.101.3/`). Programs take its directory as an argument.

## Building

```
third_party/fetch.sh     # pinned OpenSSL 1.0.2h, curl 7.52.1, PCRE 8.37, Expat 2.2.0, cmp v16, SILK 1.0.8
third_party/build.sh     # static PIC archives into third_party/build/<triple>/lib
make                     # build/<triple>/libttsivonavoice.so and libvoice_en_gb_amy.so
```

For arm64 Android, set `CC`/`CXX` to the NDK's `aarch64-linux-android21-clang(++)`. Note that
OpenSSL 1.0.2 has no Android arm64 target, so `third_party/build.sh` needs a configuration for
it.

## Status

This is the first 64-bit compile (GCC 16, x86_64, before the third-party libraries were
fetched). The engine has 27 errors and the voice library 23, of these kinds:

| Problem | Where | Fix (in the decomp, guarded) |
|---|---|---|
| `register … asm("r5")` pins that only serve matching | metrics.c, wordemb.c, hash.c, cst_synth.c, cst_postlex.c, voice_init.c | a macro that is empty off ARM |
| `android/log.h` | flite/cst_error.c, android_log.cpp | a logging shim for non-Android |
| OpenSSL 3 headers instead of 1.0.2h | isef.c, wavesynth.c | gone once `third_party/` is built |
| GCC 16 strictness: `NULL` without its header, `return;` in a non-void function, a pointer type | ssml_prosody.c, flite/cst_item.c, wavesynth.c | small fixes |

Then come the 64-bit behaviour checks:
- **Pointer/integer casts:** 13 warnings to review.
- **Sizes and offsets:** anything that assumes 32-bit sizes.
- **Plain `char`:** must stay signed (`-fsigned-char`, set in `build.mk`).
- **Floating point:** `-ffp-contract=off`, and libm differences.

The target is output identical to the decomp's 32-bit build on its difftest corpus.

## Known gaps inherited from the decomp

- **PLS lexicons:** not decompiled yet. Amy's two alias lexicons in lang.dat are ignored.
- **SSML input:** switched off.
- **Vorbis (Tremor) voices:** unsupported. Amy uses SILK.

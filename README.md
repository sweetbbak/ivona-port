# ivona-port

IVONA's TTS engine (`libttsivonavoice`) and the British English "Amy" voice
(`libvoice_en_gb_amy`), from the matching decompilation of the 32-bit ARM Android libraries,
being ported to 64-bit: x86_64 Linux first, then arm64 Android.

## Where the code comes from

`src/`, `include/`, `exports/` and `build.mk` started as an **export** from the decomp repo
(`llm/decomp` in `sweetbbak/open-ivona`), by its `tools/export_port.py`. They are exactly the
sources the decomp's runnable 32-bit build compiles; that build reproduces the original voice
library's output byte for byte (the decomp's `tools/difftest.sh`). `EXPORTED_FROM` names the
decomp commit.

The two repos have different goals and are kept separate:

- **The decomp** aims at byte-matching the original ARM code. It never carries portability
  changes.
- **The port** aims at the same behaviour, built easily with any modern compiler on 64-bit.
  Its sources are edited here freely.

To bring in later decomp work, such as newly decompiled functions:

- **The `decomp` branch** holds only pure exports.
- **The export tool** writes to it and refuses to run on any other branch, or on a dirty tree.
- **Merging into `main`** combines the port's fixes with the new code:

```
git switch decomp
<decomp>/tools/export_port.py ~/dev/ivona-port
git add -A && git commit -m "Import from the decomp (<commit>)"
git switch main && git merge decomp
```

The voice data (`vox_en_gb_amy22i`, `lang_en_gb.dat` from `eng.gbr.amy.1.6.101.3/`) is never
committed. Programs take its directory as an argument.

## Layout

- **`src/`, `include/`, `build.mk`:** the engine and the voice (from the decomp, then ported).
- **`src/port/`, `platform/`:** port-only code.
- **`third_party/`:** fetch and build scripts for the pinned third-party libraries.
- **`tools/speak.c`:** a command-line synthesizer. `tools/difftest.sh` compares its output with
  references.
- **`speechd/`:** a speech-dispatcher output module with an installer, for Linux screen readers
  and `spd-say` (see `speechd/README.md`).
- **`android/`:** an Android app that is a system-wide TTS engine (see `android/README.md`).

## Building

```
third_party/fetch.sh     # pinned OpenSSL 1.0.2h, curl 7.52.1, PCRE 8.37, Expat 2.2.0, cmp v16, SILK 1.0.8
third_party/build.sh     # static PIC archives into third_party/build/<triple>/lib
make                     # build/<triple>/libttsivonavoice.so and libvoice_en_gb_amy.so
```

For Android, `make android-arm64` (arm64-v8a) and `make android-x86_64` (the emulator) build
the engine, the voice, the app's JNI bridge and `speak` with the NDK. The third-party libraries
are built too. The NDK is found automatically (see the Makefile).

## Status

**x86_64 Linux and Android (arm64-v8a, x86_64) work.** On every line of `tests/corpus.txt` (23 lines: numbers, dates, money,
abbreviations, homographs, a long paragraph), the native build produces WAVs that are byte
for byte the same as the original 32-bit Android libraries' output. AddressSanitizer and
UBSan report nothing on the corpus.

```
make
build/x86_64-pc-linux-gnu/speak path/to/eng.gbr.amy.1.6.101.3 "Hello world." hello.wav
tools/difftest.sh path/to/eng.gbr.amy.1.6.101.3 REF_DIR   # REF_DIR: NN-orig.wav references
make OUT=build/asan OPT="-O1 -g -fsanitize=address,undefined" LDFLAGS=-fsanitize=address,undefined
```

What the port had to change, and what to watch for when importing more code from the decomp:

- **Per-file struct copies.** The decomp often re-declares a struct in each file, with `int`
  placeholders for pointers or padding to 32-bit offsets. Each struct the engine and voice share
  now has one definition (`include/lang_core.h`, `token_chunk.h`, `mark_queue.h`, the real
  `dom.h`, `ssml_doc.h`, `tts_voxdb.h`, ...).
- **Hard-coded sizes and offsets.** Some code uses literal 32-bit sizes (`vector_new(4, ...)`
  for pointers, `cst_safe_alloc(..., 0x14)`, union-member sizes), `+ 0x10`-style offsets, or
  byte-offset field reads (`F(u, 0x19)` in the target cost). These are now `sizeof`/`offsetof`
  or named fields.
- **Matching tricks.**
  - Register pins and empty `asm` barriers are removed.
  - Functions declared with the wrong return type or no return relied on ARM leaving the result
    in `r0`.
  - One call left out an argument that ARM happened to pass in `r0` (`ssml_doc_new`).
- **Declarations that disagree with definitions.** An LTO build finds them all
  (`make OPT="-O1 -flto=auto -Wlto-type-mismatch" LDFLAGS="-flto=auto -Wlto-type-mismatch"`):
  pointers truncated through `int`, and `int`s passed where `size_t` or pointers are expected.
- **Behaviour the original got from its platform.**
  - `-fwrapv`: signed overflow wraps as on the original.
  - `-fsigned-char`.
  - `-ffp-contract=off`.
  - A float stub returned `int`: ARM soft-float read that as 0.0, x86-64 reads `xmm0`.
  - **`qsort`:** unit candidates are sorted by cost with frequent ties, so the original C
    library's algorithm matters. `src/port/bsd_qsort.c` is bionic's 4.4BSD/FreeBSD qsort, and
    all of IVONA's sorts use it.

Open:
- arm64 Android (NDK) build.
- `isef.c` reads 32-bit words from unaligned file data, which is fine on x86-64 and arm64 but
  is formally undefined.
- The `acoustic.c` noise generator calls `ivona_rand(&seed)` against a definition taking the
  seed by value. That code is not reached for Amy.

## Known gaps inherited from the decomp

- **PLS lexicons:** not decompiled yet. Amy's two alias lexicons in lang.dat are ignored.
- **SSML input:** switched off.
- **Vorbis (Tremor) voices:** unsupported. Amy uses SILK.

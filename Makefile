# Builds IVONA's engine and the Amy voice from the exported sources (build.mk) for the host, or
# for another target with CC/CXX set. Run third_party/fetch.sh and third_party/build.sh first.
#
#   make                 build/<triple>/libttsivonavoice.so, libvoice_en_gb_amy.so, speak
#   make android-arm64   the same for Android arm64-v8a with the NDK (third-party libraries too)
#   make android-x86_64  Android x86_64 (the emulator)
#
# The NDK is ANDROID_NDK_HOME/ANDROID_NDK_ROOT if that is one, else the newest NDK of the SDK
# (ANDROID_SDK_ROOT, ANDROID_HOME, ANDROID_HOME/Sdk, ~/.local/share/Android/Sdk, ~/Android/Sdk).
CC ?= cc
CXX ?= c++
TRIPLE := $(shell $(CC) -dumpmachine)
OUT ?= build/$(TRIPLE)
TPLIB := third_party/build/$(TRIPLE)/lib
TPINC := third_party/build/$(TRIPLE)/include
OPT ?= -O2 -g
LDFLAGS ?=
# OUT can be overridden, e.g. for a sanitizer build: make OUT=build/asan OPT="-O1 -g -fsanitize=address,undefined" LDFLAGS=-fsanitize=address,undefined
# -ffp-contract=off: no fused multiply-add, so floating point rounds as on the original
# Android has <android/log.h> and liblog; elsewhere platform/linux stands in for them
ANDROID := $(findstring android,$(TRIPLE))
PLATFORM_INC := $(if $(ANDROID),,-Iplatform/linux)
PLATFORM_LIBS := $(if $(ANDROID),-llog -static-libstdc++,-lpthread)
# -fwrapv: signed overflow wraps as in the original machine code (decompiled code relies on it)
BASE := $(OPT) -fPIC -ffunction-sections -fdata-sections -ffp-contract=off -fno-strict-aliasing -fwrapv \
        -Iinclude -Iinclude/flite $(PLATFORM_INC) -I$(TPINC)
CSTD := -std=gnu99
CXXSTD := -fno-exceptions -fno-rtti

include build.mk

# port-only sources, in both libraries
PORT_SRCS := src/port/bsd_qsort.c

ENGINE_OBJS := $(patsubst %,$(OUT)/engine/%.o,$(LIBTTSIVONAVOICE_SRCS) $(PORT_SRCS))
VOICE_OBJS := $(patsubst %,$(OUT)/voice/%.o,$(LIBVOICE_EN_GB_AMY_SRCS) $(PORT_SRCS))

all: $(OUT)/libttsivonavoice.so $(OUT)/libvoice_en_gb_amy.so $(OUT)/speak

$(OUT)/engine/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(BASE) $(CSTD) $(LIBTTSIVONAVOICE_FLAGS) $(LIBTTSIVONAVOICE_$<_FLAGS) -c $< -o $@
$(OUT)/engine/%.cpp.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(BASE) $(CXXSTD) $(LIBTTSIVONAVOICE_FLAGS) $(LIBTTSIVONAVOICE_$<_FLAGS) -c $< -o $@
$(OUT)/voice/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(BASE) $(CSTD) $(LIBVOICE_EN_GB_AMY_FLAGS) $(LIBVOICE_EN_GB_AMY_$<_FLAGS) -c $< -o $@

$(OUT)/libttsivonavoice.so: $(ENGINE_OBJS)
	$(CXX) $(LDFLAGS) -shared -o $@ $^ -Wl,--no-undefined -Wl,--gc-sections -Wl,--version-script=exports/libttsivonavoice.exports \
	    -Wl,-soname,libttsivonavoice.so $(TPLIB)/libcrypto.a $(TPLIB)/libcurl.a $(TPLIB)/libexpat.a \
	    $(TPLIB)/libpcre.a $(TPLIB)/libsilk.a $(TPLIB)/libcmp.a -ldl -lm $(PLATFORM_LIBS)
$(OUT)/libvoice_en_gb_amy.so: $(VOICE_OBJS)
	$(CC) $(LDFLAGS) -shared -o $@ $^ -Wl,--no-undefined -Wl,--gc-sections -Wl,--version-script=exports/libvoice_en_gb_amy.exports \
	    -Wl,-soname,libvoice_en_gb_amy.so $(TPLIB)/libpcre.a $(TPLIB)/libsilk.a $(TPLIB)/libcmp.a \
	    -ldl -lm $(PLATFORM_LIBS)

# Android: the JNI bridge of the TTS app (android/)
$(OUT)/libivona_jni.so: android/app/src/main/c/ivona_jni.c $(OUT)/libttsivonavoice.so
	$(CC) $(OPT) -fPIC -shared -Iinclude -o $@ $< -L$(OUT) -lttsivonavoice -llog -Wl,--no-undefined

# the test program: speak [--voice-lib PATH] [--marks FILE] VOICE_DIR "text" out.wav
$(OUT)/speak: tools/speak.c $(OUT)/libttsivonavoice.so
	$(CC) $(OPT) $(LDFLAGS) -Iinclude -o $@ tools/speak.c -L$(OUT) -lttsivonavoice -Wl,-rpath,'$$ORIGIN'

clean:
	rm -rf build

# Android: the NDK's clang for API 21
# (the first candidate that really is an SDK / NDK: these variables are often set to a parent)
SDK_CANDIDATES := $(ANDROID_SDK_ROOT) $(ANDROID_HOME) $(ANDROID_HOME)/Sdk \
                  $(HOME)/.local/share/Android/Sdk $(HOME)/Android/Sdk
ANDROID_SDK := $(firstword $(foreach d,$(SDK_CANDIDATES),$(if $(wildcard $(d)/platforms),$(d))))
NDK_CANDIDATES := $(ANDROID_NDK_HOME) $(ANDROID_NDK_ROOT) \
                  $(lastword $(sort $(wildcard $(ANDROID_SDK)/ndk/*)))
NDK := $(firstword $(foreach d,$(NDK_CANDIDATES),$(if $(wildcard $(d)/toolchains/llvm),$(d))))
NDK_BIN = $(NDK)/toolchains/llvm/prebuilt/linux-x86_64/bin
android-arm64 android-x86_64: android-%:
	@test -d "$(NDK_BIN)" || { echo "no NDK found (set ANDROID_NDK_HOME to it)" >&2; exit 1; }
	CC=$(NDK_BIN)/$(ANDROID_ABI_$*)21-clang third_party/build.sh
	$(MAKE) CC=$(NDK_BIN)/$(ANDROID_ABI_$*)21-clang CXX=$(NDK_BIN)/$(ANDROID_ABI_$*)21-clang++ \
	    $(addprefix build/$(ANDROID_ABI_$*)21/,libttsivonavoice.so libvoice_en_gb_amy.so libivona_jni.so speak) \
	    OUT=build/$(ANDROID_ABI_$*)21
ANDROID_ABI_arm64 = aarch64-linux-android
ANDROID_ABI_x86_64 = x86_64-linux-android

.PHONY: all clean android-arm64 android-x86_64

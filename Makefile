# Builds IVONA's engine and the Amy voice from the exported sources (build.mk) for the host, or
# for another target with CC/CXX set. Run third_party/fetch.sh and third_party/build.sh first.
#
#   make                 build/<triple>/libttsivonavoice.so, libvoice_en_gb_amy.so
#   make CC=aarch64-linux-android21-clang CXX=aarch64-linux-android21-clang++
CC ?= cc
CXX ?= c++
TRIPLE := $(shell $(CC) -dumpmachine)
OUT ?= build/$(TRIPLE)
TPLIB := third_party/build/$(TRIPLE)/lib
OPT ?= -O2 -g
LDFLAGS ?=
# OUT can be overridden, e.g. for a sanitizer build: make OUT=build/asan OPT="-O1 -g -fsanitize=address,undefined" LDFLAGS=-fsanitize=address,undefined
# -ffp-contract=off: no fused multiply-add, so floating point rounds as on the original
# Android has <android/log.h> and liblog; elsewhere platform/linux stands in for them
ANDROID := $(findstring android,$(TRIPLE))
PLATFORM_INC := $(if $(ANDROID),,-Iplatform/linux)
PLATFORM_LIBS := $(if $(ANDROID),-llog,)
BASE := $(OPT) -fPIC -ffunction-sections -fdata-sections -ffp-contract=off -fno-strict-aliasing \
        -Iinclude -Iinclude/flite $(PLATFORM_INC)
CSTD := -std=gnu99
CXXSTD := -fno-exceptions -fno-rtti

include build.mk

ENGINE_OBJS := $(patsubst %,$(OUT)/engine/%.o,$(LIBTTSIVONAVOICE_SRCS))
VOICE_OBJS := $(patsubst %,$(OUT)/voice/%.o,$(LIBVOICE_EN_GB_AMY_SRCS))

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
	    $(TPLIB)/libpcre.a $(TPLIB)/libsilk.a $(TPLIB)/libcmp.a -ldl -lm -lpthread $(PLATFORM_LIBS)
$(OUT)/libvoice_en_gb_amy.so: $(VOICE_OBJS)
	$(CC) $(LDFLAGS) -shared -o $@ $^ -Wl,--no-undefined -Wl,--gc-sections -Wl,--version-script=exports/libvoice_en_gb_amy.exports \
	    -Wl,-soname,libvoice_en_gb_amy.so $(TPLIB)/libpcre.a $(TPLIB)/libsilk.a $(TPLIB)/libcmp.a \
	    -ldl -lm $(PLATFORM_LIBS)

# the test program: speak [--voice-lib PATH] [--marks FILE] VOICE_DIR "text" out.wav
$(OUT)/speak: tools/speak.c $(OUT)/libttsivonavoice.so
	$(CC) $(OPT) $(LDFLAGS) -Iinclude -o $@ tools/speak.c -L$(OUT) -lttsivonavoice -Wl,-rpath,'$$ORIGIN'

clean:
	rm -rf build

.PHONY: all clean

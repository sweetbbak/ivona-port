# Builds IVONA's engine and the Amy voice from the exported sources (build.mk) for the host, or
# for another target with CC/CXX set. Run third_party/fetch.sh and third_party/build.sh first.
#
#   make                 build/<triple>/libttsivonavoice.so, libvoice_en_gb_amy.so
#   make CC=aarch64-linux-android21-clang CXX=aarch64-linux-android21-clang++
CC ?= cc
CXX ?= c++
TRIPLE := $(shell $(CC) -dumpmachine)
OUT := build/$(TRIPLE)
TPLIB := third_party/build/$(TRIPLE)/lib
OPT ?= -O2 -g
# -ffp-contract=off: no fused multiply-add, so floating point rounds as on the original
BASE := $(OPT) -fPIC -ffunction-sections -fdata-sections -ffp-contract=off -fno-strict-aliasing \
        -Iinclude -Iinclude/flite
CSTD := -std=gnu99
CXXSTD := -fno-exceptions -fno-rtti

include build.mk

ENGINE_OBJS := $(patsubst %,$(OUT)/engine/%.o,$(LIBTTSIVONAVOICE_SRCS))
VOICE_OBJS := $(patsubst %,$(OUT)/voice/%.o,$(LIBVOICE_EN_GB_AMY_SRCS))

all: $(OUT)/libttsivonavoice.so $(OUT)/libvoice_en_gb_amy.so

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
	$(CXX) -shared -o $@ $^ -Wl,--gc-sections -Wl,--version-script=exports/libttsivonavoice.exports \
	    -Wl,-soname,libttsivonavoice.so $(TPLIB)/libcrypto.a $(TPLIB)/libcurl.a $(TPLIB)/libexpat.a \
	    $(TPLIB)/libpcre.a $(TPLIB)/libsilk.a $(TPLIB)/libcmp.a -ldl -lm -lpthread
$(OUT)/libvoice_en_gb_amy.so: $(VOICE_OBJS)
	$(CC) -shared -o $@ $^ -Wl,--gc-sections -Wl,--version-script=exports/libvoice_en_gb_amy.exports \
	    -Wl,-soname,libvoice_en_gb_amy.so $(TPLIB)/libpcre.a $(TPLIB)/libsilk.a $(TPLIB)/libcmp.a \
	    -ldl -lm

clean:
	rm -rf build

.PHONY: all clean

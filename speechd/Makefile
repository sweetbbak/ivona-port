# speech-dispatcher output module for the IVONA engine and the Amy voice.
#
#   make                                  build sd_ivona_port against ../build/<triple>
#   sudo make install VOICE_DIR=/path/to/eng.gbr.amy.1.6.101.3
#   sudo make uninstall
#
# install puts the engine and voice libraries in $(LIBDIR), the voice data (copied from
# VOICE_DIR: it is not distributed with the sources) in $(VOICEDIR), the module in
# speech-dispatcher's module directory and its configuration in $(CONFDIR). speech-dispatcher
# then lists it as "ivona-port" (spd-say -O); select it with spd-say -o ivona-port or in
# speechd.conf (DefaultModule ivona-port).
CC ?= cc
PREFIX ?= /usr/local
LIBDIR ?= $(PREFIX)/lib/ivona-port
VOICEDIR ?= $(PREFIX)/share/ivona-port/voice
MODULEDIR ?= $(shell pkg-config --variable=modulebindir speech-dispatcher)
CONFDIR ?= /etc/speech-dispatcher/modules
TRIPLE := $(shell $(CC) -dumpmachine)
PORT := ..
BUILD := $(PORT)/build/$(TRIPLE)
VOICE_FILES := vox_en_gb_amy22i lang_en_gb.dat

CFLAGS ?= -O2 -g -Wall
CPPFLAGS += -I$(PORT)/include $(shell pkg-config --cflags speech-dispatcher) -idirafter compat \
            -DIVONA_VOICE_DIR='"$(VOICEDIR)"' -DIVONA_VOICE_LIB='"$(LIBDIR)/libvoice_en_gb_amy.so"'
LDLIBS += -L$(BUILD) -lttsivonavoice -lspeechd_module -lm -Wl,-rpath,$(LIBDIR)

all: sd_ivona_port ivona-port.conf

$(BUILD)/libttsivonavoice.so $(BUILD)/libvoice_en_gb_amy.so:
	$(MAKE) -C $(PORT)

sd_ivona_port: sd_ivona_port.c $(BUILD)/libttsivonavoice.so
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LDLIBS)

ivona-port.conf: ivona-port.conf.in
	sed -e 's|@VOICEDIR@|$(VOICEDIR)|' -e 's|@LIBDIR@|$(LIBDIR)|' $< > $@

install: all $(BUILD)/libvoice_en_gb_amy.so
	@test -n "$(VOICE_DIR)" || { echo "set VOICE_DIR to the directory with $(VOICE_FILES)" >&2; exit 1; }
	@for f in $(VOICE_FILES); do test -f "$(VOICE_DIR)/$$f" || { echo "missing $(VOICE_DIR)/$$f" >&2; exit 1; }; done
	@test -n "$(MODULEDIR)" || { echo "speech-dispatcher's module directory not found (pkg-config)" >&2; exit 1; }
	install -d $(DESTDIR)$(LIBDIR) $(DESTDIR)$(VOICEDIR) $(DESTDIR)$(MODULEDIR) $(DESTDIR)$(CONFDIR)
	install -m 755 $(BUILD)/libttsivonavoice.so $(BUILD)/libvoice_en_gb_amy.so $(DESTDIR)$(LIBDIR)/
	for f in $(VOICE_FILES); do install -m 644 "$(VOICE_DIR)/$$f" $(DESTDIR)$(VOICEDIR)/; done
	install -m 755 sd_ivona_port $(DESTDIR)$(MODULEDIR)/
	install -m 644 ivona-port.conf $(DESTDIR)$(CONFDIR)/

uninstall:
	rm -f $(DESTDIR)$(MODULEDIR)/sd_ivona_port $(DESTDIR)$(CONFDIR)/ivona-port.conf
	rm -rf $(DESTDIR)$(LIBDIR) $(DESTDIR)$(VOICEDIR)

clean:
	rm -f sd_ivona_port ivona-port.conf

.PHONY: all install uninstall clean

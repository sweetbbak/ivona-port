#!/usr/bin/env bash
# Builds the engine, the voice and the speech-dispatcher module, and installs them system-wide.
#
#   speechd/install.sh /path/to/eng.gbr.amy.1.6.101.3 [PREFIX]     (PREFIX default /usr/local)
#
# The voice directory must hold vox_en_gb_amy22i and lang_en_gb.dat. Installing needs root; the
# script asks sudo for that step only. Afterwards: spd-say -o ivona-port "Hello world"
set -euo pipefail
cd "$(dirname "$0")/.."
VOICE_DIR=$(realpath "${1:?usage: $0 VOICE_DIR [PREFIX]}")
PREFIX=${2:-/usr/local}
for f in vox_en_gb_amy22i lang_en_gb.dat; do
    [ -f "$VOICE_DIR/$f" ] || { echo "missing $VOICE_DIR/$f" >&2; exit 1; }
done
command -v pkg-config >/dev/null && pkg-config --exists speech-dispatcher || {
    echo "speech-dispatcher's development files are needed (pkg-config speech-dispatcher)" >&2; exit 1; }
[ -d third_party/openssl-1.0.2h ] || third_party/fetch.sh
third_party/build.sh
make -j"$(nproc)"
make -C speechd PREFIX="$PREFIX"
sudo make -C speechd install PREFIX="$PREFIX" VOICE_DIR="$VOICE_DIR"
# a running speech-dispatcher only sees new modules after a restart (it starts again on demand)
pkill -u "$USER" -x speech-dispatcher 2>/dev/null || true
echo
echo "Installed. Try:  spd-say -o ivona-port \"Hello world\""
echo "To make it the default, add  DefaultModule ivona-port  to ~/.config/speech-dispatcher/speechd.conf"
echo "(or /etc/speech-dispatcher/speechd.conf)."

#!/usr/bin/env bash
# Speaks a few sentences with the port's speak, then runs the vocoder pass over each, so that
# out/NN.wav (the engine), out/NN.bigvgan.wav and out/NN.smooth.wav can be compared by ear.
#
#   experiments/neural_vocoder/demo.sh VOICE_DIR ["your own sentence" ...]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
VOICE_DIR=${1:?usage: $0 VOICE_DIR [sentences...]}
shift
[ -x "$HERE/.venv/bin/python" ] || "$HERE/setup.sh"
SPEAK=$ROOT/build/$(${CC:-cc} -dumpmachine)/speak
[ -x "$SPEAK" ] || make -C "$ROOT" -j"$(nproc)"
if [ $# -eq 0 ]; then
    set -- "Crime rates fell sharply this year, according to the police." \
           "The quick brown fox jumps over the lazy dog." \
           "Once upon a time, in a land far, far away, there lived a king who had three daughters."
fi
mkdir -p "$HERE/out"
n=0
for text in "$@"; do
    n=$((n + 1))
    f=$(printf '%s/out/%02d' "$HERE" $n)
    "$SPEAK" --marks "$f.marks" "$VOICE_DIR" "$text" "$f.wav" 2>/dev/null
    echo "$text" > "$f.txt"
    "$HERE/.venv/bin/python" "$HERE/resynth.py" "$f.wav" --marks "$f.marks"
done

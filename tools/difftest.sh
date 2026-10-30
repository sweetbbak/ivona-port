#!/usr/bin/env bash
# Differential test: every line of the corpus spoken by this build must be byte-identical to a
# reference WAV made by the original 32-bit libraries (or the decomp's runnable build, which
# matches them).
#
#   tools/difftest.sh VOICE_DIR REF_DIR [CORPUS]
#
# REF_DIR holds NN-orig.wav for corpus line NN (01, 02, ...), as the decomp's tools/difftest.sh
# leaves them in its build/difftest/. Output: PASS/DIFF per line, exit 1 unless all pass.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOICE_DIR=$1 REF=$2 CORPUS=${3:-$ROOT/tests/corpus.txt}
SPEAK=$ROOT/build/$(${CC:-cc} -dumpmachine)/speak
OUT=$ROOT/build/difftest
mkdir -p "$OUT"
pass=0 total=0
while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    total=$((total + 1))
    n=$(printf '%02d' $total)
    short=$(printf '%.60s' "$line")
    if ! "$SPEAK" "$VOICE_DIR" "$line" "$OUT/$n.wav" > "$OUT/$n.log" 2>&1 </dev/null; then
        echo "FAIL $n (see $OUT/$n.log): $short"
    elif cmp -s "$OUT/$n.wav" "$REF/$n-orig.wav"; then
        echo "PASS $n $short"; pass=$((pass + 1))
    else
        echo "DIFF $n ($(stat -c%s "$REF/$n-orig.wav") vs $(stat -c%s "$OUT/$n.wav") bytes): $short"
    fi
done < "$CORPUS"
echo "$pass/$total byte-identical"
[ "$pass" = "$total" ]

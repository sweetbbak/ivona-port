#!/usr/bin/env bash
# Builds the third-party libraries as static, position-independent archives for one target into
# third_party/build/<triple>/{lib,include}, with the feature options the original was built with
# (decomp: config/vendor.yaml). Run fetch.sh first.
#
#   third_party/build.sh                       # the host
#   CC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang \
#       third_party/build.sh                   # Android arm64 (likewise x86_64-linux-android21)
#
# Every target builds in its own directory (OpenSSL 1.0.2 from a copy of its tree, the others
# configured out of tree), so several targets can coexist.
set -euo pipefail
cd "$(dirname "$0")"
TP=$PWD
CC=${CC:-cc}
AR=${AR:-$(dirname "$(command -v "$CC")")/llvm-ar}
[ -x "$AR" ] || AR=ar
TRIPLE=$($CC -dumpmachine)
OUT=$TP/build/$TRIPLE
mkdir -p "$OUT/lib" "$OUT/include" "$OUT/obj" "$OUT/src"
CF="-O2 -fPIC ${EXTRA_CFLAGS:-}"
# these 2016-era libraries and their configure tests predate C99-strict compilers (GCC 14+, new
# clang make implicit int / implicit declarations errors): keep those diagnostics as warnings
CF="$CF -Wno-error=implicit-int -Wno-error=implicit-function-declaration \
    -Wno-error=incompatible-pointer-types -Wno-error=int-conversion"
case "$TRIPLE" in
    *android*) HOST=$(echo "$TRIPLE" | sed 's/-unknown//; s/[0-9]*$//') ;;   # aarch64-linux-android
    *) HOST= ;;
esac

# OpenSSL 1.0.2h libcrypto: RSA/SHA/HMAC/RAND only (no-err no-engine no-dsa no-dh no-ec*)
if [ ! -f "$OUT/lib/libcrypto.a" ]; then
    case "$TRIPLE" in
        x86_64-*) target=linux-x86_64 ;;
        aarch64-*) target=linux-aarch64 ;;
        *) target=linux-generic64 ;;
    esac
    rm -rf "$OUT/src/openssl"
    cp -r openssl-1.0.2h "$OUT/src/openssl"
    (cd "$OUT/src/openssl"
     ./Configure "$target" no-shared no-asm no-err no-engine no-dsa no-dh no-ec no-ecdh no-ecdsa \
         -fPIC >/dev/null
     make -s depend CC="$CC" >/dev/null 2>&1
     make -s build_crypto CC="$CC" AR="$AR r" RANLIB=true >/dev/null)
    cp "$OUT/src/openssl/libcrypto.a" "$OUT/lib/"
    rm -rf "$OUT/include/openssl"
    cp -rL "$OUT/src/openssl/include/openssl" "$OUT/include/openssl"
fi

autobuild() {  # name lib-path-in-build-dir configure-args...
    local name=$1 lib=$2 src; shift 2
    src=$(ls -d "$TP/$name"-[0-9]*)
    [ -f "$OUT/lib/$(basename "$lib")" ] && return
    rm -rf "$OUT/src/$name"
    mkdir -p "$OUT/src/$name"
    (cd "$OUT/src/$name" && CC="$CC" AR="$AR" CFLAGS="$CF" CPPFLAGS="${EXTRA_CPPFLAGS:-}" \
        "$src/configure" -q ${HOST:+--host=$HOST} \
        "$@" >/dev/null && make -s >/dev/null)
    cp "$OUT/src/$name/$lib" "$OUT/lib/"
}
autobuild curl lib/.libs/libcurl.a --disable-shared --enable-static --disable-ipv6 \
    --disable-crypto-auth --disable-cookies --disable-proxy --disable-ftp --disable-telnet \
    --disable-tftp --disable-smb --without-ssl --without-zlib --without-libidn2 --without-libpsl \
    --without-librtmp --without-libssh2 --without-nghttp2 --without-gssapi --without-ca-bundle \
    --without-ca-path --disable-ldap --disable-ldaps --without-libidn
# sljit flushes the instruction cache with bionic's cacheflush(), which only 32-bit ARM has:
# use the compiler's builtin everywhere (a forced include: make would mangle the macro's parens)
echo '#define SLJIT_CACHE_FLUSH(from, to) __builtin___clear_cache((char *)(from), (char *)(to))' \
    > "$OUT/sljit_flush.h"
EXTRA_CPPFLAGS="-include $OUT/sljit_flush.h" \
autobuild pcre .libs/libpcre.a --disable-shared --enable-static --disable-cpp --enable-utf \
    --enable-unicode-properties --disable-stack-for-recursion --enable-newline-is-any --enable-jit
autobuild expat .libs/libexpat.a --disable-shared --enable-static
cp expat-2.2.0/lib/expat.h expat-2.2.0/lib/expat_external.h "$OUT/include/"

# SILK (fixed point) and cmp have no build system worth using: compile the sources directly
if [ ! -f "$OUT/lib/libsilk.a" ]; then
    rm -f "$OUT"/obj/SKP_*.o
    for f in silk-sdk-fix-1.0.8/src/*.c; do
        $CC $CF -Isilk-sdk-fix-1.0.8/interface -c "$f" -o "$OUT/obj/$(basename "${f%.c}").o"
    done
    "$AR" rcs "$OUT/lib/libsilk.a" "$OUT"/obj/SKP_*.o
fi
if [ ! -f "$OUT/lib/libcmp.a" ]; then
    $CC $CF -std=gnu99 -c cmp-16/cmp.c -o "$OUT/obj/cmp.o"
    "$AR" rcs "$OUT/lib/libcmp.a" "$OUT/obj/cmp.o"
fi
echo "third-party libraries in $OUT"

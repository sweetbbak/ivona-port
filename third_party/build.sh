#!/usr/bin/env bash
# Builds the third-party libraries as static, position-independent archives for the host (or
# for CC/HOST set in the environment) into third_party/build/<triple>/lib, with the feature
# options the original was built with (decomp: config/vendor.yaml). Run fetch.sh first.
set -euo pipefail
cd "$(dirname "$0")"
TP=$PWD
CC=${CC:-cc}
TRIPLE=${TRIPLE:-$($CC -dumpmachine)}
OUT=$TP/build/$TRIPLE
mkdir -p "$OUT/lib" "$OUT/obj"
CF="-O2 -fPIC ${EXTRA_CFLAGS:-}"
HOSTARG=${HOST:+--host=$HOST}

# OpenSSL 1.0.2h libcrypto: RSA/SHA/HMAC/RAND only (no-err no-engine no-dsa no-dh no-ec*)
if [ ! -f "$OUT/lib/libcrypto.a" ]; then
    case "$TRIPLE" in
        x86_64-*linux*) target=linux-x86_64 ;;
        aarch64-*linux-android*) target=android64-aarch64 ;;   # no such target in 1.0.2: see README
        aarch64-*linux*) target=linux-aarch64 ;;
        *) target=linux-generic64 ;;
    esac
    (cd openssl-1.0.2h && make -s clean >/dev/null 2>&1 || true
     ./Configure "$target" no-shared no-asm no-err no-engine no-dsa no-dh no-ec no-ecdh no-ecdsa \
         -fPIC >/dev/null && make -s depend >/dev/null && make -s build_crypto CC="$CC" >/dev/null)
    cp openssl-1.0.2h/libcrypto.a "$OUT/lib/"
fi

autobuild() {  # dir lib-path configure-args...
    local d=$1 lib=$2; shift 2
    [ -f "$OUT/lib/$(basename "$lib")" ] && return
    (cd "$d" && CC="$CC" CFLAGS="$CF" ./configure -q $HOSTARG "$@" >/dev/null && make -s >/dev/null)
    cp "$d/$lib" "$OUT/lib/"
}
autobuild curl-7.52.1 lib/.libs/libcurl.a --disable-shared --enable-static --disable-ipv6 \
    --disable-crypto-auth --disable-cookies --disable-proxy --disable-ftp --disable-telnet \
    --disable-tftp --disable-smb --without-ssl --without-zlib --without-libidn2 --without-libpsl \
    --without-librtmp --without-libssh2 --without-nghttp2 --without-gssapi --without-ca-bundle \
    --without-ca-path
autobuild pcre-8.37 .libs/libpcre.a --disable-shared --enable-static --disable-cpp --enable-utf \
    --enable-unicode-properties --disable-stack-for-recursion --enable-newline-is-any --enable-jit
autobuild expat-2.2.0 lib/.libs/libexpat.a --disable-shared --enable-static

# SILK (fixed point) and cmp have no build system worth using: compile the sources directly
if [ ! -f "$OUT/lib/libsilk.a" ]; then
    rm -f "$OUT"/obj/SKP_*.o
    for f in silk-sdk-fix-1.0.8/src/*.c; do
        $CC $CF -Isilk-sdk-fix-1.0.8/interface -c "$f" -o "$OUT/obj/$(basename "${f%.c}").o"
    done
    ar rcs "$OUT/lib/libsilk.a" "$OUT"/obj/SKP_*.o
fi
if [ ! -f "$OUT/lib/libcmp.a" ]; then
    $CC $CF -std=gnu99 -c cmp-16/cmp.c -o "$OUT/obj/cmp.o"
    ar rcs "$OUT/lib/libcmp.a" "$OUT/obj/cmp.o"
fi
echo "third-party libraries in $OUT/lib"

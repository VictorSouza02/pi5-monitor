#!/bin/bash
# Build the Pi5 Monitor daemon (armv7, iOS 9) into native/pi5mon. Host: macOS with Command Line Tools.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk}"
cd "$ROOT/native"
# Embed the page pre-gzipped; its hash is the ETag, so an unchanged page costs a 304.
gzip -9 -n -c index.html > index.html.gz
{
  echo "#define INDEX_ETAG \"$(shasum index.html.gz | cut -c1-12)\""
  xxd -i -n index_gz index.html.gz
} > index_gz.h
rm index.html.gz
# The macOS SDK headers are ABI-compatible for these POSIX/BSD calls; libSystem comes from the
# device-derived tbd stub. The A5 is armv7: build for the builtin armv7s target, then patch below.
clang -target armv7s-apple-ios9.0 -isysroot "$SDK" -Wno-incompatible-sysroot -mcpu=cortex-a9 -Os -Wall -c pi5mon.c -o pi5mon.o
ld -arch armv7s -ios_version_min 9.0 -dead_strip -o pi5mon pi5mon.o "$ROOT/sdk/tbd/libSystem.B.dylib.tbd" 2>&1 | grep -v "warning: object file" || true
strip pi5mon 2>/dev/null || true
# Mach-O cpusubtype ARM_V7S (0x0B) -> ARM_V7 (0x09) so the A5 accepts the binary.
python3 -c "import struct,sys;f=open(sys.argv[1],'r+b');f.seek(8);f.write(struct.pack('<I',9));f.close()" pi5mon
rm -f pi5mon.o
ls -la pi5mon

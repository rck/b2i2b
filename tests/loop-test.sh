#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Roland Kammerer <roland.kammerer@linbit.com>
#
# End-to-end test for b2i2b using loop devices.
# Must run as root. Needs losetup, mkfs.ext4, cmp and zstd (xz optional).
#
#   sudo tests/loop-test.sh

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
B2I="$here/../b2i"
I2B="$here/../i2b"

# ---------------------------------------------------------------------------
# setup / teardown
# ---------------------------------------------------------------------------

(( EUID == 0 )) || { echo "must run as root" >&2; exit 1; }
for t in losetup blockdev mkfs.ext4 cmp zstd; do
    command -v "$t" >/dev/null || { echo "missing tool: $t" >&2; exit 1; }
done
command -v pv >/dev/null || echo "note: pv not installed, progress falls back to dd" >&2

work=$(mktemp -d /tmp/b2i2b-test.XXXXXX)
mnt_src=$work/mnt-src
mnt_dst=$work/mnt-dst
mkdir -p "$mnt_src" "$mnt_dst"

loops=()
cleanup() {
    set +e
    umount "$mnt_src" "$mnt_dst" 2>/dev/null
    (( ${#loops[@]} )) && losetup -d "${loops[@]}" 2>/dev/null
    rm -rf "$work"
}
trap cleanup EXIT

mkloop() {  # mkloop <size> -> prints loop device
    local f
    f=$(mktemp "$work/backing.XXXXXX")
    truncate -s "$1" "$f"
    local dev
    dev=$(losetup --find --show "$f")
    loops+=("$dev")
    echo "$dev"
}

# zero_dev <dev>: wipe a block device. dd without count would run into
# ENOSPC and exit non-zero, which set -e turns into a test abort.
zero_dev() {
    local bytes
    bytes=$(blockdev --getsize64 "$1")
    dd if=/dev/zero of="$1" bs=1M count=$(( bytes / 1048576 )) status=none
}

# ---------------------------------------------------------------------------
# assertions
# ---------------------------------------------------------------------------

pass=0; fail=0
ok()   { echo "ok   - $*"; ((pass++)) || true; }
nok()  { echo "FAIL - $*"; ((fail++)) || true; }

# expect_ok <desc> <cmd...>
expect_ok() {
    local desc=$1; shift
    if "$@" >"$work/out" 2>&1; then ok "$desc"; else nok "$desc"; sed 's/^/       /' "$work/out"; fi
}
# expect_fail <desc> <pattern> <cmd...>  : command must fail and stderr must match pattern
expect_fail() {
    local desc=$1 pat=$2; shift 2
    if "$@" >"$work/out" 2>&1; then
        nok "$desc (unexpectedly succeeded)"
    elif grep -q -- "$pat" "$work/out"; then
        ok "$desc"
    else
        nok "$desc (failed, but message did not match '$pat')"; sed 's/^/       /' "$work/out"
    fi
}
# expect_warn <desc> <pattern> <cmd...>  : command must succeed and stderr must match pattern
expect_warn() {
    local desc=$1 pat=$2; shift 2
    if "$@" >"$work/out" 2>&1 && grep -q -- "$pat" "$work/out"; then
        ok "$desc"
    else
        nok "$desc"; sed 's/^/       /' "$work/out"
    fi
}

# ---------------------------------------------------------------------------
# tests
# ---------------------------------------------------------------------------

echo "# preparing source device"
src=$(mkloop 64M)
mkfs.ext4 -q "$src"
mount "$src" "$mnt_src"
echo "hello from b2i2b" > "$mnt_src/marker.txt"
dst=$(mkloop 64M)
small=$(mkloop 32M)
echo "# src=$src dst=$dst small=$small"

echo "# b2i"
expect_warn "b2i warns when source is mounted" "is in use" \
    "$B2I" "$src" "$work/mounted.zst"
rm -f "$work/mounted.zst"
umount "$mnt_src"

expect_ok "b2i zstd" "$B2I" "$src" "$work/test.zst"
expect_fail "b2i refuses existing image" "already exists" \
    "$B2I" "$src" "$work/test.zst"
expect_ok "b2i -f overwrites" "$B2I" -f "$src" "$work/test.zst"
expect_ok "b2i raw" "$B2I" "$src" "$work/test.img"
if cmp -s "$src" "$work/test.img"; then ok "raw image identical to device"; else nok "raw image differs"; fi
if command -v xz >/dev/null; then
    expect_ok "b2i xz" "$B2I" "$src" "$work/test.xz"
fi
expect_fail "b2i rejects non-device source" "not a block device" \
    "$B2I" "$work/test.img" "$work/x.zst"
expect_fail "b2i rejects device as target" "did you mean i2b" \
    "$B2I" "$src" "$dst"

echo "# i2b"
expect_ok "i2b zstd" "$I2B" "$work/test.zst" "$dst"
if cmp -s "$src" "$dst"; then ok "zstd round trip identical"; else nok "zstd round trip differs"; fi
mount "$dst" "$mnt_dst"
if [[ $(cat "$mnt_dst/marker.txt") == "hello from b2i2b" ]]; then ok "restored fs mounts and holds marker"; else nok "marker missing"; fi
expect_fail "i2b refuses mounted target" "is in use" \
    "$I2B" "$work/test.zst" "$dst"
umount "$mnt_dst"

zero_dev "$dst"
expect_ok "i2b raw" "$I2B" "$work/test.img" "$dst"
if cmp -s "$src" "$dst"; then ok "raw round trip identical"; else nok "raw round trip differs"; fi
if [[ -e $work/test.xz ]]; then
    zero_dev "$dst"
    expect_ok "i2b xz" "$I2B" "$work/test.xz" "$dst"
    if cmp -s "$src" "$dst"; then ok "xz round trip identical"; else nok "xz round trip differs"; fi
fi
expect_fail "i2b refuses raw image larger than device" "larger than the device" \
    "$I2B" "$work/test.img" "$small"
expect_fail "i2b rejects device as source" "did you mean b2i" \
    "$I2B" "$src" "$dst"
expect_fail "i2b rejects missing image" "does not exist" \
    "$I2B" "$work/nope.zst" "$dst"

echo
echo "# $pass passed, $fail failed"
(( fail == 0 ))

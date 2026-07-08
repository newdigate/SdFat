#!/bin/sh
set -e
QEMU=~/Development/rt1170/evkb/tools/qrun
DIR=$(cd "$(dirname "$0")" && pwd)
. ~/Development/rt1170/evkb/tools/gate-lib.sh
gate_init
ELF="$DIR/build/sd_block_test.elf"; OUT="$DIR/sd_block.uart"; IMG="$DIR/card.img"
rm -f "$OUT"
# 4 GB sparse raw image -> QEMU presents an SDHC (block-addressed) card, matching
# a real microSD.  Sparse: costs no disk until written.
[ -f "$IMG" ] || mkfile -n 4g "$IMG"
"$QEMU" -M mimxrt1170-evk -global fsl-imxrt1170.boot-xip=on -kernel "$ELF" \
    -display none -serial file:"$OUT" \
    -drive if=sd,format=raw,file="$IMG" \
    -d guest_errors,unimp -D "$DIR/sd_block.dbg" &
P=$!; gate_pid $P; sleep 5; kill $P 2>/dev/null; wait $P 2>/dev/null || true
echo "==== captured ===="; cat "$OUT"
grep -q "SD_INIT=PASS"      "$OUT" || { echo "FAIL: init";      exit 1; }
grep -q "SD_BLOCK_PIO=PASS" "$OUT" || { echo "FAIL: PIO block"; exit 1; }
grep -q "SD_BLOCK_DMA=PASS" "$OUT" || { echo "FAIL: DMA block"; exit 1; }
echo "PASS: SD raw block RW verified (init + PIO + SDMA)"

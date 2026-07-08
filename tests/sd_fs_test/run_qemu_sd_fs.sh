#!/bin/sh
set -e
QEMU=~/Development/rt1170/evkb/tools/qrun
DIR=$(cd "$(dirname "$0")" && pwd)
. ~/Development/rt1170/evkb/tools/gate-lib.sh
gate_init
ELF="$DIR/build/sd_fs_test.elf"; OUT="$DIR/sd_fs.uart"; IMG="$DIR/card.img"

# Build a fresh MBR-partitioned FAT card image each run.  This SdFat mounts only
# MBR partition 1 (FsVolume::begin defaults part=1; there is no superfloppy
# fallback), so a bare FAT boot sector at LBA 0 -- what mformat/newfs_msdos
# produce -- will NOT mount.  Create an MBR with one primary FAT16 partition
# using macOS-native tools: attach the raw image as a device, partition+format
# it, then detach.  The firmware then creates/reads its own file in partition 1.
rm -f "$OUT" "$IMG"
mkfile -n 512m "$IMG"                                   # 512 MB sparse (<=2GB -> SDSC)
DISK=$(hdiutil attach -nomount -imagekey diskimage-class=CRawDiskImage "$IMG" \
    | head -1 | awk '{print $1}')
[ -n "$DISK" ] || { echo "FAIL: could not attach $IMG as a device"; exit 1; }
diskutil partitionDisk "$DISK" 1 MBR "MS-DOS FAT16" RTTEST 100% >/dev/null \
    || { hdiutil detach "$DISK" >/dev/null 2>&1 || true; echo "FAIL: partition/format"; exit 1; }
hdiutil detach "$DISK" >/dev/null

"$QEMU" -M mimxrt1170-evk -global fsl-imxrt1170.boot-xip=on -kernel "$ELF" \
    -display none -serial file:"$OUT" \
    -drive if=sd,format=raw,file="$IMG" \
    -d guest_errors,unimp -D "$DIR/sd_fs.dbg" &
P=$!; gate_pid $P; sleep 6; kill $P 2>/dev/null; wait $P 2>/dev/null || true
echo "==== captured ===="; cat "$OUT"
grep -q "SD_FS_WRITE=PASS" "$OUT" || { echo "FAIL: fs write"; exit 1; }
grep -q "SD_FS_READ=PASS"  "$OUT" || { echo "FAIL: fs read";  exit 1; }
grep -q "SD_FS_DIR=PASS"   "$OUT" || { echo "FAIL: fs dir";   exit 1; }
# Host-side interop proof (best-effort, non-fatal): re-attach the image with the
# macOS FAT driver and list partition 1's root, showing the firmware-written file
# really landed in the FAT.  mdir (mtools) is used instead when available.
if command -v mdir >/dev/null 2>&1; then
    echo "---- host mdir ----"; mdir -i "$IMG@@1s" :: 2>/dev/null || mdir -i "$IMG" :: 2>/dev/null || true
else
    HOSTATTACH=$(hdiutil attach -imagekey diskimage-class=CRawDiskImage "$IMG" 2>/dev/null || true)
    HOSTDISK=$(echo "$HOSTATTACH" | head -1 | awk '{print $1}')
    HOSTMNT=$(echo "$HOSTATTACH" | grep -o '/Volumes/[^[:space:]]*' | head -1)
    if [ -n "$HOSTMNT" ]; then
        echo "---- host FAT listing ($HOSTMNT) ----"; ls -la "$HOSTMNT" 2>/dev/null || true
        echo "---- rttest.txt ----"; cat "$HOSTMNT/rttest.txt" 2>/dev/null || true; echo
    fi
    [ -n "$HOSTDISK" ] && { hdiutil detach "$HOSTDISK" >/dev/null 2>&1 || true; }
fi
echo "PASS: SD FAT filesystem verified (write + read-back + dir)"

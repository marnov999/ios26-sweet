#!/bin/bash
# pkg-davinci.sh RUN NAME [EXTRA_BOOT_ARGS]
#   -> /home/marnov/xmiphones/ios26/img/davinci-ios26-NAME.img, for a RAM test only:
#      fastboot -s 800f46c3 boot davinci-ios26-NAME.img   (nothing here flashes anything)
# The xnu-12377 kernel of CI run RUN (marnov999/ios26-sweet) in davinci's iOS 16 boot chain, unchanged: the shim
# kernel and DTB of the flashed gpu195af image, MIUI's own kernel/ramdisk/cmdline behind the payload (charger mode
# and the boot menu's MIUI entry), and the davinci ADT (iPhone X identity for now; iPhone 11's comes with the root).
# Boot-args: the bring-up set, read-only (no ufsrw, no rootrw): the kernel mounts the iOS root from iosdata
# without writing to it. The framebuffer console stays on the panel; the UDP console goes to the host's :5140.
set -euo pipefail
RUN=$1 NAME=$2 EXTRA=${3:-}
W=/home/marnov/xmiphones/devtools/work
P=$W/power198                       # gpu195af parts: unpack195af/{kernel,dtb}, miui-{Image,ramdisk,cmdline}
T=$(cd "$(dirname "$0")" && pwd)
O=/home/marnov/xmiphones/ios26/img
B=$O/build-$NAME
mkdir -p "$O" "$B"
GH=/home/marnov/xmiphones/devtools/gh/bin/gh
LOG=$B/ci-$RUN.log
env -u GH_TOKEN $GH run view "$RUN" -R marnov999/ios26-sweet --log > "$LOG"
for p in 0100-sweet-new-files 0101-sweet-apple-edits; do
	grep -q "Applying patch: .*$p.patch" "$LOG" || { echo "$p not applied"; exit 1; }
	! grep -q "Skipping patch .*$p.patch" "$LOG" || { echo "$p skipped"; exit 1; }
done
rm -rf "$B/out" && env -u GH_TOKEN $GH run download "$RUN" -R marnov999/ios26-sweet -n xnu-kernel -D "$B/out"
K=$B/out/kernel.development.sweet
[ -s "$K" ] || { echo "no kernel in run $RUN"; exit 1; }
CMDLINE="rd=ufsroot0 ufsroot=iosdata debug=0xc serial=3 cpus=8 keepsyms=1 -v wdt=-1 sweetfb_hz=60 sweetusb=2 sweettouchdelay=3 sweetbattery=1 $EXTRA"
case " $CMDLINE " in *" ufsroot=iosdata "*) ;; *) echo "refusing: no ufsroot=iosdata"; exit 1 ;; esac
case " $CMDLINE " in *ufsroot=userdata*) echo "refusing: ufsroot=userdata"; exit 1 ;; esac
case " $CMDLINE " in *" ufsrw=1 "*|*" rootrw=1 "*) [ "${ALLOW_RW:-}" = 1 ] || { echo "refusing: rw boot-arg without ALLOW_RW=1"; exit 1; } ;; esac
python3 "$T/mkpayload.py" "$K" $W/davinci_5g_cam.adt "$B/payload.bin" --cmdline "$CMDLINE"
python3 "$T/mkcombo.py" "$B/payload.bin" $P/miui-Image $P/miui-ramdisk $P/miui-cmdline "$B/combo.bin"
IMG=$O/davinci-ios26-$NAME.img
python3 /home/marnov/xmiphones/kbuild/tools/mkbootimg.py --header_version 2 --kernel $P/unpack195af/kernel \
	--ramdisk "$B/combo.bin" --dtb $P/unpack195af/dtb --base 0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 \
	--tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096 --cmdline "console=null" -o "$IMG"
strings -n 20 "$B/payload.bin" | grep -F "$CMDLINE" > /dev/null || { echo "cmdline not in payload"; exit 1; }
echo "$CMDLINE" > "$IMG.cmdline"
ls -la "$IMG"
echo "boot-args: $CMDLINE"

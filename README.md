# ios26-sweet

Apple's open-source XNU **xnu-12377.121.6** (the iOS 26 kernel) with the **iOS 26.5.2** user space on two
Xiaomi phones whose CPUs have no pointer authentication:

| Codename | Phone | SoC | CPU | GPU |
|---|---|---|---|---|
| davinci | Mi 9T | SM7150 (Snapdragon 730) | Kryo 470: Cortex-A76 + A55, Armv8.2 | Adreno 618 |
| raphael | Mi 9T Pro | SM8150 (Snapdragon 855) | Kryo 485: Cortex-A76 + A55, Armv8.2 | Adreno 640 |

The successor of our iOS 16.7 ports (xnu-8796), which are built on
[dipa-studio/ios-sweet](https://github.com/dipa-studio/ios-sweet) with parts of
[HakiOS](https://github.com/oosexgang/hakios-xnu-kernel). Status: **preparation**; nothing built or booted yet.

## The approach

- **User space:** the iPhone 11 (`iPhone12,1`) restore of iOS 26.5.2 (23F84). iOS 26 ships only an arm64e
  (pointer-authenticated) shared cache, and Armv8.2 cores trap on the non-hint PAC instructions. As
  [none24smu/UniXNU-zeta](https://github.com/none24smu/UniXNU-zeta) did on the Surface Duo 2, launchd, dyld and
  the whole shared cache are rewritten offline to plain arm64 (every non-hint PAC instruction replaced by its
  unauthenticated form, code proven by control flow first), then re-signed.
- **Kernel:** xnu-12377.121.6 built without ptrauth, 16 KiB pages, with our drivers. Our kernel change set from the
  iOS 16 port carries over as two parts: our own files (drivers, copied whole and fixed for the newer kernel) and
  our edits to Apple's files (merged onto 12377).
- **Graphics:** iOS 26's CoreAnimation has no OpenGL ES fallback, so the window server needs Metal on the Adreno.

## Measured so far (2026-11-07)

Our iOS 16 kernel change set (fork/hackios-gles f498bf8) against xnu-12377.121.6:

| Part | Size | On 12377 |
|---|---|---|
| Our own files | 110 files, about 58,800 lines | copied whole; compile fixes still to find |
| Our edits to Apple's files | 78 files, +2,513 / -138 lines | 46 merge cleanly, 30 have 1-5 conflicting pieces (about 45), 2 belong to the staged HFS sources |

The iPhone 11 shared cache: 979.8 million instruction-section words; 29.28 million non-hint PAC instructions to
lower (zeta counted 29.58 million in the iPhone 17 cache). A linear sweep also finds instructions of features the
A76 lacks (FCMA, LRCPC2, BF16, MOPS, ...); how many of them are real code, and where, is being measured.

## Plan

1. Kernel: resolve the merge, build xnu-12377 in CI (blacktop/darwin-xnu-build, macOS 26.5), fix compile errors.
2. First boot from RAM (`fastboot boot`) to the kernel console on davinci, then root mount.
3. User space: lower launchd, dyld and the shared cache; non-ptrauth shared-region slide fixes; skip libignition's
   cryptex graft; build the root image.
4. launchd, backboardd, SpringBoard; then Metal for the window server.
5. raphael.

## Layout

- `xnu/patches/`: what CI puts on Apple's xnu-12377.121.6 (blacktop/darwin-xnu-build, `MACOS_VERSION=26.5`,
  `MACHINE_CONFIG=SWEET`): `0019`/`0020`/`0026-stage-*.sh` fetch libpthread-539.100.4, BearSSL and hfs-715.120.4
  (the macOS 26.5 versions); `0100-sweet-new-files.patch` our drivers and other new files; `0101-sweet-apple-edits.patch`
  our changes to Apple's files.
- `.github/workflows/xnu.yml`: the build (macos-latest, Xcode 26); artifacts `xnu-kernel` and `xnu-buildtree`.

## Not included

No binaries or firmware of Apple, Qualcomm or Xiaomi.

# gb10-overlay

A Gentoo overlay for the NVIDIA DGX Spark (GB10 Grace-Blackwell) on arm64.

| Package | What it is |
| --- | --- |
| `sys-kernel/gb10-sources` | Kernel sources with the GB10 enablement patches ported from Ubuntu's `linux-nvidia-6.17`. The arm-smmu-v3 iGPU quirk is required or GSP init fails and the GPU is unusable. |
| `app-emulation/fex` | FEX-Emu, the x86/x86-64 usermode emulator. This is what runs the Steam client and x86 Linux binaries, and its thunk libraries hand OpenGL/Vulkan straight to the native arm64 NVIDIA driver. |
| `app-emulation/fex-rootfs` | The prebuilt x86 Gentoo system images FEX runs guests against, and that the guest thunks are compiled against. |

## Enabling the overlay

```sh
cat > /etc/portage/repos.conf/gb10.conf <<'CONF'
[gb10]
location = /var/db/repos/gb10
sync-type = git
sync-uri = https://github.com/av-rm/gb10-overlay.git
auto-sync = yes
CONF
emaint sync -r gb10
```

Everything here is `~arm64`:

```sh
cat >> /etc/portage/package.accept_keywords/gb10 <<'CONF'
app-emulation/fex ~arm64
app-emulation/fex-rootfs ~arm64
sys-kernel/gb10-sources ~arm64
CONF
```

## Installing FEX

```sh
emerge -av app-emulation/fex
```

FEX is built with clang regardless of your system compiler — it needs clang's
x86 cross support for the thunks, and upstream only tracks clang warning flags.

### USE flags

| Flag | Default | Effect |
| --- | --- | --- |
| `thunks` | on | Build the host/guest thunk libraries. Without these, guest OpenGL and Vulkan are emulated in software and games are unusable. Pulls in `app-emulation/fex-rootfs` (~1.3G of distfiles) and needs ~4G of build space. |
| `fexconfig` | on | The FEXConfig GUI, which is how you toggle individual thunks. |
| `qt6` | on | Build FEXConfig against Qt 6. |
| `telemetry` | off | FEX's offline telemetry. Local-only statistics under `~/.fex-emu`; nothing is transmitted. |

To build the thunks against an x86 sysroot you already have — one fetched by
`FEXRootFSFetcher`, say — instead of the packaged images:

```sh
FEX_X86_ROOTFS=/path/to/extracted/rootfs emerge -av app-emulation/fex
```

`app-emulation/fex-rootfs` is still pulled in as a build dependency in that
case; add it to `/etc/portage/profile/package.provided` if you want it gone.

## After installing

**binfmt_misc**, so x86 binaries can be executed directly:

```sh
modprobe binfmt_misc          # and add binfmt_misc to /etc/conf.d/modules
rc-update add binfmt default
rc-service binfmt start
```

FEX installs `/usr/lib/binfmt.d/FEX-x86.conf` and `FEX-x86_64.conf`, which is
one of the directories OpenRC's `binfmt` service reads, so no further
configuration is needed.

**A RootFS**, since FEX cannot run anything without an x86 userland:

```sh
mkdir -p ~/.fex-emu/RootFS
unsquashfs -d ~/.fex-emu/RootFS/gentoo-x86_64 /usr/share/fex-emu/rootfs/base.sqfs
unsquashfs -f -d ~/.fex-emu/RootFS/gentoo-x86_64 /usr/share/fex-emu/rootfs/chroot.sqfs
```

then set `RootFS` in FEXConfig. Extracting avoids needing `sys-fs/squashfuse`,
which is not keyworded for arm64. `FEXRootFSFetcher` will fetch an Ubuntu image
instead if you prefer one.

**Thunks**: enable Vulkan, OpenGL, Wayland and DRM in FEXConfig. Leave the
OpenAL thunk off — it is known to crash Steam even though the host library
is otherwise load-bearing.

**Limits**, before running Steam or Proton:

```sh
echo 'vm.max_map_count = 2147483642' > /etc/sysctl.d/99-steam.conf
sysctl --system
# /etc/security/limits.conf:  <user>  hard  nofile  524288
```

## GB10 notes

* The kernel must use 4K pages (`CONFIG_ARM64_4K_PAGES`). FEX does not work
  with 64K pages, and `gb10-sources` sets this for the iGPU's sake anyway.
* The 20 cores are asymmetric: CPUs 5-9 and 15-19 are the 3.9 GHz Cortex-X925,
  0-4 and 10-14 the 2.8 GHz Cortex-A725. The scheduler handles emulated
  workloads poorly, so pin games with `taskset -c 5-9,15-19 %command%`.
* Graphics stay native: the thunks forward to the arm64 `nvidia-drivers`
  Vulkan driver, so only CPU-side x86 code is emulated.

## Credits

* [FEX-Emu](https://github.com/FEX-Emu/FEX) — upstream, MIT.
* [chadmed/asahi-overlay](https://github.com/chadmed/asahi-overlay) — the
  `app-emulation/FEX` ebuild this one is derived from, and both patches in
  `app-emulation/fex/files`.
* [WhatAmISupposedToPutHere/fex-rootfs](https://github.com/WhatAmISupposedToPutHere/fex-rootfs)
  — the x86 rootfs images.

Ebuilds here are distributed under the GPL-2, per the header on each file.

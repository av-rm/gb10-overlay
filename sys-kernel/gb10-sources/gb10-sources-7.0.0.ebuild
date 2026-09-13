# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="8"

ETYPE="sources"
K_SECURITY_UNSUPPORTED="1"

# The tree ships SUBLEVEL = 14 and an empty EXTRAVERSION, and both are left
# alone: the kernel then calls itself plain 7.0.14, which is what
# /lib/modules/7.0.14 and the already-built nvidia-drivers expect. Dropping
# this line makes the eclass stamp EXTRAVERSION = -gb10 into the Makefile,
# which renames the module directory and forces a nvidia-drivers rebuild.
K_NOSETEXTRAVERSION="1"

# Always repoint /usr/src/linux on install, rather than only under
# USE=symlink. This is deliberate -- it is the eselect step the manual
# deployment did -- but it does mean emerging this package moves the symlink
# out from under whatever it pointed at before.
K_SYMLINK="1"

inherit kernel-2
detect_version
detect_arch

# Ubuntu source package, format 1.0: a pristine upstream tarball plus one
# .diff.gz carrying both the Debian packaging and the whole NVIDIA GB10 patch
# set. Nothing from files/*.patch is applied here -- every patch the 6.17
# ebuilds carried by hand is already merged into this tree, which is why
# UNIPATCH_LIST is empty.
#
# NV_ABI is the Ubuntu ABI revision and is the only thing that changes on a
# rebuild of the same upstream 7.0.0; bump it and re-run `ebuild ... manifest`.
NV_PN="linux-nvidia-7.0"
NV_ABI="1019.19~24.04.2"
NV_TARBALL="${NV_PN}_7.0.0.orig.tar.gz"
NV_DIFF="${NV_PN}_7.0.0-${NV_ABI}.diff.gz"
NV_POOL="https://archive.ubuntu.com/ubuntu/pool/main/l/${NV_PN}"

DESCRIPTION="Linux kernel sources with NVIDIA DGX Spark (GB10 Grace-Blackwell) support"
HOMEPAGE="https://github.com/av-rm/gb10-overlay"
SRC_URI="
	${NV_POOL}/${NV_TARBALL}
	${NV_POOL}/${NV_DIFF}
"

KEYWORDS="~arm64"
IUSE=""

# kernel-2's universal_unpack() is hardcoded for kernel.org naming -- it
# unpacks linux-${KV_MAJOR}.${KV_MINOR}.tar.xz -- and this is a Debian source
# package, so replace it. Redefining it here wins over the eclass copy, and
# the rest of kernel-2_src_unpack (env_setup_kernel_makeopts, the cd into
# ${S}) still runs afterwards.
universal_unpack() {
	cd "${WORKDIR}" || die

	unpack "${NV_TARBALL}"

	# The tarball's top-level directory is literally linux-7.0, which is
	# what ${KV_MAJOR}.${KV_MINOR} would have been anyway.
	mv linux-7.0 "linux-${KV_FULL}" || die "could not rename source tree"
	cd "linux-${KV_FULL}" || die

	# Apply at a fixed depth. unipatch probes -p0 first, and this diff
	# creates whole directories (debian/, debian.master/, debian.nvidia/,
	# debian.nvidia-7.0/) as well as modifying existing files, so a probe
	# can settle on the wrong level and scatter them into the tree root.
	# -p1 is what the diff's own paths say. -F0 refuses fuzz: the diff was
	# generated against exactly this tarball, so any fuzz means the orig
	# tarball is not the one NVIDIA cut it against.
	ebegin "Applying ${NV_DIFF}"
	zcat "${DISTDIR}/${NV_DIFF}" | patch -p1 -s -F0 --no-backup-if-mismatch
	eend ${?} || die "failed to apply ${NV_DIFF}"
}

src_prepare() {
	kernel-2_src_prepare

	# Config for this machine; build it with `make gb10_defconfig`.
	#
	# Cut with savedefconfig from the running 7.0.14 .config and verified to
	# round-trip byte-identically back to that file against this tree.
	# DM_CRYPT/BLK_DEV_DM/MD are =y, not =m: root is LUKS
	# (detached header in /boot) under LVM, and NVIDIA's own config ships
	# DM_CRYPT=m.
	#
	# Kept separate from files/gb10_defconfig, which belongs to the masked
	# 6.17.0 ebuild and is a different kernel's config entirely.
	cp "${FILESDIR}"/7.0.0/gb10_defconfig arch/arm64/configs/ || die
}

pkg_postinst() {
	kernel-2_pkg_postinst
	elog "GB10 / DGX Spark notes:"
	elog "  This is NVIDIA's linux-nvidia-7.0 tree (Ubuntu ABI ${NV_ABI}),"
	elog "  not vanilla plus patches. Everything the 6.17 ebuilds applied by"
	elog "  hand is already merged upstream of this tarball, so files/*.patch"
	elog "  is not used here."
	elog ""
	elog "  Upstream renumbered this kernel: the tree is VERSION 7 PATCHLEVEL 0"
	elog "  SUBLEVEL 14, so it builds and installs as 7.0.14 even though the"
	elog "  package version is 7.0.0. Sources land in /usr/src/linux-${KV_FULL}"
	elog "  and modules in /lib/modules/7.0.14."
	elog ""
	elog "  A starting config for this machine is shipped as gb10_defconfig:"
	elog "      cd /usr/src/linux && make gb10_defconfig && make menuconfig"
	elog "  Run gb10_defconfig itself -- do not copy the previous kernel's"
	elog "  .config and run olddefconfig. That keeps whatever the old file"
	elog "  already said and silently skips symbols added since it was cut."
	elog ""
	elog "  DM_CRYPT is built in (=y), not a module, for the LUKS root."
	elog "  Check it survived any menuconfig pass:"
	elog "      grep -E '^CONFIG_(DM_CRYPT|BLK_DEV_DM|MD)=' .config"
	elog ""
	elog "  nvidia-drivers must be rebuilt against this tree if you change"
	elog "  EXTRAVERSION or LOCALVERSION (emerge nvidia-drivers)."
	elog ""
	elog "  cma= is a no-op on this machine: DRAM starts at 0x80000000 so"
	elog "  ZONE_DMA32 is empty and CMA cannot be reserved. Leave it off the"
	elog "  kernel command line."
}

pkg_postrm() {
	kernel-2_pkg_postrm
}

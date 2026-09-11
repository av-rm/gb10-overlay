# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-info optfeature

DESCRIPTION="Prebuilt x86/x86-64 Gentoo system image for use as a FEX RootFS"
HOMEPAGE="https://github.com/WhatAmISupposedToPutHere/fex-rootfs"

SRC_URI="
	https://github.com/WhatAmISupposedToPutHere/fex-rootfs/releases/download/${PV}/fex-rootfs.sqfs
		-> ${P}-base.sqfs
	https://github.com/WhatAmISupposedToPutHere/fex-rootfs/releases/download/${PV}/fex-chroot.sqfs
		-> ${P}-chroot.sqfs
"
S="${WORKDIR}"

# A full x86 Gentoo image: the usual mix of GPL/LGPL/MIT/BSD userland.
LICENSE="GPL-2+ GPL-3+ LGPL-2.1+ BSD MIT"
SLOT="0"
KEYWORDS="-* ~arm64"

# Opaque filesystem images; nothing here for portage to strip or scan, and
# we are not redistributing someone else's build artifacts to the mirrors.
RESTRICT="binchecks mirror strip"

pkg_pretend() {
	# Only needed if you let the kernel mount the images rather than
	# extracting them or going through squashfuse.
	CONFIG_CHECK="~SQUASHFS ~SQUASHFS_ZSTD"
	check_extra_config
}

src_unpack() {
	# The images are used as-is; unpacking a 1.3G squashfs would only
	# waste build space.
	:
}

src_install() {
	insinto /usr/share/fex-emu/rootfs
	newins "${DISTDIR}/${P}-base.sqfs" base.sqfs
	newins "${DISTDIR}/${P}-chroot.sqfs" chroot.sqfs
}

pkg_postinst() {
	elog "The x86 rootfs images are installed in /usr/share/fex-emu/rootfs."
	elog
	elog "FEX mounts .sqfs images by calling squashfuse, which is not"
	elog "keyworded for arm64. Either keyword it, or extract the image once"
	elog "and point FEX at the directory instead:"
	elog
	elog "  mkdir -p ~/.fex-emu/RootFS"
	elog "  unsquashfs -d ~/.fex-emu/RootFS/gentoo-x86_64 \\"
	elog "      /usr/share/fex-emu/rootfs/base.sqfs"
	elog "  unsquashfs -f -d ~/.fex-emu/RootFS/gentoo-x86_64 \\"
	elog "      /usr/share/fex-emu/rootfs/chroot.sqfs"
	elog
	elog "then set RootFS to gentoo-x86_64 in FEXConfig, or in"
	elog "~/.fex-emu/Config.json."
	elog
	elog "app-emulation/fex[thunks] uses these images directly at build time;"
	elog "you do not need to extract them for that."

	optfeature "mounting the .sqfs images without extracting them" \
		sys-fs/squashfuse
}

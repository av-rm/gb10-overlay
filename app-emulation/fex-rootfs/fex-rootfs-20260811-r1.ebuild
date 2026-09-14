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

# fex-rootfs-setup extracts the images at runtime.
RDEPEND="sys-fs/squashfs-tools"

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

	# Extracting the images is only half the job; see the script for why the
	# result has to be "broken" before anything will work reliably.
	dobin "${FILESDIR}/fex-rootfs-setup"
}

pkg_postinst() {
	elog "The x86 rootfs images are installed in /usr/share/fex-emu/rootfs."
	elog
	elog "FEX mounts .sqfs images by calling squashfuse, which is not"
	elog "keyworded for arm64, so extract the images once instead:"
	elog
	elog "  fex-rootfs-setup        # run as your own user, not root"
	elog
	elog "That extracts base.sqfs + chroot.sqfs into ~/.fex-emu/RootFS and"
	elog "then *breaks* the result, which is not optional: FEX resolves a"
	elog "guest path against the RootFS first and only falls through to the"
	elog "host if it is missing, so a directory present in both silently"
	elog "shadows the host's. An unbroken rootfs leaves Steam writing its IPC"
	elog "into the rootfs /tmp while the webhelper in pressure-vessel uses the"
	elog "real one, which surfaces as startup error 0x3009."
	elog
	elog "Re-run it after every upgrade of this package: a fresh extract puts"
	elog "all of those directories back. It is idempotent and will not"
	elog "overwrite an existing ~/.fex-emu/Config.json."
	elog
	elog "app-emulation/fex[thunks] uses these images directly at build time;"
	elog "you do not need to extract them for that."

	optfeature "mounting the .sqfs images without extracting them" \
		sys-fs/squashfuse
}

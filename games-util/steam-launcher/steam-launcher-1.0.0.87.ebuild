# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop optfeature xdg

DESCRIPTION="Valve's Steam client launcher, wired up to run under FEX on arm64"
HOMEPAGE="https://store.steampowered.com/"
SRC_URI="https://repo.steampowered.com/steam/archive/stable/steam_${PV}.tar.gz"
S="${WORKDIR}/steam-launcher"

LICENSE="Steam"
SLOT="0"
# arm64 only on purpose: on any other arch you want the real games-util/steam-launcher
# from ::steam-overlay, which does not need any of the FEX plumbing below.
KEYWORDS="-* ~arm64"

# The bootstrap tarball is an opaque x86 payload we neither built nor may
# redistribute, and it is not ours to strip or scan on an arm64 host.
RESTRICT="bindist mirror strip binchecks"

RDEPEND="
	app-emulation/fex[thunks]
	app-emulation/fex-rootfs
	sys-apps/bubblewrap
	media-libs/vulkan-loader[X]
"

src_compile() {
	# Nothing to build; upstream's Makefile only installs.
	:
}

src_install() {
	# Deliberately not "emake install": that also runs install-apt-source,
	# which drops Debian sources.list snippets and a keyring on the system.
	emake \
		DESTDIR="${D}" \
		PREFIX="${EPREFIX}/usr" \
		install-bin \
		install-docs \
		install-icons \
		install-bootstrap \
		install-desktop \
		install-appdata

	# bin_steamdeps.py is Valve's apt dependency checker. It is useless here and
	# would drag in a python dep for nothing; bin_steam.sh only runs it behind
	# an `if [ -x ]`, so dropping it is silently fine.
	rm -f "${ED}/usr/bin/steamdeps" || die
	rm -rf "${ED}/usr/lib/steam/bin_steamdeps.py" "${ED}/usr/lib/steam/steam_launcher" || die

	# The x86 client cannot be launched directly on arm64 -- it has to go
	# through FEX. See the script for the three things that have to be set.
	dobin "${FILESDIR}/steam-fex"

	# A second desktop entry pointing at the wrapper, derived from Valve's so it
	# keeps their icon, actions and translations. The stock steam.desktop is
	# left installed but will not work unless something else can run x86.
	# TryExec goes in [Desktop Entry] only -- desktop-file-validate rejects it
	# inside the [Desktop Action ...] groups, so restrict it to the first Exec.
	sed \
		-e 's|^Exec=/usr/bin/steam|Exec=/usr/bin/steam-fex|' \
		-e 's|^Name=Steam$|Name=Steam (FEX)|' \
		-e '0,/^Exec=/s|^Exec=|TryExec=/usr/bin/steam-fex\nExec=|' \
		"${S}/steam.desktop" > "${T}/steam-fex.desktop" || die
	domenu "${T}/steam-fex.desktop"
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "Launch the client with 'steam-fex', or the \"Steam (FEX)\" menu entry."
	elog "Running 'steam' directly will not work: it is an x86 script."
	elog
	elog "Steam is installed to the host /usr. FEX resolves a guest path against"
	elog "its RootFS first and only falls through to the host when the file is"
	elog "missing, so nothing needs copying into the RootFS -- but an older"
	elog "hand-installed copy there will shadow this one. Remove it if present:"
	elog "  rm -f ~/.fex-emu/RootFS/*/usr/bin/steam"
	elog "  rm -rf ~/.fex-emu/RootFS/*/usr/lib/steam"
	elog
	elog "Prepare the RootFS once, if you have not already:"
	elog "  fex-rootfs-setup        # app-emulation/fex-rootfs, run as your user"
	elog
	elog "In ~/.fex-emu/Config.json, two thunks must stay OFF or the client dies"
	elog "at startup, and both failures name a missing symbol rather than FEX:"
	elog "  asound        - libasound-guest.so exports no versioned ALSA symbols,"
	elog "                  so libcef fails on snd_mixer_elem_set_callback/ALSA_0.9"
	elog "  WaylandClient - the guest lib exports no wl_list_* helpers, so libdecor"
	elog "                  fails on wl_list_init and SDL games lose their launcher"
	elog "GL, Vulkan, drm and cuda are the ones worth enabling."
	elog
	elog "ServerSocketPath must be set, and must not be under /tmp: FEX derives"
	elog "its default socket name from getuid(), which a user namespace reports"
	elog "as 0, and pressure-vessel gives its container a private /tmp. Either"
	elog "one stops the CEF zygote reaching FEXServer. Use \$HOME, e.g."
	elog "  \"ServerSocketPath\": \"/home/<user>/.fex-emu/Server/fexsrv.sock\""
	elog
	elog "Raise these before running games:"
	elog "  vm.max_map_count = 2147483642   (/etc/sysctl.d/)"
	elog "  nofile hard limit >= 524288     (/etc/security/limits.conf)"

	optfeature "GPU acceleration through the FEX thunks" x11-drivers/nvidia-drivers
}

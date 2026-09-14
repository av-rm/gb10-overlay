# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( {19..22} )
LLVM_OPTIONAL=1

inherit check-reqs cmake flag-o-matic linux-info llvm-r2 toolchain-funcs

MY_PN="FEX"
MY_P="${MY_PN}-${PV}"

DESCRIPTION="Fast usermode x86 and x86-64 emulator for arm64 Linux"
HOMEPAGE="
	https://fex-emu.com/
	https://github.com/FEX-Emu/FEX/
"

# GitHub archives carry no submodule content, and FEX pins these hard, so
# they have to be fetched separately and dropped into External/ by hand.
# Everything else FEX vendors is either unbundled below (fmt, xxhash,
# range-v3, drm-headers) or only used by the test suite (Catch2, tracy,
# vixl, zydis), which we never build.
RPMALLOC_HASH="1d85c246cd827ead6865f4f880d4fef53f2b1864"
JEMALLOC_GLIBC_HASH="8436195ad5e1bc347d9b39743af3d29abee59f06"
CPP_OPTPARSE_HASH="9f94388a339fcbb0bc95c17768eb786c85988f6e"
UNORDERED_DENSE_HASH="3234af2c03549bc85656bfd3a86993bf1cd8aef1"
# The thunk generator cannot parse the current Vulkan headers, so this
# pin has to match upstream's rather than following media-libs/vulkan-*.
VULKAN_HEADERS_HASH="450bd2232225d6c7728a4108055ac2e37cef6475"

SRC_URI="
	https://github.com/FEX-Emu/${MY_PN}/archive/refs/tags/${MY_P}.tar.gz
	https://github.com/FEX-Emu/rpmalloc/archive/${RPMALLOC_HASH}.tar.gz
		-> rpmalloc-${RPMALLOC_HASH}.tar.gz
	https://github.com/FEX-Emu/jemalloc/archive/${JEMALLOC_GLIBC_HASH}.tar.gz
		-> jemalloc-glibc-${JEMALLOC_GLIBC_HASH}.tar.gz
	https://github.com/Sonicadvance1/cpp-optparse/archive/${CPP_OPTPARSE_HASH}.tar.gz
		-> cpp-optparse-${CPP_OPTPARSE_HASH}.tar.gz
	https://github.com/martinus/unordered_dense/archive/${UNORDERED_DENSE_HASH}.tar.gz
		-> unordered_dense-${UNORDERED_DENSE_HASH}.tar.gz
	thunks? (
		https://github.com/KhronosGroup/Vulkan-Headers/archive/${VULKAN_HEADERS_HASH}.tar.gz
			-> Vulkan-Headers-${VULKAN_HEADERS_HASH}.tar.gz
	)
"

S="${WORKDIR}/${MY_PN}-${MY_P}"

# FEX itself is MIT; rpmalloc is public-domain/MIT, jemalloc BSD-2,
# unordered_dense and cpp-optparse MIT, Vulkan-Headers Apache-2.0.
LICENSE="MIT BSD-2 public-domain thunks? ( Apache-2.0 )"
SLOT="0"
KEYWORDS="-* ~arm64"

IUSE="+fexconfig +qt6 telemetry +thunks"
REQUIRED_USE="
	fexconfig? ( qt6 )
	thunks? ( ${LLVM_REQUIRED_USE} )
"

RDEPEND="
	>=dev-libs/libfmt-11.0.2:=
	dev-libs/xxhash
	qt6? (
		dev-qt/qtbase:6[gui,wayland(-),widgets,X(-)]
		dev-qt/qtdeclarative:6
	)
	thunks? (
		dev-libs/wayland
		media-libs/alsa-lib
		media-libs/libglvnd
		x11-libs/libX11
		x11-libs/libdrm
		x11-libs/libxcb
	)
"
DEPEND="
	${RDEPEND}
	dev-cpp/range-v3
	>=sys-kernel/linux-headers-6.17
	thunks? ( app-emulation/fex-rootfs )
"
BDEPEND="
	llvm-core/clang
	llvm-core/llvm
	llvm-core/lld
	thunks? (
		sys-fs/squashfs-tools[zstd]
		$(llvm_gen_dep '
			llvm-core/clang:${LLVM_SLOT}=
			llvm-core/llvm:${LLVM_SLOT}=
		')
	)
"

PATCHES=(
	# Use the kernel's drm uapi headers instead of FEX's vendored copy.
	"${FILESDIR}/${PN}-2601-unvendor-drm-headers.patch"
	# Point the guest thunk compiler at the gcc install gcc-config selected.
	"${FILESDIR}/${PN}-2607-thunkgen-gcc-install-dir.patch"
)

# Set FEX_X86_ROOTFS to an already-extracted x86 sysroot to build the guest
# thunks against that instead of the one app-emulation/fex-rootfs ships.
: "${FEX_X86_ROOTFS:=}"

pkg_pretend() {
	use thunks || return
	CHECKREQS_DISK_BUILD=4G
	check-reqs_pkg_pretend
}

pkg_setup() {
	# binfmt_misc is what lets you run an x86 binary by just executing it.
	CONFIG_CHECK="~BINFMT_MISC"
	ERROR_BINFMT_MISC="CONFIG_BINFMT_MISC is needed to run x86 binaries directly."
	linux-info_pkg_setup

	use thunks || return
	CHECKREQS_DISK_BUILD=4G
	check-reqs_pkg_setup
	llvm-r2_pkg_setup
}

src_unpack() {
	default

	local -A deps=(
		[rpmalloc]="rpmalloc-${RPMALLOC_HASH}"
		[jemalloc_glibc]="jemalloc-${JEMALLOC_GLIBC_HASH}"
		[unordered_dense]="unordered_dense-${UNORDERED_DENSE_HASH}"
	)
	use thunks && deps[Vulkan-Headers]="Vulkan-Headers-${VULKAN_HEADERS_HASH}"

	local dep
	for dep in "${!deps[@]}"; do
		rmdir "${S}/External/${dep}" || die "External/${dep} is not an empty submodule dir"
		mv "${WORKDIR}/${deps[${dep}]}" "${S}/External/${dep}" || die
	done

	rmdir "${S}/Source/Common/cpp-optparse" || die
	mv "${WORKDIR}/cpp-optparse-${CPP_OPTPARSE_HASH}" "${S}/Source/Common/cpp-optparse" || die

	use thunks || return

	# Upstream's x86 toolchain files assume a Debian cross-gcc; ours build
	# the guest libs with clang against the x86 sysroot.
	cp "${FILESDIR}"/toolchain_x86_{32,64}.cmake "${S}/Data/CMake/" || die

	if [[ -n ${FEX_X86_ROOTFS} ]]; then
		[[ -d ${FEX_X86_ROOTFS} ]] ||
			die "FEX_X86_ROOTFS=${FEX_X86_ROOTFS} is not a directory"
		einfo "Building guest thunks against ${FEX_X86_ROOTFS}"
	else
		local rootfs="${ESYSROOT}/usr/share/fex-emu/rootfs"
		einfo "Extracting the x86 sysroot for the guest thunk build ..."
		unsquashfs -d "${WORKDIR}/x86-rootfs" "${rootfs}/base.sqfs" || die
		unsquashfs -d "${WORKDIR}/x86-rootfs" -f "${rootfs}/chroot.sqfs" || die
	fi
}

src_configure() {
	# FEX only builds with clang: it needs clang's x86 cross support for the
	# thunks, and upstream tracks clang-only warning flags.
	if ! tc-is-clang; then
		AR=llvm-ar
		CC=clang
		CXX=clang++
		NM=llvm-nm
		RANLIB=llvm-ranlib
		STRIP=llvm-strip

		strip-unsupported-flags
	fi

	# thunkgen invokes clang directly, so it needs the same gcc install dir
	# the rest of the toolchain uses.
	export THUNKGEN_EXTRA_FLAGS="--config=${EPREFIX}/etc/clang/gentoo-gcc-install.cfg"

	# Only turn on FEX's LTO if the user asked for LTO globally.
	local lto=False
	tc-is-lto && lto=True

	local mycmakeargs=(
		-DBUILD_FEXCONFIG=$(usex fexconfig)
		-DBUILD_TESTING=False
		-DBUILD_THUNKS=$(usex thunks)
		-DENABLE_CCACHE=False
		-DENABLE_CLANG_THUNKS=True
		-DENABLE_LTO=${lto}
		-DENABLE_OFFLINE_TELEMETRY=$(usex telemetry)
	)

	if use thunks; then
		mycmakeargs+=(
			-DX86_DEV_ROOTFS="${FEX_X86_ROOTFS:-${WORKDIR}/x86-rootfs}"
		)
	fi

	cmake_src_configure
}

src_install() {
	cmake_src_install

	# Stripping the static lib would drop the LTO bitcode anything linking
	# against libFEXCore.a needs.
	if tc-is-lto; then
		dostrip -x "/usr/$(get_libdir)/libFEXCore.a"
	fi

	# Upstream pre-compresses its man page; let portage handle compression.
	if [[ -f ${ED}/usr/share/man/man1/FEX.1.gz ]]; then
		gunzip "${ED}/usr/share/man/man1/FEX.1.gz" || die
	fi

	# The guest thunks are x86 shared objects, so the arm64 strip is wrong
	# for them and portage's QA would flag them either way.
	if use thunks; then
		dostrip -x /usr/share/fex-emu/GuestThunks{,_32}/
	fi
}

pkg_postinst() {
	if [[ $(getconf PAGESIZE) -ne 4096 ]]; then
		ewarn "Your kernel page size is $(getconf PAGESIZE), not 4096."
		ewarn "FEX needs 4K pages; rebuild your kernel with CONFIG_ARM64_4K_PAGES"
		ewarn "or run FEX inside app-emulation/muvm."
	fi

	elog "FEX needs an x86-64 rootfs before it can run anything:"
	elog "  fex-rootfs-setup              # app-emulation/fex-rootfs"
	elog "  FEXRootFSFetcher              # downloads one into ~/.fex-emu"
	elog
	elog "Prefer fex-rootfs-setup: it also removes the directories the image"
	elog "shares with the host (/tmp, /home, /etc/passwd, ...), which FEX"
	elog "would otherwise resolve from the rootfs and shadow the host's."
	elog
	elog "To run x86 binaries by executing them directly, enable binfmt_misc:"
	elog "  modprobe binfmt_misc                  # add to /etc/conf.d/modules"
	elog "  rc-update add binfmt default && rc-service binfmt start"
	elog "This package installs /usr/lib/binfmt.d/FEX-x86{,_64}.conf, which"
	elog "OpenRC's binfmt service reads on boot."

	if use thunks; then
		elog
		elog "Host thunks were built. Enable the ones you need in FEXConfig"
		elog "so guest x86 GL/Vulkan calls reach the native arm64 driver."
		elog "On GB10 with nvidia-drivers: enable Vulkan, OpenGL, Wayland,"
		elog "DRM and cuda."
		elog
		elog "Leave the ALSA (asound) thunk off. libasound-guest.so does not"
		elog "export ALSA's versioned symbols, so libcef fails against it and"
		elog "Steam's webhelper dies with:"
		elog "  undefined symbol: snd_mixer_elem_set_callback, version ALSA_0.9"
		elog
		elog "The GL thunk forwards into the host libGL, so it is only as good"
		elog "as the host driver: with the nvidia modules unloaded it takes the"
		elog "client down with a SIGSEGV or std::bad_alloc that looks like a"
		elog "thunk bug. Check nvidia-smi first, and rerun emerge @module-rebuild"
		elog "after any kernel rebuild."
	fi

	elog
	elog "For Steam and Proton, raise these first:"
	elog "  vm.max_map_count = 2147483642   (/etc/sysctl.d/)"
	elog "  nofile hard limit >= 524288     (/etc/security/limits.conf)"
	elog
	elog "Also set ServerSocketPath in ~/.fex-emu/Config.json to a path under"
	elog "\$HOME. FEX derives its default socket name from getuid(), which a"
	elog "user namespace reports as 0, and a socket in /tmp is invisible from"
	elog "inside pressure-vessel's private /tmp. Either one stops Steam's CEF"
	elog "zygote from reaching FEXServer."
}

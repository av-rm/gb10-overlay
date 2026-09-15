# Copyright 2023-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Derived from media-libs/nvidia-vaapi-driver-0.0.18 in ::gentoo, unchanged
# except for the added ~arm64 keyword.
#
# Upstream is arch-neutral: meson.build has no assembly, no -march/-mtune and
# no conditional architecture detection, and every dependency below is already
# keyworded for arm64. Arch Linux ARM ships the same source as
# libva-nvidia-driver for aarch64, and the aarch64 NVIDIA driver provides the
# libnvcuvid.so NVDEC is reached through, so there is nothing arch-specific to
# patch -- ::gentoo simply never keyworded it.

EAPI=8

inherit meson-multilib

DESCRIPTION="A VA-API implemention using NVIDIA's NVDEC"
HOMEPAGE="https://github.com/elFarto/nvidia-vaapi-driver"
SRC_URI="https://github.com/elFarto/nvidia-vaapi-driver/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

RDEPEND="media-libs/gst-plugins-bad
	media-libs/libglvnd
	>=media-libs/libva-1.8.0
	>=x11-libs/libdrm-2.4.60"
# Upper bound is ours, not ::gentoo's. nv-codec-headers >=13.1 declares
# NV_MIN_VERSION=610, and this box is pinned to nvidia-drivers-580.178.04, so
# building against those headers targets an NVDEC ABI the driver does not
# implement. 13.0.19.1 declares NV_MIN_VERSION=570 and is the newest that fits.
# A repo-level profiles/package.mask cannot express this: mask inheritance runs
# master -> child, and ::gentoo is gb10's master, so gb10 cannot mask its
# packages. Raise this bound when the driver moves to >=610.
DEPEND="${RDEPEND}
	>=media-libs/nv-codec-headers-11.1.5.1
	<media-libs/nv-codec-headers-13.1"
BDEPEND="virtual/pkgconfig"

pkg_postinst() {
	# Source: https://github.com/elFarto/nvidia-vaapi-driver/blob/v0.0.12/src/backend-common.c#L13
	elog "If vaapi drivers fail to load, then make sure that you are"
	elog "passing the correct parameters to the kernel."
	elog "nvidia_drm.modeset should be set to 1."

	elog "Check the wiki page for more information: "
	elog "https://wiki.gentoo.org/wiki/VAAPI"

	elog ""
	elog "This driver is native aarch64. It does NOT give hardware video"
	elog "decoding to x86 guests running under app-emulation/fex: FEX has no"
	elog "libva or libnvcuvid thunk, so a guest cannot reach it. It applies to"
	elog "native arm64 consumers only (Firefox, mpv, Chromium, GStreamer)."
}

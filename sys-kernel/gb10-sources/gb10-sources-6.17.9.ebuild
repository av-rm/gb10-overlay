# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="8"

ETYPE="sources"
K_SECURITY_UNSUPPORTED="1"
UNIPATCH_STRICTORDER="yes"

inherit kernel-2
detect_version
detect_arch

DESCRIPTION="Linux kernel sources with NVIDIA DGX Spark (GB10 Grace-Blackwell) support"
HOMEPAGE="https://github.com/av-rm/gb10-overlay"
SRC_URI="${KERNEL_URI}"

KEYWORDS="~arm64"
IUSE=""

UNIPATCH_LIST="
	${FILESDIR}/01-iommu-spark-igpu.patch
	${FILESDIR}/02-arm64-nc-to-ngnre.patch
	${FILESDIR}/03-soc-tegra.patch
	${FILESDIR}/04-perf-t410-pmu.patch
	${FILESDIR}/05-arm-cspmu-t410.patch
	${FILESDIR}/06-nvidia-ffa-ec.patch
	${FILESDIR}/07-mtk-pcie-hotplug.patch
	${FILESDIR}/08-pinctrl-mt8901.patch
	${FILESDIR}/09-nvgrace-egm.patch
	${FILESDIR}/10-tegra-misc.patch
	${FILESDIR}/11-smccc.patch
	${FILESDIR}/12-usb-xhci-mtk.patch
"

pkg_postinst() {
	kernel-2_pkg_postinst
	elog "GB10 / DGX Spark notes:"
	elog "  Required for the iGPU: CONFIG_ARM64_4K_PAGES, and the arm-smmu-v3"
	elog "  quirk in patch 01 (without it GSP init fails and the GPU is unusable)."
	elog "  Recommended: DRM=y and DRM_SIMPLEDRM=y for a console at boot,"
	elog "  MT7925E=m for wifi, MTK_PCIE_HOTPLUG=m for ConnectX-7 hotplug,"
	elog "  NVGRACE_EGM=m and NVIDIA_FFA_EC=y."
	elog "  nvidia-drivers must be rebuilt against this tree (emerge nvidia-drivers)."
}

pkg_postrm() {
	kernel-2_pkg_postrm
}

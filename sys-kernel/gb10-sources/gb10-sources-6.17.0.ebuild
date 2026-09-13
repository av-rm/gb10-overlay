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

KEYWORDS="arm64"
IUSE=""

UNIPATCH_LIST="
	${FILESDIR}/01-iommu-spark-igpu.patch
	${FILESDIR}/02-arm64-nc-to-ngnre.patch
	${FILESDIR}/03-soc-tegra.patch
	${FILESDIR}/04-perf-t410-pmu.patch
	${FILESDIR}/05-arm-cspmu-t410.patch
	${FILESDIR}/06-nvidia-ffa-ec.patch
	${FILESDIR}/08-pinctrl-mt8901.patch
	${FILESDIR}/09-nvgrace-egm.patch
	${FILESDIR}/10-tegra-misc.patch
	${FILESDIR}/11-smccc.patch
	${FILESDIR}/12-usb-xhci-mtk.patch
	${FILESDIR}/13-nvidia-driver-makefiles.patch
	${FILESDIR}/14-acpi-ffh-custom-offset.patch
	${FILESDIR}/15-smmu-v3-prereqs.patch
	${FILESDIR}/16-mm-pfn-address-space.patch
"

src_prepare() {
	kernel-2_src_prepare

	# 07 creates only new files, so every -p level "succeeds" and unipatch's
	# depth probe settles on -p0, scattering the files into a stray
	# linux-nvidia-6.17-6.17.0/ directory at the top of the tree. Apply it
	# ourselves at the correct depth rather than editing the patch.
	eapply -p1 "${FILESDIR}"/07-mtk-pcie-hotplug.patch

	# Config for this machine; build it with `make gb10_defconfig`.
	#
	# ARCH_THUNDER is deliberately left on despite being a Cavium platform:
	# patch 02 hangs ARCH_FORCE_MAX_ORDER=13 off it for 4K pages, and that
	# symbol has no prompt, so it cannot be set directly. Turning
	# ARCH_THUNDER off silently drops the kernel to MAX_ORDER=10.
	cp "${FILESDIR}"/gb10_defconfig arch/arm64/configs/ || die
}

pkg_postinst() {
	kernel-2_pkg_postinst
	elog "GB10 / DGX Spark notes:"
	elog "  Required for the iGPU: CONFIG_ARM64_4K_PAGES, and the arm-smmu-v3"
	elog "  quirk in patch 01 (without it GSP init fails and the GPU is unusable)."
	elog "  Recommended: DRM=y and DRM_SIMPLEDRM=y for a console at boot,"
	elog "  MT7925E=m for wifi, MTK_PCIE_HOTPLUG=m for ConnectX-7 hotplug,"
	elog "  NVGRACE_EGM=m and NVIDIA_FFA_EC=y."
	elog "  For a Bluetooth mouse or keyboard: UHID=m, HIDRAW=y, HID_GENERIC=m"
	elog "  and BT_HIDP=m. A BLE device speaks HID over GATT, which bluetoothd"
	elog "  delivers through /dev/uhid -- without UHID it pairs and connects"
	elog "  but never produces input. BT_HIDP only covers BR/EDR."
	elog "  nvidia-drivers must be rebuilt against this tree (emerge nvidia-drivers)."
	elog "  A starting config for this machine is shipped as gb10_defconfig:"
	elog "      cd /usr/src/linux && make gb10_defconfig && make menuconfig"
	elog "  Run gb10_defconfig itself -- do not copy the previous kernel's"
	elog "  .config and run olddefconfig. That keeps whatever the old file"
	elog "  already said and silently skips symbols added since it was cut."
}

pkg_postrm() {
	kernel-2_pkg_postrm
}

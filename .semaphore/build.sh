#!/usr/bin/env bash
# SemaphoreCI Kernel Build Script
# Copyright (C) 2018 Raphiel Rollerscaperers (raphielscape)
# Copyright (C) 2018 Rama Bondan Prakoso (rama982)
# SPDX-License-Identifier: GPL-3.0-or-later

#
# Telegram FUNCTION begin
#
git clone https://github.com/fabianonline/telegram.sh telegram
TELEGRAM_ID=-1001232319637
TELEGRAM=telegram/telegram
export TELEGRAM_TOKEN
# Push kernel installer to channel
function push() {
	JIP=$(echo Genom*.zip)
	curl -F document=@$JIP  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
			-F chat_id="$TELEGRAM_ID"
}
# Send the info up
function tg_channelcast() {
	"${TELEGRAM}" -c ${TELEGRAM_ID} -H \
		"$(
			for POST in "${@}"; do
				echo "${POST}"
			done
		)"
}
function tg_sendinfo() {
	curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
		-d "parse_mode=markdown" \
		-d text="${1}" \
		-d chat_id="$TELEGRAM_ID" \
		-d "disable_web_page_preview=true"
}
# Errored prober
function finerr() {
	tg_sendinfo "Something happen and build error..."
	exit 1
}
# Send sticker
function tg_sendstick() {
	curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker" \
		-d sticker="CAADBQADBAADVxIpHaVTe7CnLWtdAg" \
		-d chat_id="$TELEGRAM_ID" >> /dev/null
}
# Fin prober
function fin() {
	tg_sendinfo "$(echo "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.")"
}
#
# Telegram FUNCTION end
#

# Main environtment
KERNEL_DIR=${HOME}/android_kernel_xiaomi_msm8953-4.9
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb
ZIP_DIR_VINCE=$KERNEL_DIR/AnyKernel2-vince
CONFIG_VINCE=vince-perf_defconfig
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
CORES=$(grep -c ^processor /proc/cpuinfo)
THREAD="-j$CORES"
CROSS_COMPILE+="ccache "
CROSS_COMPILE+="$PWD/gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu/bin/aarch64-linux-gnu-"

# Modules environtment
OUTDIR="$PWD/out/"
SRCDIR="$PWD/"
MODULEDIR_VINCE="$PWD/AnyKernel2-vince/modules/vendor/lib/modules/"
STRIP="$PWD/stock/bin/$(echo "$(find "$PWD/stock/bin" -type f -name "aarch64-*-gcc")" | awk -F '/' '{print $NF}' |\
			sed -e 's/gcc/strip/')"

# Export
export JOBS="$(grep -c '^processor' /proc/cpuinfo)"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="ramakun"
export CROSS_COMPILE

# Install build package
install-package --update-new ccache bc bash git-core gnupg build-essential \
	zip curl make automake autogen autoconf autotools-dev libtool shtool python \
	m4 gcc libtool zlib1g-dev

# Clone toolchain
wget https://developer.arm.com/-/media/Files/downloads/gnu-a/8.3-2019.03/binrel/gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu.tar.xz
tar xvf *.tar.xz
rm *.tar.xz
find $PWD/gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu/* -type f | xargs strip --strip-unneeded

# Clone AnyKernel2
git clone https://github.com/rama982/AnyKernel2 AnyKernel2-vince -b vince-aosp

# Build start
DATE=`date`
BUILD_START=$(date +"%s")

tg_sendstick

tg_channelcast "GENOM kernel for Custom AOSP ROM new build!" \
        "Only for device <b>vince</b> (Redmi 5 Plus)" \
    	"Using toolchain: <code>$($PWD/gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu/bin/aarch64-linux-gnu-gcc --version | head -1)</code>" \
	"Under <code>android_kernel_xiaomi_msm8953-4.9/${BRANCH}</code>" \
	"With latest commit <code>$(git log --pretty=format:'"%h : %s"' -1)</code>" \
	"Started on <code>$(date)</code>"

make O=out $CONFIG_VINCE $THREAD
make O=out $THREAD

if ! [ -a $KERN_IMG ]; then
	echo -e "Kernel compilation failed, See buildlog to fix errors"
	finerr
	exit 1
fi

cd $ZIP_DIR_VINCE
cp $KERN_IMG $ZIP_DIR_VINCE/zImage
make normal &>/dev/null
echo Genom*.zip
echo "Flashable zip generated under $ZIP_DIR."
push
cd ..
tg_channelcast "NOTES: ONLY INSTALL 4.9 KERNEL ON ROMs WITH PREBUILT 4.9 KERNEL!"

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))

fin

# Build end
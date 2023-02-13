#!/bin/sh

set -e
set -u

VER=RPi4_UEFI_Firmware_v1.33
SUBVER=${VER: -5}

# Sync submodules
git submodule sync --recursive
git submodule update --init --recursive --depth 1

# Sync Rpi4 sdcard boot firmware
mkdir -p sdcard/$VER
curl --output-dir sdcard -sSLO https://github.com/pftf/RPi4/releases/download/$SUBVER/$VER.zip && unzip -d sdcard/$VER sdcard/$VER.zip

# PATCH sdcard
cp config.txt sdcard/$VER
cp cmdline.txt sdcard/$VER

# Sync Toolchain
mkdir -p tools
curl -sSL https://developer.arm.com/-/media/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.xz | tar -C tools -xJ

# Sync Secure Boot default keys
mkdir -p keys
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=Raspberry Pi Platform Key/" -keyout /dev/null -outform DER -out keys/pk.cer -days 7300 -nodes -sha256
curl -sSL https://go.microsoft.com/fwlink/?LinkId=321185 -o keys/ms_kek.cer
curl -sSL https://go.microsoft.com/fwlink/?linkid=321192 -o keys/ms_db1.cer
curl -sSL https://go.microsoft.com/fwlink/?linkid=321194 -o keys/ms_db2.cer
curl -sSL https://uefi.org/sites/default/files/resources/dbxupdate_arm64.bin -o keys/arm64_dbx.bin

# PATCH UEFI
patch --binary -d edk2 -p1 -i ../0001-MdeModulePkg-UefiBootManagerLib-Signal-ReadyToBoot-o.patch
patch --binary -d edk2-platforms -p1 -i ../0002-Check-for-Boot-Discovery-Policy-change.patch
patch --binary -d edk2-platforms -p1 -i ../1000-RPi4-Settings.patch
cp Logo.bmp edk2-non-osi/Platform/RaspberryPi/Drivers/LogoDxe/Logo.bmp

# PATCH Linux
patch --binary -d linux -p1 -i ../1001-Enable-Linux-Uefi-Awareness.patch

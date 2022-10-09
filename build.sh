#!/bin/sh

set -e

export CROSS_COMPILE=$PWD/tools/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-

###############
# Build TF-A
###############
make -C trusted-firmware-a PLAT=rpi4 RPI3_PRELOADED_DTB_BASE=0x1F0000 PRELOADED_BL33_BASE=0x20000 SUPPORT_VFP=1 SMC_PCI_SUPPORT=1 DEBUG=1 all


###############
# Build UEFI
###############
make -C edk2/BaseTools

export TFA_BUILD_ARTIFACTS=$PWD/trusted-firmware-a/build/rpi4/debug
export ARCH=AARCH64
export COMPILER=GCC5
export GCC5_AARCH64_PREFIX=$CROSS_COMPILE
export WORKSPACE=$PWD
export PACKAGES_PATH=$WORKSPACE/edk2:$WORKSPACE/edk2-platforms:$WORKSPACE/edk2-non-osi
export BUILD_FLAGS="-D SECURE_BOOT_ENABLE=TRUE -D INCLUDE_TFTP_COMMAND=TRUE -D NETWORK_ISCSI_ENABLE=TRUE -D SMC_PCI_SUPPORT=1 -D TFA_BUILD_ARTIFACTS=$TFA_BUILD_ARTIFACTS"
export DEFAULT_KEYS="-D DEFAULT_KEYS=TRUE -D PK_DEFAULT_FILE=$WORKSPACE/keys/pk.cer -D KEK_DEFAULT_FILE1=$WORKSPACE/keys/ms_kek.cer -D DB_DEFAULT_FILE1=$WORKSPACE/keys/ms_db1.cer -D DB_DEFAULT_FILE2=$WORKSPACE/keys/ms_db2.cer -D DBX_DEFAULT_FILE1=$WORKSPACE/keys/arm64_dbx.bin"

source edk2/edksetup.sh
build -a ${ARCH} -t ${COMPILER} -b DEBUG -p edk2-platforms/Platform/RaspberryPi/RPi4/RPi4.dsc --pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVendor=L"RPi4 Ajay Custom" --pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVersionString=L"RPi4 Ajay Custom v3" ${BUILD_FLAGS} ${DEFAULT_KEYS}

cp Build/RPi4/DEBUG_${COMPILER}/FV/RPI_EFI.fd sdcard/RPi4_UEFI_Firmware_v1.33


###############
# Make Rootfs
###############
mkdir -p rootfs/{bin,dev,etc,home,mnt,root,lib64/modules,proc,sbin,sys/firmware/efi/efivars,tmp,usr/{bin,lib,sbin},var/log}
ln -s lib64 rootfs/lib
chmod a+rwxt rootfs/tmp

# Based on https://github.com/landley/toybox/blob/master/scripts/mkroot.sh
cat > rootfs/sbin/init << 'EOF' &&
#!/bin/sh

export HOME=/home PATH=/bin:/sbin

#mount -t devtmpfs dev /dev
#exec 0<>/dev/console 1>&0 2>&1
#for i in ,fd /0,stdin /1,stdout /2,stderr
#do ln -sf /proc/self/fd${i/,*/} /dev/${i/*,/}; done
#mkdir -p /dev/shm
#chmod +t /dev/shm
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t efivarfs efivarfs /sys/firmware/efi/efivars
mount -t tmpfs tmpfs /tmp
ifconfig lo 127.0.0.1

echo 3 > /proc/sys/kernel/printk     #cat /dev/kmsg

CONSOLE=/dev/tty1                    #LCD
##CONSOLE=/dev/ttyAMA0               #Serial
echo -e '\e[?7hType exit when done.'
exec oneit -c $CONSOLE /bin/sh
EOF
chmod +x rootfs/sbin/init &&

# Google's nameserver, passwd+group with special (root/nobody) accounts + guest
echo "nameserver 8.8.8.8" > rootfs/etc/resolv.conf &&
cat > rootfs/etc/passwd << 'EOF' &&
root:x:0:0:root:/root:/bin/sh
guest:x:500:500:guest:/home/guest:/bin/sh
nobody:x:65534:65534:nobody:/proc/self:/dev/null
EOF
echo -e 'root:x:0:\nguest:x:500:\nnobody:x:65534:' > rootfs/etc/group


###############
# Build Linux
###############
#TODO: Capture defconfig changes
make -C linux ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE bcm2711_defconfig
make -C linux -j$(nproc) ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE Image modules dtbs
make -C linux -j$(nproc) ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE INSTALL_MOD_PATH=$PWD/rootfs modules_install

mkdir -p sdcard/RPi4_UEFI_Firmware_v1.33/efi/boot
cp linux/arch/arm64/boot/dts/broadcom/bcm2711-rpi-*4*.dtb sdcard/RPi4_UEFI_Firmware_v1.33
cp linux/arch/arm64/boot/Image sdcard/RPi4_UEFI_Firmware_v1.33/efi/boot/bootaa64.efi


###############
# Build Toybox
###############
make -C toybox ARCH=aarch64 CROSS_COMPILE=${CROSS_COMPILE} PREFIX=$PWD/rootfs defconfig toybox
make -C toybox ARCH=aarch64 CROSS_COMPILE=${CROSS_COMPILE} PREFIX=$PWD/rootfs install

echo "toybox Dependencies:"
${CROSS_COMPILE}readelf -a toybox/toybox | grep -E "(program interpreter)|(Shared library)"

export SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
cp -L ${SYSROOT}/lib64/{ld-2.33.so,libcrypt.so.1,libm.so.6,libresolv.so.2,libc.so.6} rootfs/lib64/
ln -s ld-2.33.so rootfs/lib64/ld-linux-aarch64.so.1


###############
# Build Shell
###############
(cd mksh; CC=${CROSS_COMPILE}cc TARGET_OS=Linux sh Build.sh -r)
cp mksh/mksh rootfs/bin
ln -s mksh rootfs/bin/sh
cp mksh/dot.mkshrc rootfs/etc/mkshrc

echo "mksh Dependencies:"
${CROSS_COMPILE}readelf -a mksh/mksh | grep -E "(program interpreter)|(Shared library)"


#################
# Fix Permissions
#################
sudo chown -R root:root rootfs
sudo mknod -m 666 rootfs/dev/null c 1 3
sudo mknod -m 600 rootfs/dev/console c 5 1


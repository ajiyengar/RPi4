#https://developer.arm.com/-/media/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.xz
#Rpi-uefi v1.33

#Check out EDK2 submodules
git submodule udpate --init --recursive

#Patch EDK2 repositories
patch --binary -d edk2 -p1 -i ../0001-MdeModulePkg-UefiBootManagerLib-Signal-ReadyToBoot-o.patch
patch --binary -d edk2-platforms -p1 -i ../0002-Check-for-Boot-Discovery-Policy-change.patch

#Set up EDK2
make -C edk2/BaseTools

#Set up Secure Boot default keys
mkdir keys
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=Raspberry Pi Platform Key/" -keyout /dev/null -outform DER -out keys/pk.cer -days 7300 -nodes -sha256
curl -L https://go.microsoft.com/fwlink/?LinkId=321185 -o keys/ms_kek.cer
curl -L https://go.microsoft.com/fwlink/?linkid=321192 -o keys/ms_db1.cer
curl -L https://go.microsoft.com/fwlink/?linkid=321194 -o keys/ms_db2.cer
curl -L https://uefi.org/sites/default/files/resources/dbxupdate_arm64.bin -o keys/arm64_dbx.bin

#Build TF-A
git clone https://git.trustedfirmware.org/TF-A/trusted-firmware-a.git
export CROSS_COMPILE=aarch64-linux-gnu-
make -C trusted-firmware-a PLAT=rpi4 RPI3_PRELOADED_DTB_BASE=0x1F0000 PRELOADED_BL33_BASE=0x20000 SUPPORT_VFP=1 SMC_PCI_SUPPORT=1 DEBUG=0 all
export TFA_BUILD_ARTIFACTS=$PWD/trusted-firmware-a/build/rpi4/release

#Build UEFI firmware
export ARCH=AARCH64
export COMPILER=GCC5
export GCC5_AARCH64_PREFIX=aarch64-linux-gnu-
export WORKSPACE=$PWD
export PACKAGES_PATH=$WORKSPACE/edk2:$WORKSPACE/edk2-platforms:$WORKSPACE/edk2-non-osi
export BUILD_FLAGS="-D SECURE_BOOT_ENABLE=TRUE -D INCLUDE_TFTP_COMMAND=TRUE -D NETWORK_ISCSI_ENABLE=TRUE -D SMC_PCI_SUPPORT=1 -D TFA_BUILD_ARTIFACTS=$TFA_BUILD_ARTIFACTS"
export DEFAULT_KEYS="-D DEFAULT_KEYS=TRUE -D PK_DEFAULT_FILE=$WORKSPACE/keys/pk.cer -D KEK_DEFAULT_FILE1=$WORKSPACE/keys/ms_kek.cer -D DB_DEFAULT_FILE1=$WORKSPACE/keys/ms_db1.cer -D DB_DEFAULT_FILE2=$WORKSPACE/keys/ms_db2.cer -D DBX_DEFAULT_FILE1=$WORKSPACE/keys/arm64_dbx.bin"
source edk2/edksetup.sh
for BUILD_TYPE in DEBUG ; do
  build -a ${ARCH} -t ${COMPILER} -b $BUILD_TYPE -p edk2-platforms/Platform/RaspberryPi/RPi4/RPi4.dsc --pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVendor=L"RPi4 Ajay Custom" --pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVersionString=L"RPi4 Ajay Custom v2" ${BUILD_FLAGS} ${DEFAULT_KEYS}
done

cp Build/RPi4/DEBUG_${COMPILER}/FV/RPI_EFI.fd .

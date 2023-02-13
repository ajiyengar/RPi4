# Goal

Boot Raspberry Pi4 with custom boot loader, linux, shell and utilities:
* ARM Trusted Firmware
* UEFI
* Linux
* Mksh (Shell)
* Utilities (Toybox)


# Instructions

## Format USB flash drive

1. Format GPT and create 3 partitions:
   * `sudo cgdisk /dev/disk/by-id/<usb-drive>`
     * part1 (EFI system partition)
     * part2 (Linux swap)
     * part3 (Linux filesystem)
1. Format file systems
   * `sudo mkfs.vfat -F 16 /dev/disk/by-id/<usb-drive>-part1`
   * `sudo mkswap /dev/disk/by-id/<usb-drive>-part2`
   * `sudo mkfs.ext4 -N 803200 /dev/disk/by-id/<usb-drive>-part3`


## Boot!

1. Sync: `sync.sh`
1. Build: `build.sh`
1. Use `udisksctl` to:
   * Copy `/sdcard` to `/dev/disk/by-id/<usb-drive>-part1`
   * Copy `/rootfs` to `/dev/disk/by-id/<usb-drive>-part3`


### Miscellaneous

* Supports 1024x600 LCD; remove _hdmi*_ entries from _config.txt_ if not desired
* rootfs is mounted r/w


# Acknowledgements

* Forked from original project: [RPi4](https://github.com/pftf/RPi4)
* <https://www.linuxfromscratch.org>
* <https://landley.net>

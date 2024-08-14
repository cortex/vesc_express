# vesc-os-pi - LIND Flash Utility

This is the rootfs-overlay for https://github.com/Lindboard/vesc-os-pi/tree/LIND

### Getting started?

* Clone the LIND branch of vesc-os-pi fork linked above.
* Symlink or copy the `Firmware/rootfs-overlay` contents to the `vesc-os-pi/rootfs-overlay` directory. 
* Symlink or copy the `Firmware/build directory` contents to `rootfs-overlay/Firmware` directory. These will be flashed via the programming header.

### Notes

* For SSH access to the Pi edit `rootfs-overlay/lind/etc/network/interfaces` You may authenticate with root:vesclife
* The filesystem is read-only but you can gain write access via an SD card reader and a linux based system
* You can test code over SSH by storing files in `/var/run` 

### Compile with 12 cores (takes about an hour)

```
make BR2_EXTERNAL=../ vesc_rpi4_lind_defconfig
make BR2_EXTERNAL=../ BR2_JLEVEL=12
```

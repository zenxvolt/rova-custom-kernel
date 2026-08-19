## AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers
# Tailored for Xiaomi Redmi 4A (rolex) / Redmi 5A (riva) - kernel source
# codename "rova" - crDroid 13 (Android 13), custom KernelSU + Droidspaces build.

### AnyKernel setup
# global properties
properties() { '
kernel.string=rova Custom Kernel (KernelSU + Droidspaces) by GH Actions
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=rolex
device.name2=riva
device.name3=rova
supported.versions=10 - 13
supported.patchlevels=
'; } # end properties

### AnyKernel install
## boot files attributes
boot_attributes() {
  set_perm_recursive 0 0 755 644 $ramdisk/*;
  set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;
} # end attributes

# boot shell variables
# Redmi 4A/5A is an A-only (no A/B slots) Qualcomm device with a plain
# boot partition (no vendor_boot/dtbo split) - matches every other
# msm8917/msm8937-family AnyKernel3 script.
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

## AnyKernel boot install
dump_boot;

# No ramdisk modifications needed - we are only swapping the kernel
# Image + DTB, the existing crDroid ramdisk/init scripts are kept as-is.

write_boot;
## end boot install

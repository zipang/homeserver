{ config, pkgs, ... }:

{
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  # Keep only the 6 last boot entries in the grub menu
  boot.loader.systemd-boot.configurationLimit = 6;
  boot.loader.efi.canTouchEfiVariables = true;

  # Ensure the keyboard layout is applied in the early boot stage (initrd)
  # This is crucial for typing the root password in emergency mode.
  boot.initrd.systemd.enable = true;

  # Support for ZFS storage
  boot.supportedFilesystems = [ "zfs" ];
  # ZFS latest kernel compatibility
  boot.zfs.package = pkgs.zfs_unstable;
}

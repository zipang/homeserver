{ config, pkgs, ... }:

{
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  # Keep only the 6 last boot entries in the grub menu
  boot.loader.systemd-boot.configurationLimit = 6;
  boot.loader.efi.canTouchEfiVariables = true;
}

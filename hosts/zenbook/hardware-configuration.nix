# PLACEHOLDER: replaced during install (docs/INSTALL.md, step 6) by:
#   nixos-generate-config --no-filesystems --root /mnt --show-hardware-config
# Filesystems come from disko.nix, which is why --no-filesystems is used.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-amd" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

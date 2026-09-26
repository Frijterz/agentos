# Disk layout: 1 GB EFI partition + LUKS2-encrypted Btrfs with subvolumes.
#
# WARNING: running disko with this file ERASES THE WHOLE DISK (Windows included).
# Check the device name with `lsblk` before installing.
#
# System rollback comes from NixOS generations; /home gets Btrfs snapshots
# (see modules/nixos/snapshots.nix) so your files can be rolled back too.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes =
                let
                  opts = [
                    "compress=zstd"
                    "noatime"
                  ];
                in
                {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = opts;
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = opts;
                  };
                  # Nested inside /home so snapper can use it for the "home" config.
                  "/home/.snapshots" = { };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = opts;
                  };
                  "/log" = {
                    mountpoint = "/var/log";
                    mountOptions = opts;
                  };
                };
            };
          };
        };
      };
    };
  };
}

# ASUS Zenbook 14 OLED (UM3406HA / UM3406KA / UM3406GA): hardware quirks.
# Keep everything model-specific here so it can later be upstreamed to nixos-hardware.
{ pkgs, ... }:
{
  # Recent AMD chips (Hawk Point, Krackan, Strix) keep getting fixes; the NPU driver
  # (amdxdna) needs 6.14+.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Includes the Cirrus Logic CS35L41 amplifier firmware the speakers need.
  hardware.enableRedistributableFirmware = true;

  # OLED panel: if you see flicker or a black screen after resume, disable
  # PSR + Panel Replay by uncommenting this line:
  # boot.kernelParams = [ "amdgpu.dcdebugmask=0x410" ];

  hardware.graphics.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  services.fwupd.enable = true;

  # Stop charging at 80% to extend battery life (asus-wmi charge threshold).
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT*", ATTR{charge_control_end_threshold}="80"
  '';

  # MediaTek Wi-Fi (MT7922 / MT7925): if the connection drops, try:
  # networking.networkmanager.wifi.powersave = false;
}

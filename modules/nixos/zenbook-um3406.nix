# ASUS Zenbook 14 OLED UM3406KA: hardware quirks.
# Seen on the NixOS live USB (kernel 6.18), 2026-09-26:
#   CPU/GPU  Ryzen AI 7 350, Radeon 860M (Krackan), 32 GB
#   Display  Samsung 1920×1200 OLED, 60 Hz, HDR metadata (~600 nits)
#   Wi-Fi    MediaTek MT7922 (mt7921e): works
#   Audio    ALC294 + 2× Cirrus CS35L41 amps: UM3406KA tuning firmware loads
#   NPU      amdxdna driver binds
#   Battery  BAT0, charge_control_end_threshold supported
#   Sleep    s2idle only (normal for this platform)
#   SSD      Micron 2500 1 TB (nvme0n1)
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

  # MediaTek MT7922 Wi-Fi: if the connection drops, try:
  # networking.networkmanager.wifi.powersave = false;
}

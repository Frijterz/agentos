{ inputs, vars, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix

    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.stylix.nixosModules.stylix

    # There is no UM3406 profile in nixos-hardware yet (request: NixOS/nixos-hardware#1638),
    # so we combine the generic AMD laptop pieces and add our own quirks in zenbook-um3406.nix.
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-ssd

    ../../modules/nixos
  ];

  networking.hostName = vars.host;

  # Set once to the NixOS release you installed from, then never change it.
  system.stateVersion = "26.05";
}

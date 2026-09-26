{
  description = "agentos: a Claude-first NixOS desktop for the ASUS Zenbook 14 OLED (UM3406)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      # The only place to change your username, hostname or repo location.
      vars = rec {
        user = "frijterz";
        host = "zenbook";
        flakeDir = "/home/${user}/agentos";
      };
    in
    {
      nixosConfigurations.${vars.host} = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs vars; };
        modules = [ ./hosts/zenbook ];
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
    };
}

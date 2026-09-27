{ vars, ... }:
{
  imports = [
    ./hyprland.nix
    ./shell.nix
    ./idle.nix
    ./apps.nix
    ./weather.nix
    ./nightlight.nix
    ./terminal.nix
    ./clipboard.nix
    ./screenshots.nix
  ];

  home.username = vars.user;
  home.homeDirectory = "/home/${vars.user}";

  # Same rule as system.stateVersion: set once, never change.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}

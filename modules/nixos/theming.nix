# System-wide look via Stylix: GTK, Qt, terminal, Hyprland borders, lock screen,
# boot splash, launcher and notifications all follow one base16 scheme.
# The Quickshell shell reads the same colours from ~/.config/agentos/theme.json.
{ pkgs, ... }:
let
  # Generated so the repo carries no binary wallpaper. Put your own image at
  # ~/.local/state/agentos/wallpaper to use it on the desktop without a rebuild.
  wallpaper = pkgs.runCommand "agentos-wallpaper.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    magick -size 1920x1200 radial-gradient:'#1a1510-#070605' png:$out
  '';
in
{
  stylix = {
    enable = true;
    polarity = "dark";
    image = wallpaper;
    # Our own scheme: retro sci-fi / NASA-punk, near-black with mission orange.
    base16Scheme = ./themes/mission-control.yaml;

    fonts = {
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.inter;
        name = "Inter";
      };
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        applications = 11;
        desktop = 11;
        popups = 11;
        terminal = 12;
      };
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };

    # Translucent terminal and popups; Hyprland blurs what's behind them.
    opacity = {
      terminal = 0.88;
      popups = 0.92;
    };
  };
}

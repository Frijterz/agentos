# Home Manager generates ~/.config/hypr/hyprland.conf with the plugin lines and
# Stylix colours, then sources config/hypr/hyprland.conf straight from this repo.
# That file is live: edit and save, and Hyprland reloads it without a rebuild.
{
  lib,
  pkgs,
  vars,
  ...
}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    # Use the Hyprland and portal from the NixOS module (programs.hyprland).
    package = null;
    portalPackage = null;
    # uwsm manages the session and graphical-session.target.
    systemd.enable = false;

    plugins = [ pkgs.hyprlandPlugins.hyprexpo ];

    extraConfig = ''
      source = ${vars.flakeDir}/config/hypr/hyprland.conf
    '';
  };

  # Quickshell draws the wallpaper (config/quickshell/Background.qml).
  services.hyprpaper.enable = lib.mkForce false;
}

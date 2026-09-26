# Home Manager generates ~/.config/hypr/hyprland.conf with the Stylix colours, then sources config/hypr/hyprland.conf straight from this repo.
# That file is live: edit and save, and Hyprland reloads it without a rebuild.
{
  lib,
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

    # Home Manager defaults to Lua configs from stateVersion 26.05; config/hypr is hyprlang.
    configType = "hyprlang";

    # No plugins: they break on every Hyprland update (hyprexpo is gone, hyprspace
    # doesn't build on 0.56). The workspace overview will live in Quickshell instead.

    extraConfig = ''
      source = ${vars.flakeDir}/config/hypr/hyprland.conf
    '';
  };

  # Quickshell draws the wallpaper (config/quickshell/Background.qml).
  services.hyprpaper.enable = lib.mkForce false;
}

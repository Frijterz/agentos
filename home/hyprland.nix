# Home Manager generates ~/.config/hypr/hyprland.lua with the Stylix colours, then loads
# config/hypr/hyprland.lua straight from this repo with require(). Hyprland watches
# required files, so that one stays live: edit and save, and Hyprland reloads it.
{
  lib,
  osConfig,
  vars,
  ...
}:
let
  c = osConfig.lib.stylix.colors;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    # Use the Hyprland and portal from the NixOS module (programs.hyprland).
    package = null;
    portalPackage = null;
    # uwsm manages the session and graphical-session.target.
    systemd.enable = false;

    # Lua: Hyprland 0.57 drops the hyprlang (.conf) format.
    configType = "lua";

    # No plugins: they break on every Hyprland update (hyprexpo is gone, hyprspace
    # doesn't build on 0.56). The workspace overview lives in Quickshell instead.

    # Window borders: an accent edge fading to half strength (less static bright
    # orange on the OLED than Stylix's solid one), and a quiet dark edge when inactive.
    settings.config.general = {
      # A gradient is a table in Lua: { colors = { … }, angle = … }.
      "col.active_border" = lib.mkForce {
        colors = [
          "rgba(${c.base0D}ee)"
          "rgba(${c.base0D}66)"
        ];
        angle = 45;
      };
      "col.inactive_border" = lib.mkForce "rgb(${c.base02})";
    };

    extraConfig = ''
      require("${vars.flakeDir}/config/hypr/hyprland.lua")
    '';
  };

  # TRANSITION, removed after the first Lua login: the session that is running while
  # this is applied still reads hyprland.conf and reloads it during the switch; without
  # the file it would lose its key bindings until you log out. Hyprland prefers
  # hyprland.lua whenever it starts, so this only serves that one session.
  xdg.configFile."hypr/hyprland.conf".text = ''
    general {
      col.active_border = rgba(${c.base0D}ee) rgba(${c.base0D}66) 45deg
      col.inactive_border = rgb(${c.base02})
    }
    source = ${vars.flakeDir}/config/hypr/hyprland.conf
  '';

  # Quickshell draws the wallpaper (config/quickshell/Background.qml).
  services.hyprpaper.enable = lib.mkForce false;
}

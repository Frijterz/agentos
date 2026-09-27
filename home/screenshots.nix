# Screenshot editor: satty opens a fresh screenshot to draw arrows, boxes, text or
# blur on, and to crop. Enter copies the result and closes; Ctrl+S saves it to
# ~/Pictures/Screenshots. Keys in hyprland.lua: Super+Ctrl+S or Print for an area,
# Shift+Print for the whole screen (Super+Shift+S stays the quick copy, no editor).
{ osConfig, ... }:
let
  c = osConfig.lib.stylix.colors;
  fonts = osConfig.stylix.fonts;
in
{
  programs.satty = {
    enable = true;
    settings = {
      general = {
        initial-tool = "arrow";
        corner-roundness = 4; # like the windows: nearly square
        annotation-size-factor = 1.5;
        copy-command = "wl-copy";
        early-exit = [ "all" ]; # done after copying or saving
        actions-on-enter = [ "save-to-clipboard" ];
        output-filename = "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png";
        floating-hack = true;
      };
      font = {
        family = fonts.sansSerif.name;
        style = "Regular";
      };
      # The theme's colours for the pens: orange, red, amber, teal, paper, near-black.
      color-palette.palette = map (base: "#${c.${base}}ff") [
        "base0D"
        "base08"
        "base0A"
        "base0C"
        "base05"
        "base00"
      ];
    };
  };

  # Where Ctrl+S saves.
  systemd.user.tmpfiles.rules = [ "d %h/Pictures/Screenshots 0755 - - -" ];
}

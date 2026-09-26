# Idle chain: screensaver (4 min) → lock (10) → screen off (11) → suspend (30).
# Full paths because systemd user services don't get your shell's PATH.
{ pkgs, ... }:
let
  qs = "${pkgs.quickshell}/bin/qs";
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  loginctl = "${pkgs.systemd}/bin/loginctl";
  systemctl = "${pkgs.systemd}/bin/systemctl";
in
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
        before_sleep_cmd = "${loginctl} lock-session";
        after_sleep_cmd = "${hyprctl} dispatch dpms on";
      };
      listener = [
        {
          timeout = 240;
          on-timeout = "${qs} ipc call screensaver start";
          on-resume = "${qs} ipc call screensaver stop";
        }
        {
          timeout = 600;
          on-timeout = "${loginctl} lock-session";
        }
        {
          timeout = 660;
          on-timeout = "${hyprctl} dispatch dpms off";
          on-resume = "${hyprctl} dispatch dpms on";
        }
        {
          timeout = 1800;
          on-timeout = "${systemctl} suspend";
        }
      ];
    };
  };

  # Stylix styles the background and input field; we add a big clock.
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };
      label = [
        {
          text = "$TIME";
          font_size = 110;
          position = "0, 180";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}

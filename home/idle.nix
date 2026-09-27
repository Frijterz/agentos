# Idle chain: screensaver (4 min) → lock (10) → screen off (11) → suspend (30).
# Full paths because systemd user services don't get your shell's PATH.
{ config, pkgs, ... }:
let
  qs = "${pkgs.quickshell}/bin/qs";
  c = config.lib.stylix.colors;
  mono = config.stylix.fonts.monospace.name;
  weatherFile = "${config.xdg.stateHome}/agentos/weather.json";
  logo = import ../modules/nixos/themes/agentos-logo.nix {
    inherit pkgs;
    colors = config.lib.stylix.colors;
  };
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  loginctl = "${pkgs.systemd}/bin/loginctl";
  systemctl = "${pkgs.systemd}/bin/systemctl";

  # Every lock (idle, Super+Ctrl+L, the system menu, before sleep) runs this: the lower
  # sonar ping (transmission closes) on locking, the higher one on unlocking.
  sounds = import ../modules/nixos/themes/agentos-sounds.nix { inherit pkgs; };
  lock = pkgs.writeShellScript "agentos-lock" ''
    ${pkgs.procps}/bin/pidof hyprlock >/dev/null && exit 0
    ${pkgs.pipewire}/bin/pw-play ${sounds}/transmission-out.wav &
    ${pkgs.hyprlock}/bin/hyprlock
    ${pkgs.pipewire}/bin/pw-play ${sounds}/transmission-in.wav
  '';
in
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "${lock}";
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

  # Mission Control lock screen, matching the screensaver: amber clock, date, weather
  # (home/weather.nix), square input field. Styled here, so Stylix's version is off.
  stylix.targets.hyprlock.enable = false;
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };
      background = [
        {
          monitor = "";
          color = "rgb(${c.base00})";
        }
      ];
      # The agentOS mark, with its glow baked in (hyprlock can't animate). The wordmark
      # is a label below: hyprlock's image widget is square, made for profile photos.
      image = [
        {
          monitor = "";
          path = "${logo}/mark-glow@2x.png";
          size = 150;
          rounding = 0;
          border_size = 0;
          position = "0, 410";
          halign = "center";
          valign = "center";
        }
      ];
      label = [
        {
          # "##": hyprlang reads a single # as the start of a comment.
          text = ''<span foreground="##${c.base05}">agent</span><span foreground="##${c.base0D}">OS</span>'';
          font_family = "${mono} Bold";
          font_size = 20;
          position = "0, -330";
          halign = "center";
          valign = "center";
        }
        {
          text = "MISSION CONTROL  ·  AUTHORIZATION REQUIRED";
          color = "rgba(${c.base0D}99)";
          font_family = mono;
          font_size = 12;
          position = "0, 290";
          halign = "center";
          valign = "center";
        }
        {
          text = "$TIME";
          color = "rgba(${c.base0D}dd)";
          font_family = mono;
          font_size = 112;
          position = "0, 180";
          halign = "center";
          valign = "center";
        }
        {
          text = ''cmd[update:60000] ${pkgs.coreutils}/bin/date +"%A %-d %B %Y" | ${pkgs.coreutils}/bin/tr a-z A-Z'';
          color = "rgba(${c.base05}88)";
          font_family = mono;
          font_size = 14;
          position = "0, 70";
          halign = "center";
          valign = "center";
        }
        {
          text = ''cmd[update:600000] ${pkgs.jq}/bin/jq -r '"\(.place)  ·  \(.temp)°C  ·  \(.desc)" | ascii_upcase' ${weatherFile} 2>/dev/null'';
          color = "rgba(${c.base05}66)";
          font_family = mono;
          font_size = 12;
          position = "0, 38";
          halign = "center";
          valign = "center";
        }
      ];
      input-field = [
        {
          monitor = "";
          size = "340, 48";
          position = "0, -110";
          halign = "center";
          valign = "center";
          rounding = 0;
          outline_thickness = 1;
          outer_color = "rgba(${c.base0D}aa)";
          inner_color = "rgb(${c.base01})";
          font_color = "rgb(${c.base05})";
          font_family = mono;
          check_color = "rgb(${c.base0A})";
          fail_color = "rgb(${c.base08})";
          fail_text = "ACCESS DENIED  ($ATTEMPTS)";
          placeholder_text = "ENTER PASSPHRASE";
          dots_size = 0.2;
          dots_spacing = 0.4;
          fade_on_empty = false;
        }
      ];
    };
  };
}

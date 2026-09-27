# Weather for the screensaver and lock screen: fetched from wttr.in (free, no account)
# every 30 minutes into ~/.local/state/agentos/weather.json. Pinned to a place because
# wttr.in's guess from the IP address (the provider's location) said Utrecht; set
# `location = ""` to go back to that guess, e.g. when travelling.
{ pkgs, ... }:
let
  location = "Veghel,Netherlands";

  agentos-weather = pkgs.writeShellApplication {
    name = "agentos-weather";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/agentos"
      mkdir -p "$state"
      # Offline or wttr.in down: keep the last reading.
      json="$(curl -fsS --max-time 20 "https://wttr.in/${location}?format=j1")" || exit 0
      out="$(jq -c '{
          temp: (.current_condition[0].temp_C | tonumber),
          feels: (.current_condition[0].FeelsLikeC | tonumber),
          desc: (.current_condition[0].weatherDesc[0].value | gsub("^\\s+|\\s+$"; "")),
          place: (.nearest_area[0].areaName[0].value | gsub("^\\s+|\\s+$"; "")),
          updated: now | floor
        }' <<<"$json")" || exit 0
      # In place, not mv: Quickshell's FileView watches this file.
      printf '%s\n' "$out" >"$state/weather.json"
    '';
  };
in
{
  home.packages = [ agentos-weather ];

  systemd.user.services.agentos-weather = {
    Unit.Description = "Fetch the weather for the screensaver and lock screen";
    Service = {
      Type = "oneshot";
      ExecStart = "${agentos-weather}/bin/agentos-weather";
    };
  };
  systemd.user.timers.agentos-weather = {
    Unit.Description = "Refresh the weather every 30 minutes";
    Timer = {
      OnStartupSec = "1min";
      OnUnitActiveSec = "30min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}

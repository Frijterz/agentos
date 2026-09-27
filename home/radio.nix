# Claude FM: Anthropic's 24/7 lo-fi / ambient stream ("music for thinking and building").
# It only exists as a YouTube live stream (clau.de/radio), so mpv plays just its audio:
# no browser tab, much lighter on the battery. Super+R or "Claude FM" in the launcher
# turns it on or off; it runs as its own user service, so closing the launcher or
# restarting the shell doesn't stop it. mpv's MPRIS plugin lets playerctl (the
# play/pause key, the AirPods stems) pause and resume it.
# The wallpaper (config/quickshell/Background.qml) shows it: a play/stop button, the
# current song (agentos-radio-now reads it off the stream's ticker) and sound waves (cava).
{ lib, pkgs, ... }:
let
  mpv = pkgs.mpv.override { scripts = [ pkgs.mpvScripts.mpris ]; };

  # The song, read off the stream's video (agent/agentos-radio-now.py explains how).
  # English only: tesseract with every language is ~1 GiB.
  agentos-radio-now = pkgs.writeShellApplication {
    name = "agentos-radio-now";
    runtimeInputs = [
      pkgs.python3
      pkgs.yt-dlp
      pkgs.ffmpeg-headless
      (pkgs.tesseract.override { enableLanguages = [ "eng" ]; })
    ];
    # One thread for tesseract (it uses every core by default).
    text = ''
      export OMP_THREAD_LIMIT=1
      exec python3 ${../agent/agentos-radio-now.py} "$@"
    '';
  };
  agentos-radio = pkgs.writeShellApplication {
    name = "agentos-radio";
    runtimeInputs = [
      pkgs.systemd
      pkgs.libnotify
    ];
    text = ''
      # agentos-radio [toggle | play | stop]
      unit=agentos-radio
      play() {
        # yt-dlp by full path: the service doesn't get your shell's PATH.
        systemd-run --user --quiet --collect --unit="$unit" --description="Claude FM" \
          ${mpv}/bin/mpv --no-video --no-terminal --title="Claude FM" \
            --ytdl-format=bestaudio --script-opts=ytdl_hook-ytdl_path=${pkgs.yt-dlp}/bin/yt-dlp \
            https://clau.de/radio
        # Stops with the radio: BindsTo ends it when the radio's unit goes away.
        systemd-run --user --quiet --collect --unit="$unit-now" --description="Claude FM: current song" \
          --property=BindsTo="$unit.service" --property=After="$unit.service" \
          --property=CPUSchedulingPolicy=idle --property=IOSchedulingClass=idle \
          ${agentos-radio-now}/bin/agentos-radio-now loop
        notify-send -a Claude "Claude FM" "Music for thinking and building. Super+R stops it." || true
      }
      stop() {
        systemctl --user stop "$unit" "$unit-now" 2>/dev/null || true
        rm -f "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/agentos-radio-now.json"
      }
      case "''${1:-toggle}" in
        play) systemctl --user is-active --quiet "$unit" || play ;;
        stop) stop ;;
        toggle) if systemctl --user is-active --quiet "$unit"; then stop; else play; fi ;;
        *)
          echo "usage: agentos-radio [toggle|play|stop]" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  home.packages = [
    agentos-radio
    agentos-radio-now
    pkgs.cava
  ];

  # Sound waves for the wallpaper: cava prints 32 bar heights (0–100) per line. 20 times a
  # second on mains power, 10 on battery (cava itself uses next to no CPU; the calmer rate
  # halves the redraws). Background.qml runs it only while the radio plays and the
  # wallpaper shows, and not in battery mode.
  xdg.configFile = lib.genAttrs' [ 20 10 ] (fps: {
    name = "agentos/cava${lib.optionalString (fps == 10) "-battery"}.conf";
    value.text = ''
      [general]
      framerate = ${toString fps}
      bars = 32
      [input]
      method = pipewire
      source = auto
      [output]
      method = raw
      raw_target = /dev/stdout
      data_format = ascii
      ascii_max_range = 100
      bar_delimiter = 59
      frame_delimiter = 10
      [smoothing]
      noise_reduction = 77
    '';
  });

  # In the launcher (Super+Space): type "Claude FM" or "radio".
  xdg.desktopEntries.claude-fm = {
    name = "Claude FM";
    genericName = "Radio";
    comment = "Lo-fi and ambient music for thinking and building (on / off)";
    exec = "agentos-radio toggle";
    icon = "de.haeckerfelix.Shortwave";
    categories = [
      "AudioVideo"
      "Audio"
    ];
    settings.Keywords = "radio;music;lofi;claude;";
  };
}

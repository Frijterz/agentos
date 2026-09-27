# Claude FM: Anthropic's 24/7 lo-fi / ambient stream ("music for thinking and building").
# It only exists as a YouTube live stream (clau.de/radio), so mpv plays just its audio:
# no browser tab, much lighter on the battery. Super+R or "Claude FM" in the launcher
# turns it on or off; it runs as its own user service, so closing the launcher or
# restarting the shell doesn't stop it. mpv's MPRIS plugin lets playerctl (the
# play/pause key, the AirPods stems) pause and resume it.
{ pkgs, ... }:
let
  mpv = pkgs.mpv.override { scripts = [ pkgs.mpvScripts.mpris ]; };
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
        notify-send -a Claude "Claude FM" "Music for thinking and building. Super+R stops it." || true
      }
      stop() {
        systemctl --user stop "$unit" 2>/dev/null || true
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
  home.packages = [ agentos-radio ];

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

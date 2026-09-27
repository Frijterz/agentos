# Clipboard history (Super+V, config/quickshell/Clipboard.qml): cliphist stores what
# you copy, text and images, the newest 300 entries in ~/.cache/cliphist.
# Passwords copied with Super+Shift+P never get in: rofi-rbw marks them sensitive and
# cliphist skips those. Our own watchers rather than Home Manager's module, because
# cliphist also treats a "clear" (rofi-rbw wiping the password after 20 s) as "delete
# the newest entry", which would be whatever you copied before the password.
{ pkgs, ... }:
let
  store = pkgs.writeShellScript "agentos-cliphist-store" ''
    [ "''${CLIPBOARD_STATE:-}" = clear ] && exit 0
    exec ${pkgs.cliphist}/bin/cliphist -max-items 300 store
  '';
  watcher = type: {
    Unit = {
      Description = "Clipboard history: store copied ${type}";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste ${
        if type == "images" then "--type image" else "--type text"
      } --watch ${store}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
in
{
  home.packages = [ pkgs.cliphist ];
  systemd.user.services.agentos-cliphist-text = watcher "text";
  systemd.user.services.agentos-cliphist-images = watcher "images";
}

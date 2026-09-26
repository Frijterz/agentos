# The Quickshell desktop shell: bar, Claude panel, animated background, screensaver.
{
  config,
  osConfig,
  pkgs,
  vars,
  ...
}:
let
  colors = osConfig.lib.stylix.colors.withHashtag;
  fonts = osConfig.stylix.fonts;
in
{
  home.packages = [ pkgs.quickshell ];

  # Link straight to the repo (not the Nix store) so QML edits hot-reload instantly.
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${vars.flakeDir}/config/quickshell";

  # Stylix colours for the shell, read by config/quickshell/Theme.qml.
  xdg.configFile."agentos/theme.json".text = builtins.toJSON {
    inherit (colors)
      base00
      base01
      base02
      base03
      base04
      base05
      base06
      base07
      base08
      base09
      base0A
      base0B
      base0C
      base0D
      base0E
      base0F
      ;
    fontSans = fonts.sansSerif.name;
    fontMono = fonts.monospace.name;
  };

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell (agentos desktop shell)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # FileView misses Home Manager's symlink swap, so restart on a new theme instead.
      X-Restart-Triggers = [ config.xdg.configFile."agentos/theme.json".source ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
      RestartSec = 2;
      # The Claude panel runs agentos-ask from the system profile.
      Environment = "PATH=/run/wrappers/bin:/etc/profiles/per-user/${vars.user}/bin:/run/current-system/sw/bin";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}

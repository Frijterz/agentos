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

  # The Claude mark for the bar button and the panel header, from Simple Icons (pinned),
  # in Claude's terracotta. Fetched at build time rather than committed: it's Anthropic's
  # trademark and this repo is public. Theme.qml falls back to ✦ without it.
  claudeIcon = pkgs.runCommand "claude-icon.svg" {
    src = pkgs.fetchurl {
      url = "https://cdn.jsdelivr.net/npm/simple-icons@16.32.0/icons/claude.svg";
      hash = "sha256-LW/aeesY3czKNbeZ7rPOzg36vCJSDOOxCr0lZo35+pM=";
    };
  } ''sed 's/<path /<path fill="#D97757" /' "$src" > "$out"'';

  # Line icons (Lucide, in the palette) for the bar and the system menu.
  icons = import ../modules/nixos/themes/agentos-icons.nix {
    inherit pkgs;
    colors = osConfig.lib.stylix.colors;
  };

  # UI sounds for notifications (and the lock screen, home/idle.nix).
  sounds = import ../modules/nixos/themes/agentos-sounds.nix { inherit pkgs; };

  # The agentOS logo (same images as the boot splash), for wallpaper and screensaver.
  logo = import ../modules/nixos/themes/agentos-logo.nix {
    inherit pkgs;
    colors = osConfig.lib.stylix.colors;
  };
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
    claudeIcon = "${claudeIcon}";
    logoDir = "${logo}";
    soundDir = "${sounds}";
    iconDir = "${icons}";
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

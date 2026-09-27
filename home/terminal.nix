# Terminal look: a quiet Mission Control prompt (Starship) and a start-up summary
# (fastfetch) in new Ghostty windows. Dim labels, values in paper white, orange only
# where it matters: the same language as the bar's telemetry.
{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  colors = osConfig.lib.stylix.colors;
  logo = import ../modules/nixos/themes/agentos-logo.nix { inherit pkgs colors; };
  # The planet over the "agentOS" wordmark, cropped to the drawing. Composed here, not
  # in agentos-logo.nix, so the boot splash doesn't rebuild for a terminal tweak.
  lockup = pkgs.runCommand "agentos-lockup.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    magick \( ${logo}/mark@2x.png -trim +repage \) \
      -size 1x36 xc:none \
      \( ${logo}/word@2x.png -trim +repage -resize 70% \) \
      -background none -gravity center -append png:$out
  '';
  # A true-colour ANSI code: the terminal palette's bright black is near the background.
  ansi = base: "38;2;${colors."${base}-rgb-r"};${colors."${base}-rgb-g"};${colors."${base}-rgb-b"}";
in
{
  # Colours come from Stylix's palette for Starship (base00…base0f).
  #   ~/agentos  git main +2 !1  took 4s
  #   ❯
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true; # a blank line between commands: room to breathe
      format = lib.concatStrings [
        "$directory"
        "$git_branch"
        "$git_state"
        "$git_status"
        "$nix_shell"
        "$cmd_duration"
        "$status"
        "$line_break"
        "$character"
      ];
      directory = {
        style = "bold base05";
        read_only = " ro";
        read_only_style = "base08";
        truncation_length = 3;
        truncate_to_repo = false;
        format = "[$path]($style)[$read_only]($read_only_style) ";
      };
      git_branch = {
        style = "base0c";
        format = "[git](base03) [$branch]($style) ";
      };
      git_state.style = "base09";
      git_status = {
        style = "base09";
        format = "([$all_status$ahead_behind]($style) )";
      };
      nix_shell = {
        style = "base0c";
        format = "[nix](base03) [$name]($style) ";
      };
      cmd_duration = {
        min_time = 2000;
        format = "[took](base03) [$duration](base04) ";
      };
      status = {
        disabled = false;
        format = "[exit $status](base08) ";
      };
      character = {
        success_symbol = "[❯](base0d)";
        error_symbol = "[❯](base08)";
        vimcmd_symbol = "[❮](base0c)";
      };
    };
  };

  # System summary with the agentOS mark (Ghostty shows real images): dim labels,
  # the host in mission orange.
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "kitty-direct";
        source = "${lockup}";
        # The image's aspect ratio (1.38) in Ghostty's cells (about 2.2 × taller than
        # wide); other sizes stretch it.
        width = 24;
        height = 8;
        padding = {
          top = 1;
          left = 2;
          right = 3;
        };
      };
      display = {
        separator = "  ";
        key.width = 9; # the longest label (UPTIME) plus room
        color = {
          keys = ansi "base04";
          title = ansi "base0D";
        };
      };
      modules = [
        "break"
        {
          type = "title";
          format = "{user-name}{#${ansi "base04"}}@{#${ansi "base0D"}}{host-name}";
        }
        "break"
        {
          type = "os";
          key = "OS";
          format = "agentOS · {pretty-name}";
        }
        {
          type = "command";
          key = "GEN";
          # The newest NixOS generation and when it was made (the link's date: store
          # paths are all dated 1970).
          text = ''g=$(readlink /nix/var/nix/profiles/system); echo "''${g//[^0-9]/} · $(date -d @$(stat -c %Y /nix/var/nix/profiles/$g) '+%-d %b %H:%M')"'';
        }
        {
          type = "kernel";
          key = "KERNEL";
          format = "{release}";
        }
        {
          type = "wm";
          key = "WM";
        }
        {
          type = "uptime";
          key = "UPTIME";
        }
        {
          type = "cpu";
          key = "CPU";
          format = "{name}";
        }
        {
          type = "memory";
          key = "MEM";
        }
        {
          type = "disk";
          key = "DISK";
          folders = "/";
        }
        {
          type = "battery";
          key = "BAT";
        }
      ];
    };
  };

  # New Ghostty windows greet you with it; Herdr panes, nested shells and Claude's
  # shells (not interactive) don't. Run `fastfetch` any time to see it again.
  programs.zsh.initContent = ''
    if [[ -o interactive && "$(ps -o comm= -p $PPID)" == *ghostty* && $COLUMNS -ge 70 ]]; then
      fastfetch
    fi
  '';
}

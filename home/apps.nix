{ pkgs, ... }:
{
  home.packages = with pkgs; [
    grim
    slurp
    wl-clipboard
    hyprpicker
    brightnessctl
    playerctl
    pavucontrol
    networkmanagerapplet
  ];

  programs.ghostty = {
    enable = true;
    settings = {
      window-padding-x = 14;
      window-padding-y = 12;
      window-decoration = false;
      cursor-style = "bar";
      confirm-close-surface = false;
    };
  };

  # Launcher (Super+Space) until the Quickshell launcher exists.
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "ghostty";
        width = 40;
        lines = 10;
        horizontal-pad = 24;
        vertical-pad = 16;
      };
      border = {
        radius = 14;
        width = 2;
      };
    };
  };

  # Notifications until the Quickshell notification centre exists.
  services.mako = {
    enable = true;
    settings = {
      default-timeout = 6000;
      border-radius = 14;
      padding = "12";
      margin = "12";
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };
  programs.starship.enable = true;
  programs.btop.enable = true;
}

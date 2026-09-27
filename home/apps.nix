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
    # Agent multiplexer: persistent panes for Claude Code etc. (Super+Enter opens it).
    # Updated by Nix; `herdr update` can't write to the store.
    herdr
    # Herdr's Claude hook (~/.claude/hooks/herdr-agent-state.sh) is Python: without it
    # Herdr can't match panes to Claude sessions or restore them after a reboot.
    python3
    # Bitwarden (Mac, iPhone and here): rbw is a small native CLI client instead of the
    # ~490 MiB Electron app; the Chromium extension (modules/nixos/desktop.nix) covers
    # the browser. The account email is set with `rbw config set email …` (kept out of
    # this public repo); rbw asks for the master password with pinentry-gnome3.
    rbw
    pinentry-gnome3
  ];

  # Links and web files open in Chromium (Super+B).
  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      let
        browser = "chromium-browser.desktop";
      in
      {
        "text/html" = browser;
        "application/xhtml+xml" = browser;
        "x-scheme-handler/http" = browser;
        "x-scheme-handler/https" = browser;
        "x-scheme-handler/about" = browser;
        "x-scheme-handler/unknown" = browser;
        # claude-cli:// links (e.g. signing in from the browser): Claude Code's own
        # handler, which it wrote to mimeapps.list before Home Manager managed the file.
        "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      };
  };

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
      # agentos-mode presentation/focus: hide notifications (still in `makoctl history`).
      "mode=do-not-disturb".invisible = 1;
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };
  # GitHub's noreply address keeps the real email out of the public history.
  programs.git = {
    enable = true;
    settings.user = {
      name = "Frijterz";
      email = "120751077+Frijterz@users.noreply.github.com";
    };
  };

  programs.starship.enable = true;
  programs.btop.enable = true;
}

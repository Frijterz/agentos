{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors; # the Mission Control palette, hex without "#"
in
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
    libnotify # notify-send, e.g. the Claude panel's "Claude is done"
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
    # Passwords from the launcher (Super+P types, Super+Shift+P copies): fuzzel search
    # over the Bitwarden vault via rbw; typed with wtype, so no clipboard by default.
    # Patched: fuzzel 1.14 dropped the long `--override=` option (only `-o` works) and
    # rofi-rbw 1.7 uses it, so fuzzel quit instantly and nothing appeared. The attached
    # short form keeps it one argument. --replace-fail: the build breaks once upstream
    # changes this line, which is the cue to drop the patch.
    (rofi-rbw-wayland.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/rofi_rbw/selector/fuzzel.py \
          --replace-fail 'f"--override=key-bindings' 'f"-okey-bindings'
      '';
    }))
  ];

  # Despite the name, rofi-rbw works with fuzzel. A copied password is cleared after 20 s.
  xdg.configFile."rofi-rbw.rc".text = ''
    selector = fuzzel
    typer = wtype
    clipboarder = wl-copy
    clear-after = 20
    prompt = 󰌾 Bitwarden
  '';

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
        # "Show in folder" and friends open Thunar.
        "inode/directory" = "thunar.desktop";
      };
  };

  # Yazi: the keyboard file manager, in Ghostty (Super+E). Stylix themes it; Ghostty
  # shows image previews inline. `y` in the shell opens it and, on quit, leaves you
  # in the folder you ended up in.
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";
    settings.mgr = {
      sort_dir_first = true;
      show_hidden = false; # . toggles
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
  # fuzzel now only serves the Super+P password menu (rofi-rbw needs a dmenu-style
  # picker; apps use the Quickshell launcher). Styled like that launcher: same card,
  # colours and position, so Stylix's fuzzel colours are off.
  stylix.targets.fuzzel.enable = false;
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "ghostty";
        font = "${config.stylix.fonts.monospace.name}:size=12";
        prompt = "'󰌾  '";
        anchor = "top";
        y-margin = 192; # 20% down, like the launcher
        width = 48;
        lines = 8;
        horizontal-pad = 20;
        vertical-pad = 16;
        inner-pad = 10;
        line-height = 26;
        icons-enabled = false;
      };
      colors = {
        background = "${c.base00}db"; # 86%
        text = "${c.base05}ff";
        prompt = "${c.base0D}ff";
        placeholder = "${c.base04}ff";
        input = "${c.base05}ff";
        match = "${c.base0D}ff";
        selection = "${c.base0D}29"; # 16%
        selection-text = "${c.base0D}ff";
        selection-match = "${c.base0D}ff";
        border = "${c.base0D}4d"; # 30%
      };
      border = {
        radius = 20;
        width = 1;
      };
    };
  };

  # Notifications: Quickshell is the notification daemon now (config/quickshell/
  # Notifs.qml, Toasts.qml, history in the system menu), so no mako.

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

  programs.btop.enable = true;
}

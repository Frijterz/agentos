{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
let
  session = "uwsm start hyprland-uwsm.desktop";

  # A Chromium theme (an extension with only a manifest) from the Stylix palette, so the
  # browser matches the bar and panel and follows theme changes. Loaded with
  # --load-extension below.
  colors = config.lib.stylix.colors;
  rgb =
    base:
    map (channel: lib.toInt colors."${base}-rgb-${channel}") [
      "r"
      "g"
      "b"
    ];
  chromiumTheme = pkgs.writeTextDir "manifest.json" (
    builtins.toJSON {
      manifest_version = 3;
      name = "agentos (Stylix)";
      version = "1";
      theme.colors = {
        frame = rgb "base00";
        frame_inactive = rgb "base00";
        frame_incognito = rgb "base00";
        frame_incognito_inactive = rgb "base00";
        toolbar = rgb "base01";
        toolbar_text = rgb "base05";
        toolbar_button_icon = rgb "base05";
        tab_text = rgb "base05";
        tab_background_text = rgb "base04";
        tab_background_text_inactive = rgb "base03";
        bookmark_text = rgb "base05";
        omnibox_background = rgb "base00";
        omnibox_text = rgb "base05";
        ntp_background = rgb "base00";
        ntp_text = rgb "base05";
        ntp_link = rgb "base0D";
        ntp_header = rgb "base01";
      };
    }
  );
in
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # The LUKS passphrase at boot already proves it's you, so log straight into
  # Hyprland (like Omarchy). hyprlock takes over when idle or on Super+Ctrl+L.
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = session;
        user = vars.user;
      };
      default_session = {
        command = "${config.services.greetd.package}/bin/agreety --cmd '${session}'";
        user = "greeter";
      };
    };
  };

  security.pam.services.hyprlock = { };

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  environment.sessionVariables.NIXOS_OZONE_WL = "1"; # Electron/Chromium apps on Wayland
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  security.rtkit.enable = true;

  # Graphical password prompts for privileged actions. The polkit agent is Quickshell
  # (config/quickshell/ShellState.qml): themed prompts, and Apply's inside the panel card.
  security.polkit.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  services.blueman.enable = true;

  # Browser: Chromium (native Wayland via NIXOS_OZONE_WL above), themed from Stylix.
  # Stylix's own Chromium target is off: its BrowserThemeColor policy only tints
  # Chromium's palette and blocks every theme extension, ours included.
  environment.systemPackages = [
    (pkgs.chromium.override { commandLineArgs = [ "--load-extension=${chromiumTheme}" ]; })
  ];
  stylix.targets.chromium.enable = false;

  # Chromium policies (/etc/chromium/policies): Bitwarden is the password manager, so
  # it's installed for you from the Chrome Web Store, and Chromium's own "save
  # password?" is off to avoid two managers competing.
  programs.chromium = {
    enable = true;
    extensions = [ "nngceckbapebfimnlniiiahkandclblb" ]; # Bitwarden
    extraOpts.PasswordManagerEnabled = false;
  };
}

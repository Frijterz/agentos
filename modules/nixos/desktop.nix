{
  config,
  pkgs,
  vars,
  ...
}:
let
  session = "uwsm start hyprland-uwsm.desktop";
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
  programs.firefox.enable = true;
}

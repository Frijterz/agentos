{ pkgs, vars, ... }:
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    trusted-users = [
      "root"
      vars.user
    ];
  };

  # claude-code is unfree.
  nixpkgs.config.allowUnfree = true;

  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_MEASUREMENT = "nl_NL.UTF-8";
    LC_MONETARY = "nl_NL.UTF-8";
    LC_PAPER = "nl_NL.UTF-8";
  };

  users.users.${vars.user} = {
    isNormalUser = true;
    description = vars.user;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ];
    shell = pkgs.zsh;
    # No password in the repo: set it with `passwd` during install (docs/INSTALL.md).
  };

  programs.zsh.enable = true;
  programs.git.enable = true;

  # Lets prebuilt binaries (npx tools, AppImages, downloaded CLIs) run on NixOS.
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    curl
    wget
    jq
    ripgrep
    fd
    unzip
    fastfetch
    gh
    nodejs
    alsa-utils # speaker-test, aplay, alsamixer: audio debugging
  ];
}

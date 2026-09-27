{
  boot.loader = {
    systemd-boot = {
      enable = true;
      # Every rebuild is a boot entry; keep 20 to roll back to.
      configurationLimit = 20;
      editor = false;
    };
    efi.canTouchEfiVariables = true;
    # Time to pick an older generation. Lower it once you trust the system.
    timeout = 3;
  };

  # systemd in initrd so Plymouth can ask for the LUKS password graphically.
  boot.initrd.systemd.enable = true;
  boot.plymouth.enable = true; # agentOS theme: splash.nix
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "splash"
    "udev.log_level=3"
  ];

  zramSwap.enable = true;
}

# The Claude layer: Claude can read, explain, edit this repo and build. Applying a
# build takes your password: `nh os switch`, or Apply in the panel (agentos-switch@).
# See agent/README.md for the phases.
{
  config,
  pkgs,
  vars,
  ...
}:
let
  # Weekly update prepared in a separate worktree, offered as a card in the panel.
  agentos-update = pkgs.writeShellApplication {
    name = "agentos-update";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.git
      pkgs.jq
      pkgs.nvd
      pkgs.libnotify
      pkgs.claude-code
      config.nix.package
    ];
    text = builtins.readFile ../../agent/agentos-update.sh;
  };

  # Root side of the panel's Apply button; only reachable as agentos-switch@<hash>.
  agentos-switch = pkgs.writeShellApplication {
    name = "agentos-switch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnused
      pkgs.gawk
      pkgs.nix
      pkgs.btrfs-progs
    ];
    text = builtins.readFile ../../agent/agentos-switch.sh;
  };

  # Tells the panel about a built but unapplied system (package + git diff).
  agentos-pending = pkgs.writeShellApplication {
    name = "agentos-pending";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.jq
      pkgs.nvd
    ];
    text = builtins.readFile ../../agent/agentos-pending.sh;
  };

  # PermissionRequest hook: relays Claude's permission prompts to the panel.
  agentos-approve = pkgs.writeShellApplication {
    name = "agentos-approve";
    runtimeInputs = [
      pkgs.jq
      pkgs.socat
      pkgs.coreutils
    ];
    text = builtins.readFile ../../agent/agentos-approve.sh;
  };

  # Screenshot of the active window for Claude (panel camera button, or a card).
  agentos-screenshot = pkgs.writeShellApplication {
    name = "agentos-screenshot";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.grim
      pkgs.jq
      pkgs.hyprland
      pkgs.quickshell
    ];
    text = builtins.readFile ../../agent/agentos-screenshot.sh;
  };

  agentos-ask = pkgs.writeShellApplication {
    name = "agentos-ask";
    runtimeInputs = [
      pkgs.claude-code
      pkgs.jq
      pkgs.hyprland
      pkgs.coreutils
      agentos-approve
      agentos-screenshot
    ];
    text = builtins.readFile ../../agent/agentos-ask.sh;
  };
in
{
  environment.systemPackages = [
    pkgs.claude-code
    pkgs.nvd
    agentos-ask
    agentos-pending
    agentos-screenshot
    agentos-update
  ];

  # Daily check, weekly update: only on mains power, at low priority. The script
  # skips unless a week has passed or the prepared update is outdated.
  systemd.user.services.agentos-update = {
    description = "Prepare the weekly agentos system update";
    environment.AGENTOS_HOST = vars.host;
    unitConfig.ConditionACPower = true;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${agentos-update}/bin/agentos-update run";
      Nice = 15;
      IOSchedulingClass = "idle";
    };
  };
  systemd.user.timers.agentos-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  # Apply from the panel: `systemctl start agentos-switch@<hash>` (or @rollback).
  # The script validates its argument; polkit below asks your password every time.
  systemd.services."agentos-switch@" = {
    description = "Apply agentos system build %i";
    # Never restart or stop this unit mid-switch because its own definition changed.
    restartIfChanged = false;
    stopIfChanged = false;
    environment.AGENTOS_HOST = vars.host;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${agentos-switch}/bin/agentos-switch %i";
    };
  };

  # Only you may start it, only with your password (no 5-minute "remember me").
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          String(action.lookup("unit")).indexOf("agentos-switch@") == 0) {
        if (subject.user == "${vars.user}" && subject.local && subject.active &&
            action.lookup("verb") == "start")
          return polkit.Result.AUTH_ADMIN;
        return polkit.Result.NO;
      }
    });
  '';

  # `nh os build` = safe build + package diff, `nh os switch` = apply (asks for sudo).
  programs.nh = {
    enable = true;
    flake = vars.flakeDir;
    clean = {
      enable = true;
      extraArgs = "--keep 15 --keep-since 14d";
    };
  };
}

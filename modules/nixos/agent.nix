# The Claude layer. Phase 1 (this file): Claude can read, explain, edit this repo and
# build. Applying changes is always your `nh os switch`.
# See agent/README.md for the later phases.
{ pkgs, vars, ... }:
let
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

  agentos-ask = pkgs.writeShellApplication {
    name = "agentos-ask";
    runtimeInputs = [
      pkgs.claude-code
      pkgs.jq
      pkgs.hyprland
      pkgs.coreutils
      agentos-approve
    ];
    text = builtins.readFile ../../agent/agentos-ask.sh;
  };
in
{
  environment.systemPackages = [
    pkgs.claude-code
    pkgs.nvd
    agentos-ask
  ];

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

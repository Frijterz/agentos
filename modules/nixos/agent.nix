# The Claude layer. Phase 1 (this file): Claude can read and explain, and propose
# changes as edits to this repo. Applying them is always your `nh os switch`.
# See agent/README.md for the later phases.
{ pkgs, vars, ... }:
let
  agentos-ask = pkgs.writeShellApplication {
    name = "agentos-ask";
    runtimeInputs = [
      pkgs.claude-code
      pkgs.jq
      pkgs.hyprland
      pkgs.coreutils
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

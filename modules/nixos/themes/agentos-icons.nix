# UI icons: Lucide line icons (ISC licence), pinned, with a finer stroke (1.5 instead of
# 2) to match the thin lines of the orbit plot and logo, and coloured at build time in
# the Stylix palette. Qt's SVG renderer ignores "currentColor", hence one file per colour:
#   <name>-fg.svg (paper white), <name>-accent.svg (mission orange), <name>-warn.svg (red)
# Usage: import ./agentos-icons.nix { inherit pkgs; colors = config.lib.stylix.colors; }
{ pkgs, colors }:
let
  lucide = pkgs.fetchzip {
    url = "https://registry.npmjs.org/lucide-static/-/lucide-static-1.48.0.tgz";
    hash = "sha256-+Zrx1fSb/sXKJA5LbMmrkVfCeNVqrKn80gQLk+3WPHI=";
  };
  names = [
    "wifi"
    "wifi-high"
    "wifi-low"
    "wifi-zero"
    "wifi-off"
    "bell"
    "bell-dot"
    "bell-off"
    "lock"
    "moon"
    "log-out"
    "rotate-cw"
    "power"
    # System menu
    "bluetooth"
    "bluetooth-off"
    "bluetooth-connected"
    "volume-2"
    "volume-x"
    "mic"
    "mic-off"
    "sun"
    "orbit"
    "battery-low"
    "presentation"
    "focus"
    "chevron-down"
    "chevron-up"
    "x"
    # Calendar and weather (sun and moon are above)
    "chevron-left"
    "chevron-right"
    "cloud"
    "cloud-sun"
    "cloud-moon"
    "cloud-fog"
    "cloud-drizzle"
    "cloud-rain"
    "cloud-snow"
    "cloud-lightning"
    "sunrise"
    "sunset"
    # Launcher, Claude panel, volume pop-up, bar
    "search"
    "calculator"
    "app-window"
    "camera"
    "loader"
    "volume"
    "volume-1"
    "zap"
  ];
in
pkgs.runCommand "agentos-icons" { } ''
  mkdir -p $out
  cp ${lucide}/LICENSE $out/LICENSE-lucide
  for name in ${toString names}; do
    for tone in fg:${colors.base05} accent:${colors.base0D} warn:${colors.base08}; do
      sed -e "s/currentColor/#''${tone##*:}/g" -e 's/stroke-width="2"/stroke-width="1.5"/' \
        ${lucide}/icons/$name.svg > $out/$name-''${tone%%:*}.svg
    done
  done
''

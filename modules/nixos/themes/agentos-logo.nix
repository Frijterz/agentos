# The agentOS logo: a planet with an orbit and a satellite, and the "agentOS" wordmark,
# in the Stylix palette. Rendered from SVG at build time (no binaries in the repo) and
# shared by the boot splash, the wallpaper, the screensaver and the lock screen.
# Usage: import ./agentos-logo.nix { inherit pkgs; colors = config.lib.stylix.colors; }
#   mark.png, word.png, glow.png   1x, for Plymouth
#   mark@2x.png, word@2x.png, glow@2x.png, mark-glow@2x.png   for the 1.25x desktop
{ pkgs, colors }:
let
  hex = base: "#${colors.${base}}";
  fonts = pkgs.nerd-fonts.jetbrains-mono;

  # The orbit's back half is dimmer and hidden behind the planet; its front half passes
  # in front of it. Room around it for the glow.
  markSvg = pkgs.writeText "agentos-mark.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="320" height="320" viewBox="0 0 320 320">
      <g transform="rotate(-20 160 160)" fill="none" stroke="${hex "base0D"}" stroke-width="4">
        <ellipse cx="160" cy="160" rx="118" ry="40" stroke-opacity="0.45"/>
      </g>
      <circle cx="160" cy="160" r="52" fill="${hex "base01"}" stroke="${hex "base0D"}" stroke-width="4"/>
      <ellipse cx="160" cy="160" rx="34" ry="8" fill="none" stroke="${hex "base0D"}" stroke-width="2" stroke-opacity="0.35"/>
      <g transform="rotate(-20 160 160)" fill="none" stroke="${hex "base0D"}" stroke-width="4" stroke-linecap="round">
        <path d="M 42 160 A 118 40 0 0 0 278 160"/>
        <circle cx="256.7" cy="182.9" r="8" fill="${hex "base0D"}" stroke="none"/>
      </g>
    </svg>
  '';

  wordSvg = pkgs.writeText "agentos-word.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="280" height="72" viewBox="0 0 280 72">
      <text x="140" y="52" text-anchor="middle" font-family="JetBrainsMono Nerd Font"
            font-weight="700" font-size="50" letter-spacing="2"><tspan
            fill="${hex "base05"}">agent</tspan><tspan fill="${hex "base0D"}">OS</tspan></text>
    </svg>
  '';
in
pkgs.runCommand "agentos-logo"
  {
    nativeBuildInputs = [
      pkgs.librsvg
      pkgs.imagemagick
    ];
    # The wordmark's font, for rsvg-convert (the build has no fonts otherwise).
    FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ fonts ]; };
  }
  ''
    mkdir -p $out
    cd $out
    cp ${markSvg} mark.svg
    cp ${wordSvg} word.svg
    for scale in 1 2; do
      suffix=""
      [ $scale = 2 ] && suffix="@2x"
      rsvg-convert -z $scale ${markSvg} -o mark$suffix.png
      rsvg-convert -z $scale ${wordSvg} -o word$suffix.png
      # The glow: the mark in solid orange, blurred wide.
      magick mark$suffix.png -fill '${hex "base0D"}' -colorize 100 \
        -channel A -blur 0x$((18 * scale)) -evaluate multiply 1.6 +channel glow$suffix.png
    done
    # Mark with a medium glow baked in, for places that can't animate (lock screen).
    magick glow@2x.png -channel A -evaluate multiply 0.5 +channel mark@2x.png -composite mark-glow@2x.png
  ''

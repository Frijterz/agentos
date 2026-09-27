# UI sounds: a soft sonar ping, inspired by the Quindar tones that opened and closed
# every Apollo-era radio transmission, but lower and rounder (the real 2525 Hz beeps
# sounded like a microwave): a sine with a slow fade, a long echo and a trace of
# band-limited radio static. transmission-in (A4) opens, transmission-out (E4) closes.
# Generated at build time, so the repo holds no audio files.
# Usage: import ./agentos-sounds.nix { inherit pkgs; }
{ pkgs }:
pkgs.runCommand "agentos-sounds" { nativeBuildInputs = [ pkgs.sox ]; } ''
  mkdir -p $out
  R="-r 48000 -c 2 -b 16"
  for v in in:440 out:330; do
    n=''${v%%:*}
    f=''${v##*:}
    # Headroom (vol 0.5) before the echo adds up, so nothing clips.
    sox -n $R ping.wav synth 1.8 sine $f vol 0.5 fade l 0.02 1.8 1.7 echo 0.8 0.7 180 0.3 360 0.15
    sox -n $R static.wav synth 1.8 pinknoise sinc 300-3000 vol 0.02 fade t 0.05 0 0.8
    sox -m ping.wav static.wav $out/transmission-$n.wav reverb 50 norm -18
    rm ping.wav static.wav
  done
''

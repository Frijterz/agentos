# agentos-dictate: record from the microphone until stopped (SIGTERM/SIGINT, e.g. the
# panel's mic button clicked again), then transcribe locally with whisper.cpp and print
# the text. Nothing leaves the laptop. Used by the Claude panel; packaged by
# modules/nixos/agent.nix, which sets AGENTOS_WHISPER_MODEL.

model="${AGENTOS_WHISPER_MODEL:?AGENTOS_WHISPER_MODEL not set}"
wav="$(mktemp --suffix .wav)"
trap 'rm -f "$wav"' EXIT

# 16 kHz mono is what Whisper wants.
pw-record --rate 16000 --channels 1 --format s16 "$wav" &
rec=$!

# On stop: end the recording cleanly (pw-record finishes the WAV header on SIGINT).
stop() { kill -INT "$rec" 2>/dev/null || true; }
trap stop TERM INT
wait "$rec" 2>/dev/null || true
wait "$rec" 2>/dev/null || true # the first wait returns early when the trap runs
trap - TERM INT

# Skip the ~0.5 s start-up pop of the built-in mic, then transcribe (Dutch or English).
# One thread per physical core: with all 16 (SMT) threads it was 8x slower (34 s vs 4 s).
threads=$(($(nproc) / 2))
whisper-cli --model "$model" --file "$wav" --language auto --offset-t 500 \
  --no-timestamps --no-prints --threads "$((threads > 0 ? threads : 1))" 2>/dev/null |
  tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//'

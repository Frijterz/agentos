"""agentos-radio-now: what Claude FM is playing, read off the stream's video.

Claude FM (clau.de/radio, a YouTube live stream) doesn't publish its track list; the
song only appears as a scrolling ticker in the video's top-right corner, "Artist —
Title", monospaced, the repetitions separated by a double space. This reads that
ticker with tesseract and writes {"artist", "title", "updated"} to
$XDG_RUNTIME_DIR/agentos-radio-now.json for the wallpaper (Background.qml).

  agentos-radio-now loop   while the radio plays (agentos-radio starts and stops it):
                           a one-frame check every 30 s (60 s on battery), and a full
                           read of one ticker cycle only when the song changed
  agentos-radio-now once   one full read, printed (for testing)

Best effort: a read that doesn't make sense keeps the previous result.
Gentle, because a burst of downloading and decoding made the radio crackle (Wi-Fi and
Bluetooth share one chip): 480p video, fetched at playback speed (-re) rather than as
fast as possible, one thread each for ffmpeg and tesseract, and home/radio.nix runs it
at idle CPU and I/O priority.
Packaged by home/radio.nix, which puts yt-dlp, ffmpeg and tesseract on PATH.
"""

import json
import os
import re
import subprocess
import sys
import tempfile
import time

URL = "https://clau.de/radio"
OUT = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "agentos-radio-now.json")
# The ticker text, located in a 1280x720 frame (right of the note icon; the 480p video
# is scaled up to that first), enlarged and inverted to dark-on-light, which tesseract
# reads best.
FILTER = "scale=1280:720,crop=290:40:950:26,scale=3*iw:3*ih,negate,format=gray"


def run(cmd, timeout=90):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def stream_url():
    r = run(["yt-dlp", "-f", "bv[height<=480]", "-g", URL])
    return r.stdout.strip().splitlines()[0] if r.returncode == 0 and r.stdout.strip() else None


def frames(url, seconds, folder):
    run(["ffmpeg", "-loglevel", "error", "-y", "-threads", "1", "-re", "-t", str(seconds), "-i", url,
         "-vf", "fps=2," + FILTER, "-threads", "1", os.path.join(folder, "f%03d.png")], timeout=seconds + 60)
    return sorted(os.path.join(folder, f) for f in os.listdir(folder) if f.endswith(".png"))


def read(png):
    """One frame's text, with "|" where the gap between words is a seam (~2 chars)."""
    r = run(["tesseract", png, "-", "--psm", "7", "tsv"], timeout=30)
    words = []
    for line in r.stdout.splitlines()[1:]:
        f = line.split("\t")
        if len(f) == 12 and f[11].strip() and float(f[10]) > 30:
            words.append((int(f[6]), int(f[8]), f[11].strip()))
    if not words:
        return ""
    char = sum(w for _, w, _ in words) / max(1, sum(len(t) for _, _, t in words))
    text = words[0][2]
    for (l0, w0, _), (l1, _, t1) in zip(words, words[1:]):
        text += " | " if l1 - (l0 + w0) > 1.6 * char else " "
        text += t1
    # Characters cut off at the frame edges are guesses: drop two at each end.
    return text[2:-2].strip()


def stitch(parts):
    """Join overlapping fragments of the scrolling text into one string. A fragment that
    doesn't overlap the text so far (a misread) is skipped, not glued on."""
    out = ""
    for p in parts:
        if len(p) < 6:
            continue
        if not out:
            out = p
            continue
        for k in range(min(len(out), len(p)), 4, -1):
            if out.endswith(p[:k]):
                out += p[k:]
                break
    return out


def parse(text):
    """'… | Artist — Title | Artist …' → (artist, title): the whole cycles (between two
    seams) that read the same most often. Only the first dash separates artist and title
    (OCR reads the em dash as "-" at times, and titles have hyphens of their own)."""
    counts = {}
    for seg in text.split("|")[1:-1]:
        parts = re.split(r"\s+[-–—]\s+", seg.strip(), maxsplit=1)
        if len(parts) == 2 and 1 <= len(parts[0]) <= 60 and 1 <= len(parts[1]) <= 120:
            key = (parts[0].strip(), parts[1].strip())
            counts[key] = counts.get(key, 0) + 1
    return max(counts, key=counts.get) if counts else None


def full_read():
    url = stream_url()
    if not url:
        return None
    with tempfile.TemporaryDirectory() as d:
        text = stitch([read(f) for f in frames(url, 16, d)])
    return parse(text), text


def still_same(song):
    """One frame: is its text part of the song we already know?"""
    url = stream_url()
    if not url:
        return True  # can't tell (offline): keep what we have
    with tempfile.TemporaryDirectory() as d:
        shots = frames(url, 1, d)
        frag = read(shots[0]) if shots else ""
    def flat(t):  # dashes and seams don't count: OCR varies on those
        return re.sub(r"[-–—|\s]+", " ", t).strip()

    known = flat(f"{song[0]} {song[1]}")
    return len(flat(frag)) < 6 or flat(frag) in f"{known} {known}"


def write(song):
    data = {"artist": song[0], "title": song[1], "updated": int(time.time())} if song else {}
    with open(OUT + ".tmp", "w") as f:
        json.dump(data, f)
    os.replace(OUT + ".tmp", OUT)


def on_battery():
    try:
        return open("/sys/class/power_supply/AC0/online").read().strip() == "0"
    except OSError:
        return False


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "once"
    if mode == "once":
        result = full_read()
        print(json.dumps({"song": result[0], "text": result[1]} if result else None, ensure_ascii=False))
        return
    song = None
    while True:
        try:
            if song is None or not still_same(song):
                result = full_read()
                if result and result[0]:
                    song = result[0]
                    write(song)
        except (subprocess.TimeoutExpired, OSError, ValueError):
            pass
        time.sleep(60 if on_battery() else 30)


if __name__ == "__main__":
    main()

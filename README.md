# Vunkle

Vunkle is a beat-first video editor.

Instead of editing frames or clips, you edit **beats**. Beats are numbered, reorderable, text-addressable, and musically meaningful. Video and audio are treated as continuous media that are sliced by time only at export.

The core idea is simple:
- Find the beat clock (manually or visually)
- Decide where beat **1** is (anywhere, including negative beats)
- Arrange beats as numbers
- Export once, at full quality

The truth of an edit always exists in plain text.

---

## Core principles

- Beat-first: you move beats, not pixels
- Text-first: every edit round-trips through `.vunkle.txt`
- Lightweight editing: no re-encoding during edit
- Export-only quality: quality matters only at final render
- Musically honest: phase, tempo, and count are explicit
- Explainable: no hidden state, no magic automation

The design is heavily inspired by early Sonic Foundry ACID (v2–v4), especially its loop-alignment walkthroughs and direct manipulation model.

---

## Repository layout

```
vunkle/
├─ core/                 # Swift Package (VunkleCore)
│  ├─ Sources/
│  │  └─ VunkleCore/     # Parsers, solvers, timing, media logic
│  ├─ Sources/
│  │  └─ VunkleExportCLI/   # vunkle-export (CLI)
│  └─ Sources/
│     └─ VunkleDetectGridCLI/ # vunkle-detect-grid (CLI)
│
├─ ios/                  # iOS app (SwiftUI)
│
└─ README.md
```

VunkleCore contains all logic that must be correct, testable, and reusable. UI is a thin projection of the text model.

---

## The `.vunkle.txt` file format

Plain text. Order-insensitive. Human-editable. Diff-friendly.

### Minimal example

```text
video: secret-world.mp4
downbeat: 12.432
bpm: 119.98

export:
  1  2  3  4
  3  2  1
```

### Anchors (timing truth)

```text
# absolute anchor (locks tempo locally)
anchor:
  17 8.015

# relative anchor (phase nudge only)
anchor:
  32 +0.004
```

Rules:
- Absolute anchors affect tempo interpolation
- Relative anchors only shift phase
- Negative beat numbers are valid

---

## Beat numbering

Beat **1** does not need to occur at the start of the video.

It is valid (and common) for beat numbering to look like:

```text
anchor:
  -15 12.432
```

This means the musical downbeat occurs later in the video. Earlier beats exist and are addressable.

---

## CLI tools

### Web UI (WebSocket frontend)

All CLI tools can optionally expose a **WebSocket-driven web UI** that mirrors the iOS frontend.

Starting any CLI with `--web` launches a local server and prints (or opens) a browser link:

```bash
vunkle-export edit.vunkle.txt --web
vunkle-format edit.vunkle.txt --web
```

Behavior:
- Starts a local HTTP + WebSocket server
- Prints a URL to the terminal
- Optionally auto-opens the browser
- Serves a lightweight web app that mirrors the iOS editor

The web UI is a **thin client**:
- All semantics live in `VunkleCore`
- Browser communicates via WebSocket messages
- Same commands, same state model, same text output

This enables full Vunkle editing on **macOS, Windows, and Linux** with no native UI dependencies.



All command‑line tools are designed to run on **macOS, Linux, and Windows** using the same core logic as the iOS app. The iOS app and the Web UI are thin frontends over this core; neither introduces new semantics.


### `vunkle-export`

Slices and renders a new video from a `.vunkle.txt` file.

```bash
swift run vunkle-export edit.vunkle.txt
```

- Uses AVFoundation lazily
- Time-based slicing only (VFR-safe)
- Audio crossfades supported
- Video crossfades optional

Output:
```
<video>.vunkle.out.mp4
```

---

### `vunkle-format`

Formats a `.vunkle.txt` file for **human readability** while preserving meaning.

```bash
vunkle-format edit.vunkle.txt            # print to stdout
vunkle-format edit.vunkle.txt -i         # format in place
```

Features:
- Column‑aligned numbers (including negatives and zero‑padding)
- Stable ordering of sections
- Preserves comments and blank lines
- No semantic changes

Example alignment:

```text
export:
  -16  -8  -4  -2  -1   0   1   2
   10  11  12  13  14  15  16  17
```

This formatter is intended to be used frequently, like `gofmt` or `rustfmt`.

---

### `vunkle-detect-grid`

Detects a 4×4 visual beat grid embedded in a video (e.g. Midigarden screen recordings).

```bash
swift run vunkle-detect-grid video.mp4 --emit-vunkle --debug
```

Produces:
- Estimated BPM
- Suggested anchors
- Debug PNGs showing grid alignment
- Optional `.vunkle.txt` skeleton

Detection is opportunistic and gap-tolerant. No automation is forced.

---

## Beat alignment walkthrough

An interactive alignment mode inspired by early ACID:

- Comic-strip view of grid dot transitions
- Frame/sample-level phase nudging
- Beat count chooser (decide where “1” is)
- Loop audition with adjustable metronome
- Zoomed waveform at beat boundaries

This walkthrough exists to build confidence, not to hide complexity.

---

## Multivunks (composing vunkles)

### Multivunk text schema (draft)

Multivunks extend the text‑first model. A multivunk file references multiple vunkles and defines how their beat clocks relate.

```text
# multivunk.vunkle.txt

output:
  bpm: 120

sources:
  - id: drums
    file: drums.vunkle.txt
    mode: follow-master        # follow-master | follow-source | fixed-bpm
    pitch:
      semitones: 0
      cents: 0

  - id: bass
    file: bass.vunkle.txt
    mode: fixed-bpm
    bpm: 120
    pitch:
      semitones: -12
      cents: 0

  - id: pads
    file: pads.vunkle.txt
    mode: follow-source

# optional timeline tempo changes
bpm-change:
  33 128
  65 110

# arrangement is still beat-first
export:
  drums:  1 2 3 4 5 6 7 8
  bass:   1 1 2 2 3 3 4 4
  pads:   -7 -6 -5 -4 -3 -2 -1 0
```

Notes:
- Each source keeps its own anchors internally.
- The multivunk layer only declares **relationships** between clocks.
- All transforms are explicit and reversible.


Vunkle supports **multivunks**: compositions made from multiple already‑vunkled videos.

A multivunk treats each source vunkle as a **beat‑aware block** that can be tuned, aligned, and arranged together.

### Tempo relationship modes

Each source vunkle can operate in one of these modes:

- **Follow source**: keep the original vunkle’s BPM and beat timing.
- **Follow master**: conform to a designated master vunkle’s BPM.
- **Fixed output BPM**: all sources conform to a specified output BPM.
- **Timeline BPM changes**: explicit BPM changes at given beats in the multivunk timeline.

All modes are explicit and text‑representable.

### Time and pitch handling

When conforming tempos, a source vunkle can choose:

- **Repitch only**: change playback speed with no time‑stretch algorithm.
- **Time/pitch stretch**: use a selected stretch algorithm with controls for:
  - semitone offset (±)
  - cent offset (±)

These choices are per‑source and reversible.

### Editing performance

To keep editing lightweight:

- High‑quality audio/video processing happens **only at export**.
- During editing, sources use:
  - cached audio previews
  - low‑resolution visual thumbnails

Once a time‑stretch or repitch mode is chosen, **smart caching and preloading** ensure blocks can be assembled and auditioned with no lag.

### Beat‑synchronous thumbnails

Visual editing uses beat‑synchronous thumbnails instead of full video:

- Thumbnails are sampled exactly on beat boundaries.
- Typical density: **4 thumbnails per beat**.
- Resolution is intentionally tiny:
  - 1/8, 1/16, or 1/32 of source resolution
- Thumbnails may use aesthetic reduced‑palette formats:
  - 2‑tone, 4‑tone, or 16‑tone
  - dithered for character

For efficiency, thumbnails may be packed into **sprite sheets** instead of individual files.

These thumbnails exist only to provide orientation while arranging beats; they are not previews of final quality.

---

## What Vunkle is NOT

- Not a traditional NLE
- Not a clip-based editor
- Not a real-time effects tool
- Not trying to replace a DAW

Vunkle is intentionally narrow.

---

## Status

Early but real. The core exporter and detector exist; UI is being built directly on top of the text model.

---

## For future agents

- Prefer boring, explicit solutions
- Do not hide state in UI
- If it cannot round-trip through text, it is suspect
- Optimize for musical correctness over visual cleverness

When in doubt: make it readable, not smart.

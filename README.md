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

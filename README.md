# revunk

revunk is a beat-first video editor.

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
- Text-first: every edit round-trips through `.revunk.txt`
- Lightweight editing: no re-encoding during edit
- Export-only quality: quality matters only at final render
- Musically honest: phase, tempo, and count are explicit
- Explainable: no hidden state, no magic automation

The design is heavily inspired by early Sonic Foundry ACID (v2–v4), especially its loop-alignment walkthroughs and direct manipulation model.

---

## Repository layout

```
revunk/
├─ core/                 # Swift Package (revunkCore)
│  ├─ Sources/
│  │  └─ revunkCore/     # Parsers, solvers, timing, media logic
│  ├─ Sources/
│  │  └─ revunkExportCLI/   # revunk-export (CLI)
│  └─ Sources/
│     └─ revunkDetectGridCLI/ # revunk-detect-grid (CLI)
│
├─ ios/                  # iOS app (SwiftUI)
│
└─ README.md
```

revunkCore contains all logic that must be correct, testable, and reusable. UI is a thin projection of the text model.

---

## The `.revunk.txt` file format

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

## CLI design: one binary

revunk intentionally ships as **one beautiful monolith**.

There is a single executable:

```bash
revunk
```

All functionality is accessed through **subcommands and flags**, not separate binaries.

This keeps the mental model simple, avoids semantic drift, and guarantees that every mode of operation uses the exact same engine and text model.

### Examples

```bash
revunk export edit.revunk.txt
revunk open output.revunk.out.mp4
revunk format edit.revunk.txt
revunk detect-grid video.mp4
revunk play edit.revunk.txt
```

Flags modify behavior rather than selecting a different tool:

```bash
revunk export edit.revunk.txt --ascii
revunk export edit.revunk.txt --ascii-player
revunk export edit.revunk.txt --embed thumbnails
```

The only exception to this rule is **exported artifacts** that are themselves executable (for example, demoscene-style ASCII media players). Those are *outputs*, not tools.

---

## Web UI (WebSocket frontend)

All revunk commands can optionally expose a **WebSocket-driven web UI** that mirrors the iOS frontend.

Starting any CLI with `--web` launches a local server and prints (or opens) a browser link:

```bash
revunk-export edit.revunk.txt --web
revunk-format edit.revunk.txt --web
```

Behavior:
- Starts a local HTTP + WebSocket server
- Prints a URL to the terminal
- Optionally auto-opens the browser
- Serves a lightweight web app that mirrors the iOS editor

The web UI is a **thin client**:
- All semantics live in `revunkCore`
- Browser communicates via WebSocket messages
- Same commands, same state model, same text output

This enables full revunk editing on **macOS, Windows, and Linux** with no native UI dependencies.



All command‑line tools are designed to run on **macOS, Linux, and Windows** using the same core logic as the iOS app. The iOS app and the Web UI are thin frontends over this core; neither introduces new semantics.


### `revunk-export`

Slices and renders a new video from a `.revunk.txt` file.

```bash
swift run revunk-export edit.revunk.txt
```

- Uses AVFoundation lazily
- Time-based slicing only (VFR-safe)
- Audio crossfades supported
- Video crossfades optional

Output:
```
<video>.revunk.out.mp4
```

---

### `revunk-format`

Formats a `.revunk.txt` file for **human readability** while preserving meaning.

```bash
revunk-format edit.revunk.txt            # print to stdout
revunk-format edit.revunk.txt -i         # format in place
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

### `revunk-detect-grid`

Detects a 4×4 visual beat grid embedded in a video (e.g. Midigarden screen recordings).

```bash
swift run revunk-detect-grid video.mp4 --emit-revunk --debug
```

Produces:
- Estimated BPM
- Suggested anchors
- Debug PNGs showing grid alignment
- Optional `.revunk.txt` skeleton

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

## Multirevunks (composing revunks)

### Multirevunk text schema (draft)

Multirevunks extend the text‑first model. A multirevunk file references multiple revunks and defines how their beat clocks relate.

```text
# multirevunk.revunk.txt

output:
  bpm: 120

sources:
  - id: drums
    file: drums.revunk.txt
    mode: follow-master        # follow-master | follow-source | fixed-bpm
    pitch:
      semitones: 0
      cents: 0

  - id: bass
    file: bass.revunk.txt
    mode: fixed-bpm
    bpm: 120
    pitch:
      semitones: -12
      cents: 0

  - id: pads
    file: pads.revunk.txt
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
- The multirevunk layer only declares **relationships** between clocks.
- All transforms are explicit and reversible.


revunk supports **multirevunks**: compositions made from multiple already‑revunkd videos.

A multirevunk treats each source revunk as a **beat‑aware block** that can be tuned, aligned, and arranged together.

### Tempo relationship modes

Each source revunk can operate in one of these modes:

- **Follow source**: keep the original revunk’s BPM and beat timing.
- **Follow master**: conform to a designated master revunk’s BPM.
- **Fixed output BPM**: all sources conform to a specified output BPM.
- **Timeline BPM changes**: explicit BPM changes at given beats in the multirevunk timeline.

All modes are explicit and text‑representable.

### Time and pitch handling

When conforming tempos, a source revunk can choose:

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

---

---

## Terminal (TUI) + ASCII video frontend

revunk includes an optional **cross‑platform terminal UI (TUI)** that renders video at extremely low resolution using **ASCII / character‑based graphics**, while still using the *exact same backend* as all other frontends.

This mode is both practical and aesthetic, inspired by demoscene players and ASCII video art.

### Goals

- One binary: `revunk`
- Same engine, different presentation
- No special casing in core logic
- Beautiful constraints‑driven visuals

---

### ASCII render modes

The TUI supports multiple render modes:

- **Live terminal playback**
  - Real‑time ASCII video in terminal
  - Synchronized audio playback
  - Keyboard controls (play / pause / seek)

- **ASCII demo export**
  - Self‑contained terminal player (text + audio)
  - Intended to be run directly in a terminal
  - Inspired by demoscene intros

- **ASCII‑to‑video export**
  - Renders the ASCII frames to a standard video file (e.g. MP4)
  - Compatible with iOS, web, and social sharing
  - Preserves the ASCII aesthetic

All modes share the same renderer.

---

### ASCII rendering approach

- Video is downsampled aggressively (e.g. 80×45, 120×68)
- Each cell maps to a character based on:
  - luminance
  - optional color
- Character sets are selectable:
  - ` .:-=+*#%@`
  - block elements
  - custom fonts

Optional enhancements:
- Temporal dithering
- Ordered dithering
- Reduced palettes

---

### Audio support

- Audio playback remains full quality
- Audio timing drives video frame pacing
- The TUI renderer never alters timing

---

### Exporting ASCII video

Any frontend (CLI, Web, iOS, macOS) can export:

- Terminal‑playable ASCII demo
- ASCII frames as text files
- ASCII video rendered to MP4

This makes the ASCII mode a *first‑class output format*, not a gimmick.

---

### Architecture

- ASCII rendering is a **frontend layer only**
- Core produces time‑addressable frames
- Renderer maps frames → characters
- Same shader system can be applied *before* ASCII mapping

---

### CLI usage (examples)

```bash
revunk play edit.revunk.txt --tui
revunk export edit.revunk.txt --ascii
revunk export edit.revunk.txt --ascii-video
```

---

## Lightweight shader system

revunk supports an **optional, lightweight shader system** layered on top of the beat timeline.

Shaders are:
- **Purely visual** (audio is unaffected)
- **Optional** (default is no shader)
- **Applied per‑beat, per‑range, or globally**
- **Text‑addressable and shareable**

The goal is not full compositing, but fast, expressive *looks*, similar in spirit to apps like **Hyperspektiv**.

### Shader philosophy

- Shaders are small, readable, and copy‑pasteable
- They live in **plain text files**
- They can be shared on the web
- They are deterministic and side‑effect free
- They never affect timing or beat math

### Universal shader format

revunk uses a **GLSL‑style fragment shader format**, compatible in spirit with ShaderToy‑style sharing sites.

Example shader file:

```glsl
// glitch-wobble.revunk.glsl

uniform float time;
uniform vec2 resolution;
uniform sampler2D inputImage;

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    uv.x += sin(uv.y * 40.0 + time) * 0.01;
    gl_FragColor = texture2D(inputImage, uv);
}
```

### Referencing shaders in `.revunk.txt`

Shaders are referenced by path and optionally parameterized:

```text
shader:
  file: shaders/glitch-wobble.revunk.glsl
  apply: beats 33..64
  params:
    intensity 0.8
```

Rules:
- If no `shader:` block exists, video is unmodified
- Shaders can be stacked (order is explicit)
- Shaders never affect export timing

### Timeline interaction

- Shaders behave like **visual modifiers**, not clips
- They can be copied and pasted like beats
- They snap to beat ranges
- They are previewed at low resolution during editing
- Full quality is applied only at export

### Performance strategy

- Editing uses:
  - low‑resolution frames
  - cached shader outputs
- Export renders:
  - full resolution
  - full precision

This keeps the editor responsive while allowing rich looks.

### Frontend support

- CLI: shaders are declared and referenced textually
- Web: shaders editable in a text panel
- iOS/macOS: shader picker + live preview

All frontends use the same shader code and parameters.

---

---

## Re‑revunklable exports (configurable embedding & quines)

Every revunk export is **metadata‑complete and re‑revunklable**.

This means:
- **Source media is not embedded** in the export
- A full project description is embedded as metadata
- The export contains enough information to *re‑discover* the original sources

Exports remain lightweight while still enabling recovery and remixing.

---

### Embedding modes

Each export bundles:

revunk supports multiple **source embedding modes**, selectable per export:

1. **None (default)**
   - Only metadata is embedded
   - Source discovery is used on reopen

2. **Thumbnails only**
   - Beat‑synchronous low‑resolution frames
   - Optimized for remixing and browsing

3. **Low‑resolution video**
   - Downsampled, time‑aligned video
   - Flows back into editing stream

4. **Full‑quality video**
   - Exact source copy embedded
   - Maximum portability

Audio is always embedded at **full quality**.

Embedded or referenced sources always include:
- Original file names
- File sizes
- Content hashes
- Expected durations
- Any offsets or trims used

2. **Project revunk metadata**
   - The exact `.revunk.txt` used
   - Derived settings (BPM, anchors, grid calibration)
   - Multirevunk relationships (if any)

3. **Export descriptor (metadata revunk)**
   - Describes how this output should be re‑revunkd
   - Allows instant reopening with correct defaults

---

### Metadata revunk (source‑referencing)

Every export contains an embedded **metadata revunk**, conceptually equivalent to:

```text
# export-metadata.revunk.txt

exported-from: revunk
engine-version: 0.x

reopen:
  mode: edit
  timeline: main

sources:
  - embedded: true
    original-name: secret-world.mp4

suggested-actions:
  - remix
  - retime
  - restyle
```

This file is not meant for manual editing, but it is **plain text and inspectable**.

---

### Container & quine strategy

Exports use a **container and quine strategy** appropriate to the output format:

- **MP4 / video outputs**
  - Embedded assets stored as additional tracks or metadata atoms
  - Metadata revunk stored as a text atom

- **ASCII demo exports**
  - The output is itself the `revunk` executable
  - When run normally: plays ASCII video + audio
  - When run with `--remix`: opens the embedded project for editing
  - Sources may be embedded in any supported mode (including ASCII)

- **Executable quines**
  - Certain export formats may be true quines
  - Renaming the file preserves remixability
  - `revunk --help` reports quine support on the current platform

- **Web / bundle exports**
  - Directory or archive layout

The exact container format is abstracted by the engine.

---

### Reopening, remixing, and auto‑revunking

When opening an exported artifact:

1. revunk reads the embedded metadata revunk
2. Determines embedding mode(s)
3. Uses embedded sources and/or source discovery
4. Restores the project instantly

---

### Auto‑revunk compression

revunk can automatically compress long recordings into shorter, beat‑faithful edits.

Options include:

- Source start / end crop (approximate)
- Target duration (e.g. 3 minutes)
- Minimum stride length (in beats)

The engine generates an **auto‑revunk script** that skips through the source while preserving beat structure.

Example (conceptual):

```text
# auto-generated
export:
  1
  2 +4
  3 +8
  4 +12
```

This is intended for:
- Long jams
- Platform upload limits
- Rapid sharing

The generated script is fully editable.


No manual relinking is required.

---

### Philosophy

An export is not just a render.

It is a **shareable, remixable object**.

revunk exports are:
- playable
- inspectable
- recoverable
- remixable

---

## What revunk is NOT

- Not a traditional NLE
- Not a clip-based editor
- Not a real-time effects tool
- Not trying to replace a DAW

revunk is intentionally narrow.

---

## Lore

The name **revunk** (and by extension **revunk**) comes from the Endlesss.fm community.

**"wuncle"** was a term coined by Endlesss.fm designer and user **Noel Leeman** as a playful pun on **"one‑cel"** ("re‑one a loop"). In Endlesss, a loop can easily start on the wrong beat or phase, and collaborators would say a loop needed to be **re‑oned** — aligned so that beat **1** lands correctly.

Over time, *wuncle* became a humorous shorthand for fixing phase, count, or musical alignment — especially when exporting audio from Endlesss and correcting where the loop truly begins.

**revunk** is a direct extension of that idea: the **V is for video**.

The philosophy carries forward unchanged:
- find where *one* really is
- make alignment explicit
- treat timing as musical truth, not metadata

revunk exists to do for video what "wuncle" did for loops: make re‑oning intentional, explicit, and shareable.

---

## Recursive revunk (a core property)

A defining goal of **revunk** is **recursive applicability**:

> **Every revunk output is itself a valid revunk input.**

Any artifact produced by revunk — video, ASCII demo, executable player, or future formats — must be *revunkable again*.

This means:
- Exports are never dead ends
- Timing, structure, and intent are preserved
- A revunk can be re‑revunked indefinitely

Conceptually, revunk should be able to **revunk itself**:
- a revunk export can be opened
- edited
- re‑exported
- and reopened again

This recursive property is not an accident or a convenience; it is a design constraint.

It is why:
- text is the source of truth
- metadata is explicit and inspectable
- exports remain explainable
- no hidden state is allowed

revunk is not just an editor — it is a *closure over its own outputs*.

---

## Status

revunk is an active, working engine with **real exports** and a complete round‑trip pipeline:

`parse → solve → render → export → reopen`

Implemented today:
- Beat‑first text format (`.revunk.txt`)
- Arbitrary beat sequencing (including reverse)
- Anchor‑aware timing
- Constant offset / nudge support
- Tempo changes
- Audio crossfades
- Beat number burn‑in (debug overlay)
- Metadata sidecars (`.metadata.revunk.txt`)
- Fingerprint‑based source rediscovery on reopen

This repository should be treated as:
- a **format** (the `.revunk.txt` language)
- an **engine** (revunkCore)
- a **toolchain** (CLI / Web / TUI / iOS / macOS)

Design sections in this README are not aspirational; they describe behavior that either already exists or is actively being implemented.

Early but real. The exporter produces real MP4s, and every export can be reopened and remixed from text.

---

## For future agents

If you are extending revunk:

- Preserve **one binary** (`revunk`)
- Preserve **text-first truth**
- Do not duplicate semantics in frontends
- Keep exports re‑revunklable
- Prefer adding new output modes over new internal state

If a feature cannot round‑trip through text, metadata, and export, it is likely wrong.


- Prefer boring, explicit solutions
- Do not hide state in UI
- If it cannot round-trip through text, it is suspect
- Optimize for musical correctness over visual cleverness

When in doubt: make it readable, not smart.

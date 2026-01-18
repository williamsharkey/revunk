# AGENTS.md — revunk Continuation Guide

This document captures **everything an agent needs to know** to continue work on the revunk exporter, specifically the long‑running effort to implement **explicit video crossfades** using AVFoundation.

It is written to avoid rediscovery of dead ends and to preserve the hard‑won invariants uncovered during debugging.

---

## Project Context

**revunk** is a beat‑first, text‑first video remix engine.

Core principles:
- Text is the source of truth
- Explicit semantics only (no inference)
- Recursive revunk property: every output is a valid input
- Crossfades are explicit (`1x2`), never implicit

The CLI binary is `revunk`. Core logic lives in `core/Sources/VunkleCore/`.

---

## File of Interest

All work described here concerns:

```
core/Sources/VunkleCore/RevunkExporter.swift
```

This file has been **fully rewritten** multiple times during debugging. The current version reflects the *most correct model attempted so far*, but AVFoundation still rejects it.

---

## Deterministic Test Harness (CRITICAL)

To eliminate subjectivity, a deterministic test was built.

### Test assets

```
test_assets/generate_test_video.sh
```

Produces `revunk-test-pattern.mp4`:
- 8 seconds total
- Each second = solid color
  - red → green → blue → yellow → magenta → cyan → white → black
- Burned‑in index + timecode

### Test runner

```
blocks-test.sh
```

What it does:
1. Generates the test video
2. Writes a test `.revunk.txt`
3. Runs `revunk export`
4. Opens the output video **only if export succeeds**

If crossfades work, blended colors must be visible (e.g. red+green ≈ yellow).

---

## Crossfade Syntax

In revunk text:

```
export:
  1x2 2x3 3x4 4x5
```

Meaning:
- `1x2` = explicit video crossfade from beat 1 into beat 2
- Crossfades are **opt‑in**
- Audio and video are separate concerns

---

## What Was Proven (Do NOT Re‑try These)

During debugging, the following were all implemented correctly and **are not the cause of failure**:

- Frame‑native timing (no seconds lattice)
- Instruction splitting into:
  - outgoing only
  - crossfade window
  - incoming tail
- Instruction sorting by timeRange.start
- No overlapping or gapped instruction ranges
- Applying `preferredTransform` to every layer instruction
- Audio removed as a factor (`--no-audio` still fails)
- Deterministic reproduction of failure

If an agent re‑introduces any of the above as a “fix”, they are going backward.

---

## The Final Failure Mode

Even after all logical invariants were satisfied, AVFoundation consistently fails with:

```
AVFoundationErrorDomain Code=-11841
"The video could not be composed."
```

Key properties of this failure:
- Happens **before** video composition instructions are consumed
- No instruction logging prints
- Indicates **composition track validation failure**, not instruction failure

---

## Root Cause (Framework Constraint)

The remaining blocker is **not a logic bug**, but an AVFoundation constraint:

> **AVMutableComposition does not accept certain overlapping multi‑track graphs, even if instructions are valid.**

Specifically:
- Alternating ownership between two video tracks
- Inserting overlapping segments at final destination times
- Relying on opacity ramps to legalize the overlap

This model is *conceptually correct* but **rejected by AVFoundation**.

This was confirmed after:
- Switching from modulo track selection → ownership‑based swapping
- Ensuring strictly monotonic destination time per track
- Ensuring single contiguous insert per beat

The framework still rejects the graph.

---

## Important Insight

All Apple‑working crossfade examples do **one of the following**:

1. Maintain a **single baseline video track** covering the entire timeline
   - Other tracks fade *on top* of it
2. Use `AVVideoCompositionCoreAnimationTool`
3. Pre‑flatten segments before final composition

revunk attempted a cleaner symmetric model (two equal tracks alternating ownership). **AVFoundation does not support this**, even though it is theoretically valid.

---

## The Last Implemented Model (Current State)

The current exporter implements:
- Frame‑based timing (`fps = 30`)
- Explicit track ownership (`activeTrack` / `inactiveTrack`)
- Single contiguous insert per beat
- Sorted, contiguous instructions

This is the *best possible implementation of that model*, and it still fails.

Therefore:

> **Continuing within this model is futile.**

---

## Recommended Paths Forward

Any future agent should choose **one** of these paths deliberately.

### Path A — Baseline Track Model (Most Likely)

- Create a single base video track covering the full duration
- Insert every beat contiguously into it
- Use a second track *only* during crossfade windows
- Fade second track over the base

This matches Apple’s internal expectations.

### Path B — Pre‑flatten Beats

- Render each beat (or beat pair) into temporary assets
- Crossfade assets, not source ranges
- Heavier, but guaranteed to work

### Path C — CoreAnimation Compositor

- Use `AVVideoCompositionCoreAnimationTool`
- Let CoreAnimation handle blending
- More complexity, but Apple‑blessed

---

## Explicit Do‑Not‑Dos

Future agents should **not**:
- Re‑introduce modulo‑based track selection
- Attempt more instruction math tweaks
- Re‑introduce seconds‑based timing
- Add implicit smoothing or heuristics
- Assume opacity=0 excuses missing samples

All of these were tested and ruled out.

---

## Why This Matters

This investigation uncovered **every major AVFoundation footgun** related to crossfades:
- Instruction coverage
- Track coverage
- Frame lattice alignment
- Transform application
- Track monotonicity
- Instruction ordering

Any continuation now starts with a **complete map of the terrain**.

---

## Status Summary

- ✅ Deterministic test harness exists
- ✅ Parser semantics correct
- ✅ Exporter logic deeply explored
- ❌ AVFoundation rejects symmetric multi‑track crossfade model
- 🔜 Must change composition strategy

---

If you are reading this as a new agent: **do not feel behind**. You are starting from a position of hard‑won clarity.

# Revunk macOS App

This is the macOS app target for **Revunk**.

The macOS app is a thin SwiftUI wrapper around the same engine used by:
- the `revunk` CLI
- the WebSocket web UI
- the iOS app

## Principles

- No new semantics live here
- All edits round-trip through `.revunk.txt`
- The app embeds the `revunk` engine directly
- Web, CLI, and macOS behave identically

## Intended behavior

- Open `.revunk.txt` files
- Open video files and auto-generate revunks
- Full Beat Alignment Walkthrough UI
- ACID-style beat grid editor
- Export using the same pipeline as CLI

## Status

This target is currently a scaffold.
It exists to ensure macOS is a first-class citizen alongside CLI, Web, and iOS.

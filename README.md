# Open Pac the Man

An open-source, Godot-based remake/source-port-style recreation of Pac the Man X.

This repository contains engine code, tests, and import logic only. It does not contain
the original game binary, original artwork, original sounds, original music, or original
levels. Like other open-source game reimplementations, you provide original game data
from a copy you are allowed to use, and the remake loads that data at runtime.

Current state: initial alpha. The core game loop, original level import, maze rendering,
sprites, sounds, music, scoring, high scores, simultaneous multiplayer, two-handed mode,
extras, difficulty modes, and Master spotlight behavior are implemented enough for
playtesting. Fidelity work is still ongoing.

## Requirements

- Godot 4.7 for development.
- A local copy of the original Pac the Man X data.

Verified original data source:

- `pacx151a.zip` — Pac the Man X 1.5.1a Cocoa release.

Supported loader inputs:

- A ZIP file containing the original `.app` bundle.
- An unpacked `.app` bundle directory, for example `Pac the Man X.app`.

Not yet verified:

- Pre-Cocoa releases. The loader can inspect ZIPs and `.app` directories, but those
  versions may use different executable/resource layouts. See
  [docs/original-data.md](docs/original-data.md).

## Running from source

Clone the repo, then put original data in one of these locations:

```text
original/pacx151a.zip
original/Pac the Man X.app/
```

`original/` is ignored by git. Do not commit original game data.
If your ZIP extracts to a parent folder such as `Pac the Man X/Pac the Man X.app`,
copy or move the inner `.app` bundle to `original/Pac the Man X.app`.

Run with Godot:

```bash
godot --path . -- --archive=original/pacx151a.zip
```

Or let the game find the default location:

```bash
godot --path .
```

On Windows, `play.cmd` searches these paths in order:

1. `original/pacx151a.zip`
2. `original/Pac the Man X.app`
3. `../clone/pacx151a.zip` as a local development fallback

You can also pass any explicit source:

```bash
godot --path . -- "--archive=C:/Games/Pac the Man X.app"
```

Useful runtime flags:

```text
--mode=solo|simultaneous|two_handed
--players=1|2|3|4
--level-pack=x|standard
--level=0
--difficulty=easy|normal|hard|master
--archive=/path/to/pacx151a.zip
```

## Testing

Run the code-only test suite:

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

Run the full local import/fidelity checks against original data:

```bash
godot --headless --path . --script res://tests/run_tests.gd -- --archive=original/pacx151a.zip
```

The archive-aware tests inspect required resources, parse imported levels, validate
the maze subtile adjacency model across original levels, decode recovered raw sprite
formats, and decode representative audio.

## Builds

GitHub Actions exports alpha artifacts for:

- Windows x86_64
- Linux x86_64
- macOS universal

Release artifacts intentionally do not bundle original game data. After downloading an
artifact, run it with `--archive=/path/to/original-data` or place original data beside
your working copy while developing from source.

Local exports use the checked-in Godot export presets:

```bash
mkdir -p dist/windows dist/linux dist/macos
godot --headless --path . --export-release "Windows Desktop" dist/windows/OpenPacTheMan.exe
godot --headless --path . --export-release "Linux/X11" dist/linux/OpenPacTheMan.x86_64
godot --headless --path . --export-release "macOS" dist/macos/OpenPacTheMan.zip
```

You must install Godot 4.7 export templates before local exporting.

## Project layout

```text
src/core/          deterministic gameplay rules and data structures
src/import/        original ZIP/.app, plist, raw sprite, and audio importers
src/presentation/  Godot rendering helpers and sprite layout code
src/app/           Godot scene adapter, HUD, audio, menus, and runtime wiring
tests/             headless regression tests
docs/              architecture notes, reverse-engineering notes, handoff docs
```

## Legal status

This project is an independent reimplementation/remake effort. It does not distribute
original Pac the Man X assets or binaries. To use the remake with original data, you are
responsible for supplying a copy you are legally allowed to use.

The remake code is licensed under the MIT License. Original game assets remain owned by
their respective rightsholders and are not covered by this repository's license.

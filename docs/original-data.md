# Original data handling

This project follows the usual source-port/reimplementation pattern: code is open source,
but original game data is supplied by the user at runtime.

## Local placement

Preferred development layout:

```text
remake/
  original/
    pacx151a.zip
```

Alternative unpacked layout:

```text
remake/
  original/
    Pac the Man X.app/
      Contents/
        MacOS/
        Resources/
```

`original/` is ignored by git and must remain local.

The runtime search order is:

1. `--archive=/explicit/path` if provided.
2. `original/pacx151a.zip`
3. `original/Pac the Man X.app`
4. `../clone/pacx151a.zip` for this workspace's existing development setup.

Despite the flag name, `--archive=` accepts either a ZIP file or an unpacked `.app`
directory.

## Verified version matrix

| Version/source | Format tested | Status | Notes |
| --- | --- | --- | --- |
| Pac the Man X 1.5.1a | ZIP containing Cocoa `.app` | Verified | Current primary source: `pacx151a.zip`. |
| Pac the Man X 1.5.1a | Unpacked Cocoa `.app` | Loader supported, not locally verified | Same expected resource suffixes as the ZIP. |
| Pre-Cocoa versions | ZIP or app/folder | Not yet verified | May use different executable names, resource paths, file formats, or level locations. |

## Required resource suffixes

The current importer validates these canonical Cocoa-layout suffixes:

```text
/Contents/MacOS/Pac the Man X
/Contents/Resources/Levels/The X Levels.plist
/Contents/Resources/Sprites/player1.raw
/Contents/Resources/Sprites/points.raw
```

Gameplay currently also expects resources such as:

```text
/Contents/Resources/Pac the Man X Editor.app/Contents/Resources/Levels.plist
/Contents/Resources/Backgrounds/*.png
/Contents/Resources/Sprites/*.raw
/Contents/Resources/Sounds/*.wav
/Contents/Resources/Music/*.mp3
```

If a pre-Cocoa release fails inspection, the next step is to add a second layout profile
rather than special-case individual reads throughout the game.

## Compatibility test commands

Code-only tests:

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

Inspect and test a ZIP:

```bash
godot --headless --path . --script res://tests/run_tests.gd -- --archive=original/pacx151a.zip
```

Inspect and test an unpacked app:

```bash
godot --headless --path . --script res://tests/run_tests.gd -- "--archive=original/Pac the Man X.app"
```

For any newly found version, capture:

- exact filename/source version,
- SHA-256 from the test output,
- `kind` (`zip` or `directory`),
- missing required suffixes if any,
- whether X levels, Standard levels, sprites, and audio decode.

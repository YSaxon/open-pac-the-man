# Maze Engine

Working repository for an independent, cross-platform reimplementation of Pac the Man X.

The repository contains only newly written code. Original executables, levels, graphics,
music, sounds, and other copyrighted resources must not be committed. During development,
tools read a user-supplied original archive such as `pacx151a.zip`.

## Development

Requires Godot 4.7 or newer.

On Windows, double-click `play.cmd`. It opens the original title artwork and a mode menu,
locates the Scoop Godot installation, and loads `../clone/pacx151a.zip` without extracting or
copying proprietary resources. `play-2p.cmd` and `play-two-handed.cmd` bypass the menu for quick
multiplayer testing. Standard levels are the default; X levels remain selectable as the bundled
bonus level pack.

Run the current project:

```powershell
godot --path .
```

Run the headless test suite and inspect a local original archive:

```powershell
godot --headless --path . --script res://tests/run_tests.gd -- --archive=../clone/pacx151a.zip
```

The public project name and code license remain deliberate pre-release decisions. “Maze
Engine” is only a neutral working name.

## Current state

The project has reached its initial simultaneous-multiplayer milestone. Player 1 uses the arrow
keys, Player 2 uses WASD, M toggles music, P or Space pauses, and Enter or R restarts after game
over or campaign completion. Escape ends the current game and returns to the mode menu; Escape
on that menu exits. In solo mode either arrow keys or WASD work. On the mode menu, D cycles through
the original Easy, Normal, Hard, and single-player-only Master difficulties.

- Validates the original 1.5.1 ZIP without copying it into the project.
- Parses Apple XML property lists and imports both 25-level packs: the normal Standard levels
  embedded in the editor bundle and the bundled X bonus levels.
- Decodes the original 24-bit RGB and 32-bit RGBA `.raw` image formats.
- Renders neon maze boundary outlines around the recovered path topology without painting over
  the level texture, plus the bundled citadel, ghost-door barrier, pellet, power-pellet,
  background, player, ghost, bonus, READY, pause, death, and game-over artwork directly from
  the archive.
- Implements pixel-exact player movement, buffered turns, tunnel wrapping, pellets, scoring,
  and extra-life thresholds recovered from 1.5.1a.
- Loads all four ghost colors plus frightened/blinking artwork from the user-supplied archive.
- Implements ghost waiting, hunting, frightened, returning, timed release, collision, and
  level-dependent ghost scoring states. Recovered difficulty-specific speed, random branch choice,
  deterministic Hard/Master pursuit, and two-player target ownership are implemented. Returning
  ghosts use a shortest-path field, and the test suite verifies that every connected path cell in
  all 25 levels can reach home without a loop.
- Advances through all 25 imported X levels, preserves score/lives between levels, and implements
  READY, pause, the two-part death sequence, post-death READY reset, game-over,
  campaign-completion, and restart states.
- Loads the original image font, WAV effects, and MP3 title/gameplay music directly from the
  archive and persists named top-ten scores in a versioned, mode-separated local high-score file.
- Implements moving bonuses and the recovered per-avatar double-speed, double-score, and
  invulnerability effects, including the HUD `X2` indicator for double-score. Bonuses use their
  recovered three-frame six-FPS wobble and ±25° rocking; five-frame power pellets animate from
  elapsed time at a slower six-FPS loop rather than display frame count.
- Restores the original five-color bouncing point digits for eaten ghosts and bonuses, including
  double-score values, per-digit launch staggering, the recovered 1.5-second lifetime, and a
  one-second gameplay pause after eating a ghost.
- Implements two-player simultaneous runtime with independent movement, score, lives, power-ups,
  death/respawn, ghost targeting, HUD, and high-score category.
- Implements two-handed runtime with independent movement and power-ups but a shared score/lives
  account and separate high-score category. Exhausting the shared reserve removes only the avatar
  that died; the other finishes its current life. The runtime collections retain the planned
  3/4-player ownership model, but third/fourth player input and artwork are not exposed yet.
- Restores four difficulty-separated high-score categories and Master's original 300×300 moving
  darkness mask while retaining its original solo-only restriction.

Known major gaps include settings, third/fourth player runtime, level-clear polish, and further
side-by-side visual tuning against original screenshots.

Planned multiplayer architecture separates input seats, player profiles/handicaps, live avatars,
score accounts, and selectable appearances; see ADR 0003. Difficulty recovery and the remaining
Aqua/glass maze-rendering fidelity work are tracked in ADR 0004.

For a local visual-regression capture, append an absolute output path:

```powershell
godot --path . -- --archive=../clone/pacx151a.zip --screenshot=C:/temp/maze-preview.png
```

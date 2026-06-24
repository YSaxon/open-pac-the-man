# ADR 0004: Preserve original difficulty modes and isolate visual style

Status: research in progress.

## Recovered facts

The 1.5.1 executable persists a `Difficulty` preference and uses three distinct score categories:
`LevelEasy`, `LevelNormal`, and `LevelHard`. The archive contains `spot.raw`, a 300×300 black RGBA
mask with a transparent circular center and a long alpha falloff. The executable loads it as a
dedicated frame set and its game loop conditionally adds spot sprites. This is the resource behind
the remembered darkness/visibility feature on the highest difficulty.

Exact difficulty effects on ghost decisions, timings, scoring, and spotlight placement still need
to be traced before implementation. Difficulty is session-owned and must not be conflated with
per-player handicaps.

## Decision

- Restore Easy, Normal, and Hard as explicit original-compatible session modes.
- Keep each mode's high scores separate, matching the original categories.
- Implement Hard's darkness with a viewport overlay/mask derived from the supplied `spot.raw`, with
  multiplayer composition defined explicitly rather than assuming one player.
- Research whether multiple players receive a union of visibility bubbles, individual viewports,
  or original player-selection behavior before choosing the multiplayer rule.
- Keep maze topology and collision independent from its renderer. Aqua/glass styling belongs to a
  presentation theme, not level data or navigation code.

## Maze presentation follow-up

The current contour geometry is mechanically correct but flatter than the original Mac OS X look.
The fidelity pass should compare original captures and recover the layered alpha, dark outer edge,
blue body, bright inner highlight, rounded joins, and any glow/shadow treatment. These parameters
should live in a reusable maze material/style object so visual tuning cannot affect path geometry.

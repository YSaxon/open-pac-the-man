# ADR 0004: Preserve original difficulty modes and isolate visual style

Status: difficulty behavior implemented; first Aqua rendering pass implemented.

## Recovered facts

The 1.5.1 executable persists four numeric values: Easy 1, Normal 2, Hard 3, and Master 4. Its
localized strings expose all four labels, and local/online score names distinguish every value.
Easy ghosts use a 0.8 velocity component; Normal, Hard, and Master use 0.9. Easy and Normal have
one-in-three and one-in-27 random branch overrides respectively. Hard and Master are deterministic
and prioritize the target axis with greater separation.

Master is the remembered darkness mode and is explicitly incompatible with two-player games. The
archive's 300×300 `spot.raw` is centered on the player and surrounded by four opaque viewport-sized
sprites. Difficulty is session-owned and is not a per-player handicap.

## Decision

- Restore Easy, Normal, Hard, and Master as explicit original-compatible session modes.
- Keep each mode's high scores separate, matching the original categories.
- Implement Master's darkness from the supplied `spot.raw` and retain the original single-player
  restriction instead of inventing multiplayer spotlight composition.
- Keep maze topology and collision independent from its renderer. Aqua/glass styling belongs to a
  presentation theme, not level data or navigation code.

## Maze presentation follow-up

The current contour geometry is mechanically correct and now uses separate shadow, glow, wall-face,
gap, inner-wall, highlight, and lowlight strokes. This moves the maze closer to the original Mac OS
X Aqua/glass appearance while keeping all visual parameters inside `MazeView`.

The remaining fidelity pass should compare side-by-side original captures and tune the layered
alpha, dark outer edge, colored body, bright inner highlight, rounded joins, and glow/shadow
treatment. Longer-term, these parameters should live in a reusable maze material/style object so
visual tuning cannot affect path geometry.

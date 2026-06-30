# Visual renderer handoff

Date: 2026-06-28

This note is a handoff for the maze/background/tiling fidelity work. It is intentionally more
procedural than architectural: another agent should be able to pick up from here without relying on
chat history.

## Current assessment

The current remake is playable, but the maze visuals are still wrong compared with Pac the Man X.
The biggest issue is the wall/background layer model. The core correction from the latest review is:
the level/background tiling belongs on the non-playable/wall/island regions, not on the playable
corridor tiles.

Real screenshots show:

- Playable corridors should not receive the patterned tiling.
- The patterned level texture is visible across the board, especially inside blocked/non-playable
  islands.
- Maze walls are thin, rounded, translucent/neon outlines with an Aqua/glass feel.
- Some blocked areas have a faint filled/glassy overlay, not just outline strokes.
- The ghost base has a neon orange/yellow `barrier.raw` doorway sprite and sometimes a low-opacity
  glass texture over the base.
- The Standard level 1 wall style is much thinner and smoother than the current procedural mask.

The current code path in `src/presentation/maze_view.gd` creates a procedural mask from the
playable maze graph. It has gone through several iterations, but it is still not faithful enough.
The next best step is probably to recover or reconstruct the original `TGame::BuildLevel` /
`AddTileSprite` logic that places 11×11 wall primitives, rather than continuing to tune the
procedural edge mask by eye.

## Reference screenshots

These files are useful visual breadcrumbs, but they are generated/local artifacts and should not be
committed or kept in the repository root. Regenerate them under `build/visual-artifacts/` when
needed.

- `visual-inspect.png` — first broken attempt: circular/ring artifacts at nearly every maze node.
- `visual-inspect-fixed.png` — removed full-circle arcs but left choppy disconnected/dashed walls.
- `visual-inspect-wall-mask.png` — generated per-segment edge mask; massive internal rings at
  segment endpoints.
- `visual-inspect-wall-union.png` — union-distance edge mask; removed endpoint rings but produced
  overly thick white tube-like corridors.
- `visual-inspect-corridor-mask.png` — latest screenshot at time of handoff; corridors are darkened
  and islands filled, but this is probably still conceptually wrong because it treats playable
  corridors as tubes instead of treating non-playable shapes as the textured/glassy layer.
- `visual-inspect-nonplayable-bg.png` — corrected layer model: the level background tile is applied
  only to non-playable regions. This fixes the fundamental tiling-direction mistake but still leaves
  an overly thick/tube-like procedural wall outline.
- `visual-inspect-subtile-blocked.png` — first subtile-field renderer: each 44 px logical cell is
  split into 4×4 11 px subtiles, playable corridors are carved out, and `tile.raw` primitives frame
  the remaining blocked/non-playable field. This is the best current direction, though outer tunnel
  caps/corner variants still need tuning.
- `visual-inspect-subtile-full-background.png` — refinement of the above: the background pattern is
  tiled under the whole board, while only blocked/non-playable subtiles receive the primitive
  wall/lightening overlay.
- `visual-inspect-convex-subtiles.png` — adds diagonal-aware convex frame selection so blocked
  subtiles with diagonal-only playable openings use frames `0`, `2`, `6`, or `8` instead of fill.
- `visual-inspect-opposite-convex-subtiles.png` — corrected orientation for the diagonal-only
  convex frames: the renderer uses the opposite corner frame so the curve faces the playable
  diagonal opening.
- `visual-inspect-warp-boundaries.png` — adds explicit perimeter warp caps so wrap openings are
  framed with inset pairs instead of appearing as unadorned gaps; top upward tunnels use `13,12`.
- `visual-inspect-profile-adjacency.png` — current checkpoint after adding the logical 2×2 surface
  profile table, moving warp caps off playable subtiles, and adding boundary-opening shoulder caps.
- `visual-inspect-level2-surface-profile.png` — Standard level 2 checkpoint after switching
  interior blocked-subtile frame selection to the shared quadrant/surface-profile predicate. This is
  the reference for T-junction regression work.
- `tile-frames-grid.png` — contact sheet of recovered 11×11 wall primitive frames from `tile.raw`.
- `tile-frames-contact.png` — earlier contact sheet for the same tile primitives.

Useful online reference screenshots:

- Uptodown level-1 blue maze screenshot:
  `https://pac-the-man-x.fr.uptodown.com/mac`
- Uptodown yellow level-2 screenshot:
  `https://pac-the-man-x.fr.uptodown.com/mac`
- My Abandonware later/dark maze screenshot:
  `https://www.myabandonware.com/game/pac-the-man-x-k5h`
- Macintosh Repository screenshot:
  `https://www.macintoshrepository.org/15503-pac-the-man-x`

The Uptodown level-1 image is the most directly relevant to the default Standard mode visual issue.

## Original resource locations

Original archive:

```text
../clone/pacx151a.zip
```

Important files inside the archive:

```text
/Contents/Resources/Sprites/tile.raw
/Contents/Resources/Sprites/tile2.raw
/Contents/Resources/Sprites/citadel1.raw
/Contents/Resources/Sprites/citadel2.raw
/Contents/Resources/Sprites/citadel3.raw
/Contents/Resources/Sprites/barrier.raw
/Contents/Resources/Sprites/font.raw
/Contents/Resources/Sprites/points.raw
/Contents/Resources/Backgrounds/*.png
/Contents/Resources/Levels/The X Levels.plist
/Contents/Resources/Pac the Man X Editor.app/Contents/Resources/Levels.plist
```

Notes:

- Standard levels are loaded from the editor app plist:
  `/Contents/Resources/Pac the Man X Editor.app/Contents/Resources/Levels.plist`.
- X/bonus levels are loaded from:
  `/Contents/Resources/Levels/The X Levels.plist`.
- `tile.raw` / `tile2.raw` decode as `33×77`, i.e. three columns by seven rows of `11×11` primitive
  frames.
- The original board scale is 640×480.
- Maze logical cells are 44 px apart.
- Maze top-left used by the remake is currently `Vector2(34, 36)` for visual placement.
- Runtime entity maze-node centers are documented separately as `(40, 42) + 44 * cell`.

## Relevant code entry points

Main visual code:

```text
src/presentation/maze_view.gd
src/app/main.gd
src/import/raw_sprite.gd
src/import/level_importer.gd
src/core/maze_topology.gd
```

Current initialization in `src/app/main.gd`:

```gdscript
var background_texture := _load_background_texture(archive_path, level.background)
var tile_texture := _load_wall_mask_texture("/Contents/Resources/Sprites/%s.raw" % level.tileset)
var citadel_texture := _load_wall_mask_texture("/Contents/Resources/Sprites/%s.raw" % citadel_name)
var barrier_texture := _load_raw_texture("/Contents/Resources/Sprites/barrier.raw")
maze.set_artwork(tile_texture, citadel_texture, barrier_texture, background_texture)
maze.show_level(level, Vector2(34, 36))
```

Important caveat: `MazeView` now does place original 11×11 primitive frames from `tile.raw` /
`tile2.raw`, but the frame-selection logic is still independently reconstructed. It is not yet a
verified port of the original `BuildLevel` placement algorithm.

Also important: `main.gd` should not stamp background sprites across the whole viewport. The latest
code routes the native background tile into `MazeView`; `MazeView` builds `background_fill_texture`
by sampling it only where the computed mask is non-playable.

## What has already been tried

### 1. Full-cell tile usage

Earlier experiments treated level characters / tile masks as if they corresponded to complete
44×44 tiles. This is wrong. The original `tile.raw` and `tile2.raw` are 11×11 primitive sheets, not
complete navigation-cell tiles.

Result: broken, path-covering blocks and wrong edge textures.

### 2. Centerline strokes

The first procedural approach drew thick strokes along playable graph centerlines.

Result: corridors looked like choppy or broken line segments covering playable paths.

### 3. Parallel boundary lines around corridors

The next approach drew boundaries offset from each path centerline by `PATH_HALF_WIDTH := 15.0`.

Result: closer structurally, but still had bad seams and did not produce the original glass/neon
look. It still treated path topology as the primary painted object rather than non-playable shapes.

### 4. Per-segment wall alpha masks

`visual-inspect-wall-mask.png` came from rasterizing alpha around each path segment.

Result: every segment endpoint became a visible circular/ring artifact.

### 5. Union-distance wall mask

`visual-inspect-wall-union.png` computed the nearest distance to the union of all corridor
segments, so segment endpoints no longer produced rings.

Result: structurally cleaner, but the maze became thick white/blue tubes around black playable
corridors. This still does not match the original.

### 6. Corridor blackout + blocked-region fill

`visual-inspect-corridor-mask.png` added:

- a black mask over the inside of playable corridors;
- a faint fill over blocked/non-playable regions;
- a narrower edge alpha function.

Result: it made the background/tiling placement issue more obvious. The user correctly pointed out
that the tiling should be on non-playable tiles, not playable ones.

The next iteration replaced the procedural distance mask with a 4×4 subtile field per logical maze
cell. It renders the background under the full playfield, then carves playable corridors out of the
subtile grid and stamps original 11×11 primitives on the remaining blocked field. This now directly
encodes the rule that the wall/island overlay belongs to non-playable regions, even though the
background image itself remains visible everywhere.

## Current `MazeView` model

The latest `MazeView` computes:

- `build_playable_subtiles(level.rows)`, a 4×4 subtile grid per 44 px logical cell;
- a two-subtile-wide playable center plus two-subtile-wide extensions for allowed directions;
- `background_fill_texture` across the full board bounds;
- `wall_texture` by stamping original 11×11 `tile`/`tile2` frames over those blocked subtiles.

The current frame mapping explicitly tests the recovered interior-box pattern:

```text
9  7 10
5 11  3
12 1 13
```

This is likely the correct architecture. Diagonal-only openings are now handled as opposite convex
outer corner frames, and perimeter warp openings are explicitly capped without drawing over playable
tunnel subtiles.

The current logical model treats every 11×11 primitive as a 2×2 surface-bit profile:

```text
0  = 1110   1  = 1100   2  = 1101
3  = 1010   5  = 0101   6  = 1011
7  = 0011   8  = 0111   9  = 0001
10 = 0010   11 = 1111   12 = 0100
13 = 1000   blank = 0000
```

The tests now validate that:

- the single blocked-island pattern has matching 2×2 profiles;
- every defined frame round-trips through the profile table;
- a T-shaped playable carve-out selects blocked-subtile frames via the shared 2×2 surface profile;
- emitted real-level frame grids never draw a wall primitive on a playable subtile;
- all shipped Standard and X levels satisfy interior cardinal profile adjacency.

Important limitation: the strict profile validator currently skips the outermost board boundary.
Boundary warp openings are the remaining ambiguous case. A full cardinal+corner invariant over the
outer boundary still fails around top/bottom/side warp shoulders because the original appears to use
special multi-tile boundary-opening treatment. Do not treat the current outer-boundary caps as final
fidelity; they are a cleaner, non-intrusive checkpoint.

## Recovered binary clues

Known from local disassembly work:

- There is a function equivalent to `TGame::AddTileSprite(int, int, int, int, int)`.
- It places tile sprites at 11 px subcell increments:

```text
x ≈ 34 + 44 * cellX + 11 * subX
y ≈ 36 + 44 * cellY + 11 * subY
```

- It uses layer/z around `15`.
- It takes a frame index into the `tile`/`tile2` primitive sheet.
- Frame indices observed are in roughly the `0..14` range, even though the sheet has 21 frames.
- `TLevel::SplitTiles()` only splits the tile bitmap into 11×11 frames; it does not create the map.
- `TGame::BuildLevel` is probably where the frame placement logic lives.

Scratch disassembly file may be present locally:

```text
buildlevel-tile-disasm.txt
```

Do not commit raw disassembly/decompiler output to the public remake repo. It is a local research
aid only. The clean-room implementation should commit observations and independently written code,
not copied original code or decompiler listings.

If continuing this route, regenerate it without ANSI color/noise:

```powershell
r2 -e scr.color=false -A -q -c "s 0xb0f8; pd 360" -c q "..\Pac the Man X.app\Contents\MacOS\Pac the Man X" > buildlevel-tile-disasm-clean.txt
```

Then search backward from calls to `AddTileSprite` and recover the immediate/register arguments:

- cell x
- cell y
- subcell x `0..3`
- subcell y `0..3`
- tile frame index

That should let the remake draw the same 11×11 primitive wall layout instead of guessing.

## Tile primitive frame notes

`tile-frames-grid.png` shows the frames. Rough visual interpretation:

- Frames `0, 2, 6, 8` look like large rounded outer corners.
- Frames `1, 7` look like horizontal edge strips.
- Frames `3, 5` look like vertical edge strips.
- Frames `9, 10, 12, 13` look like smaller/internal curve pieces.
- Frames `11, 14, 18, 19, 20` appear mostly solid/blank/fill-like depending on alpha treatment.

Do not rely on this mapping without checking source pixels. It is only a visual cue.

## Commands that have been useful

Run tests:

```powershell
& C:\Users\ysaxon\scoop\apps\godot\current\godot.console.exe --headless --log-file .godot\visual-tests.log --path . --script res://tests/run_tests.gd -- --archive=../clone/pacx151a.zip
```

Take a screenshot:

```powershell
& C:\Users\ysaxon\scoop\apps\godot\current\godot.console.exe --log-file .godot\visual-inspect.log --path . -- --archive=../clone/pacx151a.zip --mode=solo --level-pack=standard --screenshot=C:/Users/ysaxon/Desktop/pactheman/remake/build/visual-artifacts/visual-inspect-next.png --screenshot-delay=12
```

The screenshot command needs GUI/rendering access. In Codex it may require an escalated tool call.

## Recommended next steps

1. Stop tuning the current procedural mask unless the goal is a temporary cosmetic fallback.
2. Recover `BuildLevel`/`AddTileSprite` frame placement from the original binary.
3. Implement a `TilePrimitiveMazeView` path in `MazeView` using actual `tile.raw` / `tile2.raw`
   frames at 11×11 positions.
4. Keep the procedural mask behind a debug flag until the primitive renderer is verified.
5. Compare level 1 Standard against the Uptodown level-1 screenshot after each iteration.
6. Verify X levels separately; their darker/simpler wall style may intentionally use `tile2.raw`.
7. Preserve `barrier.raw` drawing over the ghost base doorway.
8. Preserve citadel image drawing, but verify its opacity/layering once wall primitives are correct.

## Related non-visual changes currently in the working tree

The working tree also contains unrelated but intentional improvements:

- Standard levels default to the editor-bundled Standard level plist.
- X levels remain available via `--level-pack=x` / menu option.
- HUD font rendering uses `font.raw` with recovered `16×26` glyph frames.
- `x2` double-score indicator is shown with the image font.
- Super pellets animate at a slower recovered 6 fps loop.
- Eaten-ghost point popup pause exists; the ghost sprite is hidden immediately during the pause.
- Pac-Man idle frame now animates as a right-facing mouth cycle.

Before committing, check `git status --short` and avoid accidentally committing temporary
inspection files unless intentionally preserving them.

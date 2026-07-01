# Level-load profiling: methodology and findings

This documents how the maze-load performance issue fixed in `81ddd93` was found,
and the follow-up check for any remaining per-frame (steady-state) hot path.
Both used Godot's built-in CLI script profiler — no ad hoc `Time.get_ticks_usec()`
instrumentation was added to game code.

## Methodology

Godot 4 ships a script CPU profiler and a GPU frame profiler that can both be
driven entirely from the command line, dumping per-function self/total time and
call counts to stdout every time the profiler flushes (roughly once per second
of wall time). No source changes are required to use it.

```powershell
godot --path . -d --profiling --gpu-profile --quit-after <N> -- <game args>
```

- `-d` — local stdout debugger (required for `--profiling` to have anywhere to report to).
- `--profiling` — enables the script profiler.
- `--gpu-profile` — adds a per-frame GPU render breakdown (e.g. `Render CanvasItems`).
- `--quit-after <N>` — auto-quits after N process frames, so the run is scriptable
  instead of needing a human to close the window.

Each flush prints blocks shaped like:

```text
FRAME: total: 0.323326 script: 0.315444/97 %
0:res://src/presentation/maze_view.gd::70::MazeView._draw
	total: 0.318661/98 % 	self: 0.000035/0 % tcalls: 1
1:res://src/presentation/maze_view.gd::93::MazeView._ensure_wall_texture
	total: 0.318285/98 % 	self: 0.00249/0 % tcalls: 1
...
```

`total` is time including callees, `self` is time in that function alone, `tcalls`
is the call count since the last flush. Sorting by `self` finds real hot spots
directly, without guessing which function to instrument.

For isolating pure CPU/script cost with zero rendering or vsync throttling
(useful for reasoning about weaker/GPU-less systems), add `--headless`:

```powershell
godot --headless --path . -d --profiling --quit-after <N> -- <game args>
```

Headless disables the renderer (so `_draw()`/canvas rendering is skipped) and
removes vsync pacing, so `--quit-after` frames complete as fast as the CPU can
run them — this gives a floor on `_process`/`_physics_process` cost.

To exercise real per-tick gameplay (not just the idle "READY" state), start the
game in two-player mode and use the existing `--qa-multiplayer-motion` QA hook to
give both players an initial direction so they keep moving, colliding with
pellets and ghosts, instead of sitting idle:

```powershell
godot --path . -d --profiling --gpu-profile --quit-after 900 -- --archive=../clone/pacx151a.zip --mode=simultaneous --level-pack=standard --qa-multiplayer-motion
```

## Findings

### Level-load hitch (fixed)

The first rendered frame of a level cost **323ms**, almost entirely inside
`MazeView._ensure_wall_texture`:

| Function | Self time | Calls | Cause |
| --- | --- | --- | --- |
| `MazeView._inside_level_bounds` | 145.8ms | 307,200 | Called once per viewport pixel (640×480) from a per-pixel `get_pixel`/`set_pixel` loop in `_stamp_board_background` — pure GDScript function-call overhead. |
| `MazeView._stamp_board_background` | 48.3ms | 1 | The per-pixel loop itself. |
| `OriginalArchive.read_file_by_suffix` | 85.0ms | 19 | Re-ran `ZIPReader.get_files()` (a full re-scan of the archive's file list) on *every* call, even though the reader itself was already cached. |

This happens on every level load, restart, and level transition — a real,
player-visible stutter, not a hypothetical one.

**Fix (`81ddd93`):**

- `_stamp_board_background` now tiles the background with `Image.blit_rect` in
  background-tile-sized blocks, clipped to the maze's actual pixel bounds,
  instead of a per-pixel loop. `_inside_level_bounds` was deleted (its only
  caller was removed).
- `OriginalArchive.read_file_by_suffix` now only calls `reader.get_files()` when
  the file list for that archive path isn't already cached.

One regression was caught and fixed before landing: `Image.blit_rect` requires
matching source/destination pixel formats and silently no-ops (with a logged
engine error) on mismatch. The background PNGs decode as `FORMAT_RGB8`, but the
destination buffer is `FORMAT_RGBA8`, so the very first version of the fix drew
no background at all. Caught via a `--screenshot` comparison; fixed with one
`Image.convert(Image.FORMAT_RGBA8)` call on the source before tiling.

**Result:** level-load frame time dropped from **323ms to ~25ms** (~13x).
Verified via re-profiling, a visual screenshot check, and a full run of
`tests/run_tests.gd` (all passing).

### Steady-state per-frame cost (no action needed)

Profiled 15 seconds of real two-player movement (`--mode=simultaneous
--qa-multiplayer-motion`), covering pellet collection, ghost chasing, and
collisions:

- Every recurring per-tick function (`PelletField.collect`/`_intersects`,
  `GhostMotion._choose_direction`/`_step_pixel`, sprite sync) costs low
  single-digit microseconds per call.
- Total script time per frame stays under ~1ms out of a ~19ms frame budget
  (the rest is idle time waiting on vsync).
- GPU canvas render costs 0.4–0.9ms per frame (four full-screen `draw_texture`
  passes for the wall glow/shadow/face/highlight), measured on an NVIDIA MX450
  — itself a low-end discrete GPU, so this is a reasonable low-end data point.
- Headless (no renderer, no vsync) frames cost **9–45 microseconds** total —
  the actual CPU floor for `_process`/`_physics_process` with nothing else
  competing for the frame budget.

**Conclusion:** there is no per-frame hot path worth optimizing. The engine is
vsync-bound, not compute-bound, on hardware far weaker than required to even run
Godot's `gl_compatibility` renderer. The level-load fix above was the only real
bottleneck in the codebase.

### Note on the `premature_optimizations` branch

That branch (commit `86bfd65`, unmerged) manually instrumented and "optimized"
`ghost_motion.gd`'s citadel-marker lookup, `pellet_field.gd`'s pellet scan, and
`maze_view.gd`'s `frame_for_surface_profile` bit-packing. The profiler data above
shows all three cost fractions of a millisecond per frame in real play — they
were not measured hot spots, and the branch left ad hoc `print()` profiling
statements in game code. It was correctly not merged; the level-load fix here is
based on profiler-identified costs instead.

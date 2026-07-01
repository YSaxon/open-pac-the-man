# Open questions for future original/decompilation research

This document records unresolved questions about the original Pac the Man X 1.5.1a
behavior, along with any leads already gathered. Like
`docs/research/gameplay-1.5.1.md`, it records observed facts (strings, method/ivar
names, data files) — not original source or decompiler output.

## Method used so far

- **Data-driven questions** — check the level `.plist` files and editor `.plist`
  files inside the archive directly; several questions below are fully answered
  this way with no binary analysis needed.
- **Behavioral questions** — a crude strings extraction from the Mach-O executable
  (`Contents/MacOS/Pac the Man X` inside the archive; regex over runs of printable
  ASCII ≥4 chars) surfaces Objective-C class names, ivars, and selectors even in
  the stripped 64-bit slice (`docs/research/gameplay-1.5.1.md` already notes this).
  This tells you a code path *exists* and roughly what it's named, not what its
  *logic* is. Answering the "when" questions below for certain needs real
  disassembly (Hopper/Ghidra on the Mach-O slices), which has not been done here.

```python
import zipfile, re
z = zipfile.ZipFile("pacx151a.zip")
data = z.read("Pac the Man X/Pac the Man X.app/Contents/MacOS/Pac the Man X")
strings = set(re.findall(rb"[\x20-\x7e]{4,}", data))
```

## Resolved

### tile vs tile2

Fully answered from data, no decompilation needed:

- `tile` = "Embossed tiles", used by **all 25 Standard levels** (0 exceptions).
- `tile2` = "Classic tiles", used by **all 25 X levels** (0 exceptions).
- Source: `Pac the Man X Editor.app/.../tilesets.plist` gives the display names;
  tallying the `tileset` key across `Pac the Man X Editor.app/.../Levels.plist`
  (standard pack) and `Pac the Man X.app/.../Levels/The X Levels.plist` (X pack)
  confirms the 100%/100% split.
- Already correctly data-driven in the remake via `level.tileset`
  (`src/core/level_data.gd:9`, `src/import/level_importer.gd:35`,
  `src/app/main.gd:209`) — nothing to fix here, this was just an open question
  about *why* two tilesets exist, now answered.

## Open

### Music track selection

Only `PacManiac.mp3` (gameplay) and `PacTitle.mp3` (menu) are ever played by the
remake — see the `_play_music(...)` call sites in `src/app/main.gd`. Unused:
`Loopback.mp3`, `PacDreamer.mp3`, `Pacland.mp3`, `Ending.mov`.

Binary evidence: an `MGMusic` class exists with ivars `musicArray_`, `music_`,
`titleMusic_`, `endingMusic_`. The plural `musicArray_` strongly suggests
gameplay music is chosen from a set/rotation rather than a single hardcoded file.

**TODO:** disassemble `MGMusic`'s track-selection method to learn the actual
selection rule — random per level? per level pack (Standard vs X, matching the
tile/tile2 split above)? per difficulty? a cycling playlist? — then update
`_play_music` call sites in `src/app/main.gd` accordingly.

### Ending screen + music (see also the arrow/darkness fix — same investigation surfaced this)

`ending.raw` (a full 640×480 "AMAZING! YOU FINISHED THE GAME!! THANKS FOR
PLAYING!!" screen with staff credits) and `Ending.mov` are both completely
unused. The remake currently only shows `the_end.raw` (a small title card, same
treatment as `game_over.raw`) with no music, in `_advance_level()`
(`src/app/main.gd:978`).

Binary evidence: the `endingMusic_` ivar on `MGMusic` confirms a dedicated
ending-music slot exists.

**TODO:**
- Confirm whether `Ending.mov` is a real video played standalone, or just an
  audio container driven through `MGMusic`.
- Wire up `ending.raw` (and its music/video) as the actual "finished the whole
  game" screen in `_advance_level()`, likely replacing or supplementing the
  current `the_end.raw` treatment.

### font_small usage

`font_small.raw` (a complete second, smaller font sheet) is never loaded by the
remake.

Binary evidence: format strings `font_small%d`, `font_small1`, `font_small2` —
this mirrors the `player%d.raw` pattern (`player1.raw`/`player2.raw`), which
suggests a **per-avatar** small font rather than one shared font.

**TODO:** find where the original selects `font_small<N>` and what it renders
(HUD label? player-name entry? some per-player UI region the remake doesn't have
yet?) — `src/presentation/font_text_view.gd` is the remake's only font renderer
today and only ever uses `font.raw`.

### Highscore formatting

Binary evidence: a dedicated `MGHighscores` class
(`T@"MGHighscores",R,Vhighscores_`), plus selectors `highscoreTableName` and
`highscoreTables_`. This is consistent with `docs/research/gameplay-1.5.1.md:116`'s
existing note that table names combine the level-file name with the numeric
difficulty.

Also found: `http://www.mcsebi.com/ptmx_highscores.php?%@?%@?%@?%@?%d?%d?OSX?2` —
the original submitted scores to an online leaderboard. That endpoint is almost
certainly dead and out of scope to replicate, but it explains why the class is
named `MGHighscores` rather than something purely local.

`highscore_title.raw` (the "HIGHSCORES" title graphic) is unused; the remake
renders a plain text heading instead (`_show_high_scores`,
`src/app/main.gd:1279`).

**TODO:**
- Disassemble `highscoreTableName` to get the *exact* table-key format. The
  remake's `_current_high_score_category()` (`src/app/main.gd:340`) is an
  independent reconstruction, not verified against the original's real scheme.
- Confirm per-entry field layout (name length limit, score formatting, whether
  ties are broken by anything besides score) against `src/core/high_score_store.gd`.
- Consider swapping the plain-text heading for `highscore_title.raw`.

### eat_pellet B vs B2 vs F vs F2

The remake only ever alternates `eat_pelletB.wav`/`eat_pelletB2.wav` regardless
of which avatar ate the pellet (`_collect_pellet_for_avatar`,
`src/app/main.gd:744`). `eat_pelletF.wav`/`eat_pelletF2.wav` are unused, and are
audibly distinct clips — noticeably longer than B/B2 (0.16s/0.14s vs 0.09s/0.08s).

Binary evidence is inconclusive and cuts against the tidy "F is for player 2"
guess floated earlier in this project's history: the selector
`addPelletSprites:y:pelletType:rightPellet:downPellet:` takes a `pelletType`
parameter, which raises the possibility that B vs F depends on the **pellet's
type/orientation** rather than the eating **avatar**.

**TODO:** disassemble the pellet-eaten sound-selection call site to determine
whether the B/F choice actually depends on `avatar_index`, `pelletType`, both, or
something else (e.g. it could simply be a second random-alternation pair like
B/B2 already is, unlocked in some mode the remake doesn't have).

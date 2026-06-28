# Pac the Man X 1.5.1a gameplay observations

This document records behavioral facts used by the independent implementation. It does not
contain original source or decompiler output.

## Binary

The application executable is a universal Mach-O containing x86-64 and i386 slices. The
64-bit slice is stripped but retains Objective-C runtime metadata, including class names,
method selectors, ivar names, and method boundaries.

Relevant original classes include `PMGame`, `PMSprite`, `PMPlayer`, `PMGhost`, `PMExtra`,
`MGAnimation`, and `MGSprite`.

## Coordinate system

- Logical display: 640×480.
- Maze node `(0, 0)` is at pixel `(40, 42)`.
- Adjacent maze nodes are 44 pixels apart.
- Tile coordinates are derived from `(pixelX - 40) / 44` and `(pixelY - 42) / 44`.
- Crossing `x <= 1` places an entity at `x = 606`; crossing `x >= 607` places it at `x = 2`.
- Crossing `y <= 3` places an entity at `y = 476`; crossing `y >= 477` places it at `y = 4`.

## Directions and tiles

Directions are bit values:

- left: 1
- right: 2
- up: 4
- down: 8

Level characters `A` through `P` map directly to values 0 through 15. Direction
availability is a bit test between the requested direction and the tile value. `Q`, `R`,
and `S` have special citadel/path behavior.

### Maze presentation

The `tile` and `tile2` sheets are 33 pixels wide and contain 11-pixel primitive wall pieces;
their entries are not complete 44-by-44 navigation-cell textures. Treating the character ordinal
as a sheet frame and scaling that frame to a full cell produces broken, path-covering blocks.
The rendered board follows the path topology but should not paint a solid black corridor over the
level texture. Original screenshots show the level/background texture visible through both
corridors and enclosed islands, with neon wall boundaries above it. The remake therefore draws
boundary lines offset from each path centerline, then overlays the complete 132-by-88 citadel image
and the 40-by-8 `barrier.raw` ghost-door sprite.

## Player movement

- The original animation context targets a 60 Hz display and defines its movement speed factor as
  `30 / fps`, producing a 0.5-pixel base movement unit. Movement is advanced on a 30 Hz gameplay
  cadence; advancing it on every 60 Hz display frame makes the entire simulation run twice as fast.
- A normal player update runs ten base movement substeps (5 pixels per gameplay tick).
- Double speed runs fourteen substeps.
- Horizontal and vertical nominal velocity components are each -1, 0, or 1 and are multiplied
  by the context speed factor.
- Direction availability is refreshed from the current maze node during movement.
- Perpendicular movement is snapped to the node axis before a turn.
- Player animation uses 32×32 frames.

The implementation keeps these values as named constants and exercises them in headless
tests so later refactoring cannot silently change compatibility behavior.

## Pellets and score

- The player sprite is positioned by its 32×32 top-left coordinate; its maze-node center
  is therefore `(56 + 44x, 58 + 44y)`.
- Normal pellets are 10×10 and are placed at node centers and 22-pixel edge midpoints.
- The midpoint pellet on the edge from the maze into the citadel is explicitly suppressed. The
  reachable maze-node pellet immediately outside the entrance remains present.
- Super pellets are 30×30 and are centered on the positions listed by the level.
- A normal pellet is worth 5 points; a super pellet is worth 10 points.
- The double-score state doubles points before adding them.
- Crossing a 25,000-point boundary awards an extra life.
- Regular-pellet collision uses player bounds inset by 10 pixels; super-pellet collision
  uses bounds inset by 15 pixels.

## Ghost states and movement

The five values stored by the original ghost movement state are:

- 1: waiting inside the citadel
- 2: hunting
- 3: frightened in the maze
- 4: returning to the citadel after being eaten
- 5: frightened while waiting inside the citadel

Each normal game update invokes ghost movement ten times while hunting, five times while
frightened, and up to 32 times while returning. After the first branch, the 0.5 context factor and
difficulty velocity make these 4.0/2.0/12.8 pixels on Easy and 4.5/2.25/14.4 pixels on the other
modes. Waiting ghosts retain their initial unit velocity and receive ten vertical updates;
frightened waiting ghosts receive five. Entering frightened state reverses a ghost's current
velocity. A returning ghost is not affected by another super pellet.

Hunting ghosts first target the citadel entry when leaving home, then target a player. Returning
ghosts first target the citadel entry, then their individual starting point. With two players,
ghosts 0 and 2 target player 1 while ghosts 1 and 3 target player 2; a one-player game returns its
sole player for either request.

The persisted difficulty values are Easy 1, Normal 2, Hard 3, and Master 4; Normal is the fallback.
Easy uses a 0.8 ghost velocity component and the other modes use 0.9, each multiplied by the
animation context's 0.5 speed factor. At a hunting branch after leaving home, Easy has a one-in-three
chance to replace its target-directed choice with a random available direction. Normal does so
one time in 27. Hard and Master have no random override and, when both a horizontal and vertical
target-directed choice exist, retain the axis with the larger absolute separation (horizontal wins
a tie). Frightened ghosts invert the target comparisons.

Master is single-player-only. Each Master player owns the supplied 300×300 `spot.raw` sprite,
centered on its 32×32 artwork, plus four opaque 640×480 sprites positioned around it so the rest of
the viewport is black. The local high-score table name includes both level-file name and numeric
difficulty, giving all four modes distinct tables.

Ghost zero starts on the citadel entry and immediately hunts. The remaining three start one row
inside the citadel at horizontal offsets -1, 0, and +1 and initially wait. Ghost zero's return
position is the center position on that inner row. Normal ghost artwork is a 6-by-9 frame sheet;
frightened and late-timer blinking frames are stored in a separate 6-by-1 sheet.

Player/ghost collision requires both top-left coordinate differences to be at most 10 pixels.
A frightened ghost begins returning; a hunting ghost hits a non-invulnerable player. Waiting,
returning, and frightened-waiting ghosts do not trigger either outcome. Consecutive frightened
ghost scores depend on the level group: levels 0-6 award 200/400/800/2000, levels 7-12 award
400/1000/2000/4000, levels 13-18 award 1000/2000/4000/5000, and later levels award
1000/3000/5000/10000.

The delay between releasing waiting ghosts is seven seconds for levels 0-7, six for 8-12,
five for 13-17, four for 18-22, and three thereafter. Each expiry releases the first waiting
ghost. A frightened waiting ghost can be released directly into its frightened maze state.

## Point popups

Both frightened-ghost and extra collisions call `TGame::AddPointSprites`. The routine converts
the awarded value to digits after applying double-score, centers it using recovered glyph widths
`16, 12, 16, 16, 18, 16, 16, 16`, and constructs one `TPoints` sprite per digit from
`points.raw`. The 144×105 sheet contains eight 18×21 digit frames (`0`–`6` and `8`) in five
color rows. Successive awards rotate through those five colors.

Each digit starts ten pixels below the collision coordinate and launches at -14 velocity after a
two-frame-per-digit stagger. `TSprite::MoveXY` applies the 0.5 animation speed factor and
`TPoints::Move` adds 0.5 gravity each 60 Hz animation frame. The digit settles six pixels below
the collision coordinate and the sprite expires after 90 frames (1.5 seconds).

Video reference and play feel show a short gameplay pause while the eaten-ghost point digits bounce.
The current remake uses a one-second gameplay pause after a frightened ghost is eaten while point
popup animation continues. This remains a candidate for a deeper code trace if exact frame count is
needed.

## Player extras

The five numbered extras award 500, 1000, 2000, 3000, and 5000 points. Extra 0 enables double
speed, extra 1 enables double score, and extra 2 grants invulnerability for eight seconds. Extras
3 and 4 are score-only in player collision handling. Double speed, double score, and
invulnerability belong to the individual player avatar and are cleared when that avatar dies;
this distinction matters for simultaneous and two-handed modes.

The symbol-rich earlier build constructs each `TExtra` with a three-frame set and calls
`TSprite::SetFrameSpeed(6.0)`. The visible order is implemented as a center/right/center/left
wobble at six frames per second. Rotation advances in three-degree gameplay steps but reverses at
25 and 335 degrees, making the item rock about 25 degrees in each direction rather than spin. The
five-frame super-pellet strip advances from elapsed time at six frames per second so its loop remains
stable when the display refresh rate changes.

Once per second, the original attempts to spawn an extra only while at least 60 pellets remain, no
extra is already active, and fewer than five have appeared. The attempt has a one-in-seven chance.
It chooses one candidate maze node and cancels the attempt if either axis is within 100 pixels of a
player; it does not select again from only the distant nodes. The extra number is then chosen
uniformly from zero through four using the application's shared runtime random generator.

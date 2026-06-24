# ADR 0003: Separate input seats, player profiles, avatars, and appearances

Status: planned; current avatar/account separation is compatible.

## Context

Three- and four-player simultaneous play needs configurable controls, controller swapping,
per-player handicaps, and additional visual identities. A fixed mapping such as “WASD is player
2” would incorrectly bind a person's score, handicap, and appearance to one keyboard cluster.

Desktop operating systems normally present ordinary keyboards to Godot as one merged keyboard.
Plugging in a second keyboard therefore provides more physical space but does not reliably let the
game distinguish identical keys by device. Per-keyboard identity would require a platform-specific
raw-input backend and is not a suitable cross-platform default. Gamepads do expose device IDs.

## Decision

The session model will keep these concepts independent:

- `InputSeat`: a set of logical actions and a source device (keyboard cluster or gamepad ID).
- `PlayerProfile`: the participant's name, handicap preset, and preferred appearance.
- `Avatar`: live movement, collision, temporary effects, and an assigned input seat.
- `ScoreAccount`: score, reserve lives, and extra-life thresholds, already separate from avatars.
- `PlayerAppearance`: normal, flash, death, and burst artwork plus an optional palette treatment.

The lobby will assign seats and appearances to profiles explicitly. Swapping seats changes only
who controls an avatar; it does not move scores or handicaps. Bindings are customizable and saved
by seat, not hard-coded by player number.

Default local controls should prioritize gamepads for players 3 and 4. A one-keyboard fallback can
offer four separated clusters (arrows, WASD, IJKL, and numpad) but must warn that keyboard rollover
and physical crowding vary by hardware. A second ordinary keyboard remains part of that merged key
space. A future raw-input plugin may optionally provide distinct keyboards on supported platforms.

## Handicap ownership

Handicaps are typed rather than represented by one generic difficulty scalar:

- Account-owned: starting reserve lives, points required per extra life, score multiplier.
- Avatar-owned: movement-speed multiplier and any future collision/invulnerability assistance.
- Session-owned: original global difficulty mode and maze/ghost rules.

Two-handed mode maps two avatars to one profile/account. Account modifiers apply once to the shared
account; avatar modifiers may apply independently if the lobby explicitly permits that. Score
multipliers affect awarded points before popup display and extra-life threshold evaluation so the
HUD, point popup, stored score, and life awards cannot disagree.

Handicap configuration becomes part of the high-score category or marks a run as assisted. It must
not silently enter the unmodified original-mode tables.

## Appearance strategy

The two original player sheets remain selectable presets. Players 3 and 4 can initially use
shader/palette variants, provided player number remains legible for color-vision deficiencies.
The abstraction also accepts complete new sprite sets later, avoiding a dependency on recoloring.

## Consequences

No handicap implementation is added on the main branch yet. When lobby and modifier work begins it
should use a feature branch because it touches score, life, movement, persistence, UI, and high-score
categorization together. The current runtime arrays and avatar/account split require no rollback.

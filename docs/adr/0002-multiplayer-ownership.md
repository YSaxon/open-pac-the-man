# ADR 0002: Separate avatars from score/life accounts

Status: accepted and implemented for solo, simultaneous two-player, and two-handed runtime.

## Context

Pac the Man X supports two simultaneous players. The remake should preserve that feature and
leave room for three or four simultaneous players. It should also support a two-handed mode:
one human controls two otherwise independent player avatars while sharing a single score and
life pool. Two-handed results need a separate high-score table because the mode has a different
difficulty profile.

## Decision

The game session will model player avatars and score/life accounts as separate concepts.

- An avatar owns movement, input binding, position, animation, collision state, and temporary
  effects such as speed, invulnerability, and double score.
- An account owns score, lives, extra-life thresholds, and high-score persistence.
- Ordinary simultaneous play maps avatar N to account N.
- Two-handed play maps both avatars to account 0, while retaining separate avatar power-ups.
- Shared lives are a reserve pool, not shared avatar survival: when the reserve reaches zero, only
  the avatar that just died is removed. Any other live avatar continues until its own death.
- The runtime must accept one to four avatars even before layouts and input defaults are supplied
  for every count.
- High scores are keyed by an explicit mode category (`solo`, `simultaneous_2p` through
  `simultaneous_4p`, and `two_handed`).

Ghost targeting must consume a list of live avatars rather than a hard-coded player-one object.
This also preserves the original behavior where ghosts select between simultaneous players.

## Consequences

The runtime stores avatars and accounts in separate collections and retains player-one aliases only
for compatibility with the original solo QA hooks. Third/fourth player input and artwork remain to
be added; the ownership rules and score categories already support them.

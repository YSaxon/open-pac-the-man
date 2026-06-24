class_name GhostCollision
extends RefCounted

const GhostStateScript := preload("res://src/core/ghost_state.gd")

const NONE := 0
const GHOST_EATEN := 1
const PLAYER_HIT := 2
const MAX_AXIS_DISTANCE := 10


static func classify(player_position: Vector2, ghost_position: Vector2, ghost_state: int, invulnerable := false) -> int:
	if (
		absi(player_position.x - ghost_position.x) > MAX_AXIS_DISTANCE
		or absi(player_position.y - ghost_position.y) > MAX_AXIS_DISTANCE
	):
		return NONE
	if ghost_state == GhostStateScript.FRIGHTENED:
		return GHOST_EATEN
	if ghost_state == GhostStateScript.HUNTING and not invulnerable:
		return PLAYER_HIT
	return NONE

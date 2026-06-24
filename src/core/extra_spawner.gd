class_name ExtraSpawner
extends RefCounted

const PlayerMotionScript := preload("res://src/core/player_motion.gd")

const MINIMUM_PELLETS := 60
const MAX_APPEARANCES := 5
const MINIMUM_AXIS_DISTANCE := 100
const CHANCE_DENOMINATOR := 7

var topology
var candidates: Array[Vector2i] = []
var appeared := 0
var active := false
var check_ticks := 60
var ticks_per_second := 60
var rng := RandomNumberGenerator.new()


func _init(maze = null, tick_rate := 60, seed := -1) -> void:
	topology = maze
	ticks_per_second = tick_rate
	check_ticks = tick_rate
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	if topology != null:
		for y in topology.height():
			for x in topology.width():
				var cell := Vector2i(x, y)
				var mask: int = topology.mask_at(cell)
				if mask > 0 and mask <= 15:
					candidates.append(cell)


func step(player_positions: Array[Vector2], pellets_remaining: int) -> Dictionary:
	check_ticks -= 1
	if check_ticks > 0:
		return {}
	check_ticks = ticks_per_second
	if active or appeared >= MAX_APPEARANCES or pellets_remaining < MINIMUM_PELLETS:
		return {}
	if rng.randi_range(0, CHANCE_DENOMINATOR - 1) != 0:
		return {}
	return _spawn(player_positions)


func force_spawn(cell: Vector2i, extra_number: int) -> Dictionary:
	active = true
	appeared += 1
	return {"cell": cell, "extra_number": clampi(extra_number, 0, 4)}


func released() -> void:
	active = false


func _spawn(player_positions: Array[Vector2]) -> Dictionary:
	if candidates.is_empty():
		return {}
	# The original tests one randomly selected candidate and abandons this
	# second's attempt when it is close to a player; it does not search for a
	# different eligible cell.
	var cell: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
	var pixel := PlayerMotionScript.pixel_for_cell(cell)
	for player in player_positions:
		if (
			absi(pixel.x - player.x) < MINIMUM_AXIS_DISTANCE
			or absi(pixel.y - player.y) < MINIMUM_AXIS_DISTANCE
		):
			return {}
	return force_spawn(cell, rng.randi_range(0, 4))

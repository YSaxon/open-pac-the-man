class_name GhostMotion
extends RefCounted

const MazeDirectionScript := preload("res://src/core/direction.gd")
const GhostStateScript := preload("res://src/core/ghost_state.gd")
const PlayerMotionScript := preload("res://src/core/player_motion.gd")
const DifficultyRulesScript := preload("res://src/core/difficulty_rules.gd")

const HUNTING_SUBSTEPS := 10
const FRIGHTENED_SUBSTEPS := 5
const RETURNING_SUBSTEPS := 32
const DIRECTION_ORDER: Array[int] = [
	MazeDirectionScript.LEFT,
	MazeDirectionScript.RIGHT,
	MazeDirectionScript.UP,
	MazeDirectionScript.DOWN,
]

var topology
var position := Vector2(PlayerMotionScript.GRID_ORIGIN)
var direction := MazeDirectionScript.NONE
var state := GhostStateScript.WAITING
var reached_target := false
var frightened_ticks := 0
var ghost_number := 0
var frame := 0
var home_cell := Vector2i(-1, -1)
var entry_cell := Vector2i(-1, -1)
var spawn_cell := Vector2i(-1, -1)
var difficulty := DifficultyRulesScript.Level.NORMAL
var rng := RandomNumberGenerator.new()


func _init(
	maze = null,
	start_cell := Vector2i.ZERO,
	number := 0,
	return_cell := Vector2i(-1, -1),
	difficulty_level := DifficultyRulesScript.Level.NORMAL,
	seed := -1,
) -> void:
	topology = maze
	spawn_cell = start_cell
	home_cell = start_cell if return_cell.x < 0 else return_cell
	position = Vector2(PlayerMotionScript.pixel_for_cell(start_cell))
	ghost_number = number
	difficulty = clampi(difficulty_level, DifficultyRulesScript.Level.EASY, DifficultyRulesScript.Level.MASTER)
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	if topology != null:
		entry_cell = topology.citadel_entry()


func reset_to_spawn() -> void:
	position = Vector2(PlayerMotionScript.pixel_for_cell(spawn_cell))
	frightened_ticks = 0
	frame = 0
	if ghost_number == 0:
		direction = MazeDirectionScript.LEFT
		start_hunting(true)
	else:
		direction = MazeDirectionScript.DOWN
		state = GhostStateScript.WAITING
		reached_target = false


func start_hunting(already_outside := false) -> void:
	state = GhostStateScript.HUNTING
	reached_target = already_outside


func start_frightened(duration_ticks: int) -> void:
	if state == GhostStateScript.RETURNING:
		return
	frightened_ticks = maxi(duration_ticks, 0)
	if state == GhostStateScript.WAITING or state == GhostStateScript.FRIGHTENED_WAITING:
		state = GhostStateScript.FRIGHTENED_WAITING
	else:
		state = GhostStateScript.FRIGHTENED
		reached_target = false
		direction = MazeDirectionScript.opposite(direction)


func start_returning() -> void:
	state = GhostStateScript.RETURNING
	reached_target = false
	frightened_ticks = 0


func step(player_top_left: Vector2) -> void:
	if frightened_ticks > 0:
		frightened_ticks -= 1
		if frightened_ticks == 0:
			if state == GhostStateScript.FRIGHTENED:
				state = GhostStateScript.HUNTING
				reached_target = true
			elif state == GhostStateScript.FRIGHTENED_WAITING:
				state = GhostStateScript.WAITING

	var substeps := HUNTING_SUBSTEPS
	match state:
		GhostStateScript.FRIGHTENED, GhostStateScript.FRIGHTENED_WAITING:
			substeps = FRIGHTENED_SUBSTEPS
		GhostStateScript.RETURNING:
			substeps = RETURNING_SUBSTEPS
		GhostStateScript.WAITING:
			substeps = HUNTING_SUBSTEPS
	for ignored in substeps:
		_step_pixel(player_top_left)
	frame += 1


func current_cell() -> Vector2i:
	return Vector2i(
		roundi(float(position.x - PlayerMotionScript.GRID_ORIGIN.x) / PlayerMotionScript.GRID_SPACING),
		roundi(float(position.y - PlayerMotionScript.GRID_ORIGIN.y) / PlayerMotionScript.GRID_SPACING),
	)


func is_on_node() -> bool:
	var center := Vector2(PlayerMotionScript.pixel_for_cell(current_cell()))
	var tolerance := PlayerMotionScript.MOVE_UNIT * DifficultyRulesScript.ghost_speed(difficulty) + 0.001
	var delta := position - center
	var close := (
		absf(position.x - center.x) <= tolerance
		and absf(position.y - center.y) <= tolerance
	)
	if not close:
		return false
	if delta.is_zero_approx():
		return true
	# Fractional 0.4/0.45-pixel speeds rarely land exactly on a node. Snap
	# only while approaching a nearby node, never immediately after leaving it.
	return delta.dot(Vector2(MazeDirectionScript.vector(direction))) < 0.0


func _step_pixel(player_top_left: Vector2) -> void:
	if state == GhostStateScript.WAITING or state == GhostStateScript.FRIGHTENED_WAITING:
		_wait_pixel()
		return
	if is_on_node():
		var cell := current_cell()
		position = Vector2(PlayerMotionScript.pixel_for_cell(cell))
		if state == GhostStateScript.RETURNING and cell == entry_cell:
			reached_target = true
		if state == GhostStateScript.RETURNING and reached_target and cell == home_cell:
			state = GhostStateScript.WAITING
			direction = MazeDirectionScript.DOWN
			return
		direction = _choose_direction(cell, player_top_left)
	if direction == MazeDirectionScript.NONE:
		return
	position += (
		Vector2(MazeDirectionScript.vector(direction))
		* PlayerMotionScript.MOVE_UNIT
		* DifficultyRulesScript.ghost_speed(difficulty)
	)
	_wrap_screen()


func _wait_pixel() -> void:
	if direction != MazeDirectionScript.UP and direction != MazeDirectionScript.DOWN:
		direction = MazeDirectionScript.DOWN
	# The original waiting state reverses on a vertical branch after a small
	# changed-direction delay. Keep the ghost inside the 44-pixel home lane.
	var center := PlayerMotionScript.pixel_for_cell(home_cell)
	if position.y >= center.y + 18:
		direction = MazeDirectionScript.UP
	elif position.y <= center.y - 18:
		direction = MazeDirectionScript.DOWN
	position += Vector2(MazeDirectionScript.vector(direction)) * PlayerMotionScript.MOVE_UNIT


func _choose_direction(cell: Vector2i, player_top_left: Vector2) -> int:
	if state == GhostStateScript.RETURNING:
		if not reached_target:
			var homeward: int = topology.shortest_direction(cell, entry_cell)
			if homeward != MazeDirectionScript.NONE:
				return homeward
		elif cell == entry_cell:
			return _direction_between(entry_cell, topology.find_marker("R"))
	var cell_mask: int = topology.mask_at(cell)
	if cell_mask >= 16:
		return _citadel_direction(cell, _target_cell(player_top_left))
	var choices: Array[int] = topology.directions_at(cell)
	if choices.is_empty():
		return MazeDirectionScript.opposite(direction)

	# Hunting/frightened ghosts cannot enter the citadel from the maze.
	if cell == entry_cell and state != GhostStateScript.RETURNING:
		var toward_citadel := _direction_between(entry_cell, topology.find_marker("R"))
		choices.erase(toward_citadel)

	var reverse := MazeDirectionScript.opposite(direction)
	if choices.size() > 1:
		choices.erase(reverse)
	if choices.is_empty():
		return reverse

	var target := _target_cell(player_top_left)
	var preferred := _directions_toward_or_away(
		cell, target, choices, state == GhostStateScript.FRIGHTENED
	)
	if preferred.is_empty():
		if choices.has(MazeDirectionScript.UP) and choices.has(MazeDirectionScript.DOWN):
			preferred = [
				MazeDirectionScript.UP if rng.randi_range(0, 1) == 0 else MazeDirectionScript.DOWN
			]
		elif choices.has(MazeDirectionScript.LEFT) and choices.has(MazeDirectionScript.RIGHT):
			preferred = [
				MazeDirectionScript.LEFT if rng.randi_range(0, 1) == 0 else MazeDirectionScript.RIGHT
			]
		else:
			preferred = choices.duplicate()

	if state == GhostStateScript.HUNTING and reached_target:
		var random_max: int = DifficultyRulesScript.random_override_max(difficulty)
		if random_max >= 0 and rng.randi_range(0, random_max) == 1:
			var selected_index := rng.randi_range(0, 3)
			var available_index := 0
			for candidate in DIRECTION_ORDER:
				if not choices.has(candidate):
					continue
				if available_index == selected_index:
					return candidate
				available_index += 1
			return choices[0]

	if difficulty >= DifficultyRulesScript.Level.HARD and _has_both_axes(preferred):
		var delta := target - cell
		if absi(delta.x) < absi(delta.y):
			preferred = preferred.filter(
				func(value: int) -> bool:
					return value in [MazeDirectionScript.UP, MazeDirectionScript.DOWN]
			)
		else:
			preferred = preferred.filter(
				func(value: int) -> bool:
					return value in [MazeDirectionScript.LEFT, MazeDirectionScript.RIGHT]
			)

	for candidate in DIRECTION_ORDER:
		if preferred.has(candidate):
			return candidate
	return choices[0]


func _directions_toward_or_away(
	cell: Vector2i, target: Vector2i, choices: Array[int], away: bool
) -> Array[int]:
	var result: Array[int] = []
	var delta := target - cell
	var horizontal := MazeDirectionScript.RIGHT if delta.x > 0 else MazeDirectionScript.LEFT
	var vertical := MazeDirectionScript.DOWN if delta.y > 0 else MazeDirectionScript.UP
	if away:
		horizontal = MazeDirectionScript.opposite(horizontal)
		vertical = MazeDirectionScript.opposite(vertical)
	if delta.x != 0 and choices.has(horizontal):
		result.append(horizontal)
	if delta.y != 0 and choices.has(vertical):
		result.append(vertical)
	return result


func _has_both_axes(choices: Array[int]) -> bool:
	var horizontal := choices.has(MazeDirectionScript.LEFT) or choices.has(MazeDirectionScript.RIGHT)
	var vertical := choices.has(MazeDirectionScript.UP) or choices.has(MazeDirectionScript.DOWN)
	return horizontal and vertical


func _citadel_direction(cell: Vector2i, target: Vector2i) -> int:
	# Q/R form a three-cell home row below the maze entry. Ghosts route
	# horizontally through R, then vertically through the entry.
	var center: Vector2i = topology.find_marker("R")
	if target.y < cell.y:
		if cell.x < center.x:
			return MazeDirectionScript.RIGHT
		if cell.x > center.x:
			return MazeDirectionScript.LEFT
		return MazeDirectionScript.UP
	if target.x < cell.x:
		return MazeDirectionScript.LEFT
	if target.x > cell.x:
		return MazeDirectionScript.RIGHT
	if target.y > cell.y:
		return MazeDirectionScript.DOWN
	return MazeDirectionScript.NONE


func _target_cell(player_top_left: Vector2) -> Vector2i:
	if state == GhostStateScript.RETURNING:
		return home_cell if reached_target else entry_cell
	if state == GhostStateScript.HUNTING and not reached_target:
		return entry_cell
	return Vector2i(
		roundi(float(player_top_left.x - PlayerMotionScript.GRID_ORIGIN.x) / PlayerMotionScript.GRID_SPACING),
		roundi(float(player_top_left.y - PlayerMotionScript.GRID_ORIGIN.y) / PlayerMotionScript.GRID_SPACING),
	)


func _distance_after(cell: Vector2i, candidate: int, target: Vector2i) -> int:
	var next := cell + MazeDirectionScript.vector(candidate)
	return absi(next.x - target.x) + absi(next.y - target.y)


func _direction_between(from: Vector2i, to: Vector2i) -> int:
	var delta := to - from
	if delta == Vector2i.LEFT:
		return MazeDirectionScript.LEFT
	if delta == Vector2i.RIGHT:
		return MazeDirectionScript.RIGHT
	if delta == Vector2i.UP:
		return MazeDirectionScript.UP
	if delta == Vector2i.DOWN:
		return MazeDirectionScript.DOWN
	return MazeDirectionScript.NONE


func _wrap_screen() -> void:
	if position.x <= 1:
		position.x = PlayerMotionScript.MAX_X
	elif position.x >= 607:
		position.x = PlayerMotionScript.MIN_X
	if position.y <= 3:
		position.y = PlayerMotionScript.MAX_Y
	elif position.y >= 477:
		position.y = PlayerMotionScript.MIN_Y

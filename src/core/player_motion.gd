class_name PlayerMotion
extends RefCounted

const MazeDirectionScript := preload("res://src/core/direction.gd")

# Constants recovered from PMSprite and PMPlayer in Pac the Man X 1.5.1a.
const GRID_ORIGIN := Vector2i(40, 42)
const GRID_SPACING := 44
const MOVE_UNIT := 0.5
const NORMAL_SUBSTEPS := 10
const DOUBLE_SPEED_SUBSTEPS := 14
const MIN_X := 2
const MAX_X := 606
const MIN_Y := 4
const MAX_Y := 476

var topology
var position := Vector2(GRID_ORIGIN)
var direction := MazeDirectionScript.NONE
var requested_direction := MazeDirectionScript.NONE
var frame := 0
var citadel_entry := Vector2i(-1, -1)
var citadel_cell := Vector2i(-1, -1)


func _init(maze = null, start_cell := Vector2i.ZERO) -> void:
	topology = maze
	position = Vector2(pixel_for_cell(start_cell))
	if topology != null:
		citadel_entry = topology.citadel_entry()
		citadel_cell = topology.find_marker("R")


func request(value: int) -> void:
	if value in [
		MazeDirectionScript.LEFT,
		MazeDirectionScript.RIGHT,
		MazeDirectionScript.UP,
		MazeDirectionScript.DOWN,
	]:
		requested_direction = value
		# A 180-degree reversal does not need a maze node: the player is
		# retracing the corridor segment it just traversed. Waiting for the next
		# node made reversals appear to fail depending on where the key was hit.
		if value == MazeDirectionScript.opposite(direction):
			direction = value


func release(value: int) -> void:
	if requested_direction == value:
		requested_direction = MazeDirectionScript.NONE


func step(double_speed := false) -> void:
	var count := DOUBLE_SPEED_SUBSTEPS if double_speed else NORMAL_SUBSTEPS
	for ignored in count:
		_step_pixel()
	frame += 1


func current_cell() -> Vector2i:
	return Vector2i(
		roundi(float(position.x - GRID_ORIGIN.x) / GRID_SPACING),
		roundi(float(position.y - GRID_ORIGIN.y) / GRID_SPACING),
	)


func is_on_node() -> bool:
	return (
		is_zero_approx(fposmod(position.x - GRID_ORIGIN.x, GRID_SPACING))
		and is_zero_approx(fposmod(position.y - GRID_ORIGIN.y, GRID_SPACING))
	)


static func pixel_for_cell(cell: Vector2i) -> Vector2i:
	return GRID_ORIGIN + cell * GRID_SPACING


func _step_pixel() -> void:
	if is_on_node():
		var cell := current_cell()
		if requested_direction != MazeDirectionScript.NONE and _direction_allowed(cell, requested_direction):
			direction = requested_direction
		if direction == MazeDirectionScript.NONE or not _direction_allowed(cell, direction):
			return
	position += Vector2(MazeDirectionScript.vector(direction)) * MOVE_UNIT
	_wrap_screen()


func _direction_allowed(cell: Vector2i, value: int) -> bool:
	if cell == citadel_entry and cell + MazeDirectionScript.vector(value) == citadel_cell:
		return false
	return topology.direction_allowed(cell, value)


func _wrap_screen() -> void:
	if position.x <= 1:
		position.x = MAX_X
	elif position.x >= 607:
		position.x = MIN_X
	if position.y <= 3:
		position.y = MAX_Y
	elif position.y >= 477:
		position.y = MIN_Y

class_name ExtraMotion
extends RefCounted

const MazeDirectionScript := preload("res://src/core/direction.gd")
const PlayerMotionScript := preload("res://src/core/player_motion.gd")

const SUBSTEPS := 2
const LIFETIME_SECONDS := 10
const COLLISION_AXIS_DISTANCE := 10
const ANIMATION_FPS := 6
const ANIMATION_SEQUENCE: Array[int] = [1, 2, 1, 0]
const ROTATION_STEP_DEGREES := 3.0
const ROTATION_LIMIT_DEGREES := 25.0

var topology
var position := Vector2.ZERO
var direction := MazeDirectionScript.NONE
var extra_number := 0
var remaining_ticks := 0
var frame := 0
var ticks_per_second := 60
var rotation_degrees := 0.0
var rotation_direction := 1.0
var rng := RandomNumberGenerator.new()


func _init(maze = null, start_cell := Vector2i.ZERO, number := 0, ticks_per_second := 60, seed := -1) -> void:
	topology = maze
	position = Vector2(PlayerMotionScript.pixel_for_cell(start_cell))
	extra_number = clampi(number, 0, 4)
	self.ticks_per_second = maxi(ticks_per_second, 1)
	remaining_ticks = LIFETIME_SECONDS * self.ticks_per_second
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()


func step() -> void:
	remaining_ticks = maxi(remaining_ticks - 1, 0)
	for ignored in SUBSTEPS:
		_step_pixel()
	rotation_degrees += ROTATION_STEP_DEGREES * rotation_direction
	if rotation_degrees >= ROTATION_LIMIT_DEGREES:
		rotation_degrees = ROTATION_LIMIT_DEGREES
		rotation_direction = -1.0
	elif rotation_degrees <= -ROTATION_LIMIT_DEGREES:
		rotation_degrees = -ROTATION_LIMIT_DEGREES
		rotation_direction = 1.0
	frame += 1


func animation_frame() -> int:
	var ticks_per_frame := maxi(roundi(float(ticks_per_second) / ANIMATION_FPS), 1)
	return ANIMATION_SEQUENCE[(frame / ticks_per_frame) % ANIMATION_SEQUENCE.size()]


func expired() -> bool:
	return remaining_ticks == 0


func collides(player_position: Vector2) -> bool:
	return (
		absi(position.x - player_position.x) <= COLLISION_AXIS_DISTANCE
		and absi(position.y - player_position.y) <= COLLISION_AXIS_DISTANCE
	)


func current_cell() -> Vector2i:
	return Vector2i(
		roundi(float(position.x - PlayerMotionScript.GRID_ORIGIN.x) / PlayerMotionScript.GRID_SPACING),
		roundi(float(position.y - PlayerMotionScript.GRID_ORIGIN.y) / PlayerMotionScript.GRID_SPACING),
	)


func is_on_node() -> bool:
	return (
		is_zero_approx(fposmod(position.x - PlayerMotionScript.GRID_ORIGIN.x, PlayerMotionScript.GRID_SPACING))
		and is_zero_approx(fposmod(position.y - PlayerMotionScript.GRID_ORIGIN.y, PlayerMotionScript.GRID_SPACING))
	)


func _step_pixel() -> void:
	if is_on_node():
		var choices: Array[int] = topology.directions_at(current_cell())
		var reverse := MazeDirectionScript.opposite(direction)
		if choices.size() > 1:
			choices.erase(reverse)
		if choices.is_empty():
			direction = reverse
		else:
			direction = choices[rng.randi_range(0, choices.size() - 1)]
	if direction == MazeDirectionScript.NONE:
		return
	position += Vector2(MazeDirectionScript.vector(direction)) * PlayerMotionScript.MOVE_UNIT
	if position.x <= 1:
		position.x = PlayerMotionScript.MAX_X
	elif position.x >= 607:
		position.x = PlayerMotionScript.MIN_X
	if position.y <= 3:
		position.y = PlayerMotionScript.MAX_Y
	elif position.y >= 477:
		position.y = PlayerMotionScript.MIN_Y

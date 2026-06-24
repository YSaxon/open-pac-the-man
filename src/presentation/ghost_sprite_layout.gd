class_name GhostSpriteLayout
extends RefCounted

const MazeDirectionScript := preload("res://src/core/direction.gd")
const GhostStateScript := preload("res://src/core/ghost_state.gd")
const FRAME_SIZE := 32


static func frame_cell(ghost_number: int, direction: int, frame: int, state: int, frightened_ticks := 0) -> Vector2i:
	if state == GhostStateScript.FRIGHTENED or state == GhostStateScript.FRIGHTENED_WAITING:
		var blinking_offset := 3 if frightened_ticks <= 40 and posmod(frame, 2) == 0 else 0
		return Vector2i(blinking_offset + posmod(frame, 3), 0)
	if state == GhostStateScript.RETURNING:
		return Vector2i(_direction_column(direction), 8)
	var row := posmod(ghost_number, 4) * 2
	if direction == MazeDirectionScript.UP or direction == MazeDirectionScript.DOWN:
		row += 1
	var direction_half := 0
	if direction == MazeDirectionScript.RIGHT or direction == MazeDirectionScript.DOWN:
		direction_half = 3
	return Vector2i(direction_half + posmod(frame, 3), row)


static func region(ghost_number: int, direction: int, frame: int, state: int, frightened_ticks := 0) -> Rect2:
	var cell := frame_cell(ghost_number, direction, frame, state, frightened_ticks)
	return Rect2(cell * FRAME_SIZE, Vector2i(FRAME_SIZE, FRAME_SIZE))


static func _direction_column(direction: int) -> int:
	match direction:
		MazeDirectionScript.RIGHT:
			return 1
		MazeDirectionScript.UP:
			return 2
		MazeDirectionScript.DOWN:
			return 3
	return 0

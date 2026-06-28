class_name PlayerSpriteLayout
extends RefCounted

const MazeDirectionScript := preload("res://src/core/direction.gd")
const FRAME_SIZE := 32
const HALF_CYCLE := 8
const FULL_CYCLE := 14


static func frame_cell(direction: int, animation_frame: int) -> Vector2i:
	var phase := posmod(animation_frame, FULL_CYCLE)
	if phase >= HALF_CYCLE:
		phase = FULL_CYCLE - phase
	match direction:
		MazeDirectionScript.LEFT:
			return Vector2i(phase, 0)
		MazeDirectionScript.RIGHT:
			return Vector2i(15 - phase, 0)
		MazeDirectionScript.DOWN:
			return Vector2i(7 - phase, 1)
		MazeDirectionScript.UP:
			return Vector2i(15 - phase, 1)
	return Vector2i(15 - phase, 0)


static func region(direction: int, animation_frame: int) -> Rect2:
	return Rect2(Vector2(frame_cell(direction, animation_frame) * FRAME_SIZE), Vector2(FRAME_SIZE, FRAME_SIZE))

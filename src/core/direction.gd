class_name MazeDirection
extends RefCounted

const NONE := 0
const LEFT := 1
const RIGHT := 2
const UP := 4
const DOWN := 8


static func vector(value: int) -> Vector2i:
	match value:
		LEFT:
			return Vector2i.LEFT
		RIGHT:
			return Vector2i.RIGHT
		UP:
			return Vector2i.UP
		DOWN:
			return Vector2i.DOWN
	return Vector2i.ZERO


static func opposite(value: int) -> int:
	match value:
		LEFT:
			return RIGHT
		RIGHT:
			return LEFT
		UP:
			return DOWN
		DOWN:
			return UP
	return NONE


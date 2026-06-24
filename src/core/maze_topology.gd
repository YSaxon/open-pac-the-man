class_name MazeTopology
extends RefCounted

var rows: PackedStringArray


func _init(tile_rows: PackedStringArray = PackedStringArray()) -> void:
	rows = tile_rows


func width() -> int:
	return 0 if rows.is_empty() else rows[0].length()


func height() -> int:
	return rows.size()


func mask_at(cell: Vector2i) -> int:
	if cell.y < 0 or cell.y >= height() or cell.x < 0 or cell.x >= width():
		return 0
	var value := rows[cell.y].unicode_at(cell.x) - "A".unicode_at(0)
	# The original accepts values through R (17), then applies a direction bit test.
	return value if value >= 0 and value <= 17 else 0


func direction_allowed(cell: Vector2i, direction: int) -> bool:
	return (mask_at(cell) & direction) != 0


func directions_at(cell: Vector2i) -> Array[int]:
	var result: Array[int] = []
	for direction in [1, 2, 4, 8]:
		if direction_allowed(cell, direction):
			result.append(direction)
	return result


func find_marker(marker: String) -> Vector2i:
	if marker.length() != 1:
		return Vector2i(-1, -1)
	for y in height():
		var x := rows[y].find(marker)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


func citadel_entry() -> Vector2i:
	var citadel := find_marker("R")
	if citadel.x < 0:
		return citadel
	# R is the citadel's internal target. The entry is the ordinary maze node
	# whose path points into it; in the shipped levels this is directly above.
	var candidates := [
		[citadel + Vector2i.LEFT, 2],
		[citadel + Vector2i.RIGHT, 1],
		[citadel + Vector2i.UP, 8],
		[citadel + Vector2i.DOWN, 4],
	]
	for candidate in candidates:
		var cell: Vector2i = candidate[0]
		var mask := mask_at(cell)
		if mask > 0 and mask <= 15 and direction_allowed(cell, candidate[1]):
			return cell
	return Vector2i(-1, -1)


func shortest_direction(start: Vector2i, target: Vector2i) -> int:
	if start == target or mask_at(start) <= 0 or mask_at(target) <= 0:
		return 0
	var frontier: Array[Vector2i] = [start]
	var first_step: Dictionary = {start: 0}
	var cursor := 0
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		for direction in directions_at(current):
			var neighbor := current + _direction_vector(direction)
			neighbor = _wrap_cell(neighbor)
			if first_step.has(neighbor):
				continue
			var mask := mask_at(neighbor)
			if mask <= 0 or mask > 15:
				continue
			var initial: int = direction if current == start else first_step[current]
			if neighbor == target:
				return initial
			first_step[neighbor] = initial
			frontier.append(neighbor)
	return 0


func _wrap_cell(cell: Vector2i) -> Vector2i:
	var wrapped := cell
	if wrapped.x < 0:
		wrapped.x = width() - 1
	elif wrapped.x >= width():
		wrapped.x = 0
	if wrapped.y < 0:
		wrapped.y = height() - 1
	elif wrapped.y >= height():
		wrapped.y = 0
	return wrapped


func _direction_vector(direction: int) -> Vector2i:
	match direction:
		1:
			return Vector2i.LEFT
		2:
			return Vector2i.RIGHT
		4:
			return Vector2i.UP
		8:
			return Vector2i.DOWN
	return Vector2i.ZERO

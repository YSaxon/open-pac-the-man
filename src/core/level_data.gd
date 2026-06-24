class_name LevelData
extends RefCounted

const EXPECTED_WIDTH := 13

var rows: PackedStringArray
var background := ""
var citadel := ""
var tileset := ""
var wait_time := 0
var item := 0
var wall_color := Color.WHITE
var player_one := Vector2i.ZERO
var player_two := Vector2i.ZERO
var super_pellets: Array[Vector2i] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if rows.is_empty():
		errors.append("Level has no tile rows")
	for index in rows.size():
		if rows[index].length() != EXPECTED_WIDTH:
			errors.append("Row %d has width %d; expected %d" % [index, rows[index].length(), EXPECTED_WIDTH])
	if tileset.is_empty():
		errors.append("Level has no tileset")
	if citadel.is_empty():
		errors.append("Level has no citadel")
	if wait_time < 0:
		errors.append("Level wait time cannot be negative")
	return errors


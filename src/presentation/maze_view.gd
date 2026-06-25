class_name MazeView
extends Node2D

const CELL_SIZE := 44.0
const HALF_CELL := CELL_SIZE / 2.0
const SHADOW_WIDTH := 33.0
const GLOW_WIDTH := 34.0
const OUTER_WALL_WIDTH := 29.0
const WALL_FACE_WIDTH := 27.0
const WALL_GAP_WIDTH := 25.0
const INNER_WALL_WIDTH := 21.0
const GLASS_HIGHLIGHT_WIDTH := 19.5
const GLASS_LOWLIGHT_WIDTH := 19.5
const CORRIDOR_WIDTH := 17.0
const SHADOW_OFFSET := Vector2(2.0, 2.0)
const HIGHLIGHT_OFFSET := Vector2(-1.25, -1.25)
const LOWLIGHT_OFFSET := Vector2(1.25, 1.25)

var level
var origin := Vector2.ZERO
var tile_texture: Texture2D
var citadel_texture: Texture2D


func set_artwork(tiles: Texture2D, citadel: Texture2D) -> void:
	tile_texture = tiles
	citadel_texture = citadel
	queue_redraw()


func show_level(value, top_left: Vector2) -> void:
	level = value
	origin = top_left
	queue_redraw()


func _draw() -> void:
	if level == null:
		return
	# The raw tile sheet contains 11-pixel wall primitives, not 44-pixel cell
	# textures. Layering the union of all path strokes recreates the continuous
	# pair of walls surrounding the playable corridor. The offset highlight and
	# lowlight strokes approximate the original Aqua/glass shading without
	# changing the underlying topology.
	var glow: Color = level.wall_color
	glow.a = 0.20
	var shadow := Color(0.0, 0.0, 0.0, 0.42)
	var outer: Color = level.wall_color.darkened(0.44)
	var face: Color = level.wall_color.darkened(0.10)
	var gap := Color("02040a")
	var inner: Color = level.wall_color.lightened(0.16)
	var highlight: Color = level.wall_color.lightened(0.76)
	highlight.a = 0.46
	var lowlight: Color = level.wall_color.darkened(0.54)
	lowlight.a = 0.54
	_draw_path_layer(SHADOW_WIDTH, shadow, SHADOW_OFFSET)
	_draw_path_layer(GLOW_WIDTH, glow)
	_draw_path_layer(OUTER_WALL_WIDTH, outer)
	_draw_path_layer(WALL_FACE_WIDTH, face)
	_draw_path_layer(WALL_GAP_WIDTH, gap)
	_draw_path_layer(INNER_WALL_WIDTH, inner)
	_draw_path_layer(GLASS_LOWLIGHT_WIDTH, lowlight, LOWLIGHT_OFFSET)
	_draw_path_layer(GLASS_HIGHLIGHT_WIDTH, highlight, HIGHLIGHT_OFFSET)
	_draw_path_layer(CORRIDOR_WIDTH, Color("000000"))
	if citadel_texture != null:
		_draw_citadel()


func _draw_path_layer(width: float, color: Color, offset := Vector2.ZERO) -> void:
	for y in level.rows.size():
		var row: String = level.rows[y]
		for x in row.length():
			var mask := row.unicode_at(x) - "A".unicode_at(0)
			if mask <= 0 or mask > 15:
				continue
			var cell := Vector2i(x, y)
			var center := _cell_center(cell) + offset
			for direction in [1, 2, 4, 8]:
				if mask & direction:
					draw_line(center, _path_endpoint(cell, center, direction, offset), color, width, true)
	# Round caps at nodes make turns and intersections one continuous contour.
	for y in level.rows.size():
		var row: String = level.rows[y]
		for x in row.length():
			var mask := row.unicode_at(x) - "A".unicode_at(0)
			if mask > 0 and mask <= 15:
				draw_circle(_cell_center(Vector2i(x, y)) + offset, width / 2.0, color, true, -1.0, true)


func _path_endpoint(cell: Vector2i, center: Vector2, direction: int, offset := Vector2.ZERO) -> Vector2:
	match direction:
		1:
			return Vector2(offset.x, center.y) if cell.x == 0 else center + Vector2(-HALF_CELL, 0.0)
		2:
			return Vector2(640.0 + offset.x, center.y) if cell.x == level.rows[cell.y].length() - 1 else center + Vector2(HALF_CELL, 0.0)
		4:
			return center + Vector2(0.0, -HALF_CELL)
		8:
			return center + Vector2(0.0, HALF_CELL)
	return center


func _draw_citadel() -> void:
	for y in level.rows.size():
		var row: String = level.rows[y]
		for x in row.length():
			if row.substr(x, 1) in ["Q", "R"]:
				draw_texture_rect(
					citadel_texture,
					Rect2(origin + Vector2(x, y) * CELL_SIZE, Vector2(3, 2) * CELL_SIZE),
					false,
					level.wall_color
				)
				return


func _cell_center(cell: Vector2i) -> Vector2:
	return origin + Vector2(cell) * CELL_SIZE + Vector2(HALF_CELL, HALF_CELL)


func position_for_cell(cell: Vector2i) -> Vector2:
	return _cell_center(cell)

class_name MazeView
extends Node2D

const CELL_SIZE := 44.0
const HALF_CELL := CELL_SIZE / 2.0
const SHADOW_OFFSET := Vector2(2.0, 2.0)
const HIGHLIGHT_OFFSET := Vector2(-1.25, -1.25)
const PATH_HALF_WIDTH := 15.0
const NEON_SHADOW_WIDTH := 8.0
const NEON_GLOW_WIDTH := 10.0
const NEON_FACE_WIDTH := 5.0
const NEON_HIGHLIGHT_WIDTH := 2.0
const VIEWPORT_SIZE := Vector2i(640, 480)
const WALL_TEXTURE_PADDING := 8.0

var level
var origin := Vector2.ZERO
var background_texture: Texture2D
var tile_texture: Texture2D
var citadel_texture: Texture2D
var barrier_texture: Texture2D
var background_fill_texture: Texture2D
var wall_texture: Texture2D
var solid_fill_texture: Texture2D
var corridor_texture: Texture2D
var wall_signature := ""


func set_artwork(tiles: Texture2D, citadel: Texture2D, barrier: Texture2D = null, background: Texture2D = null) -> void:
	tile_texture = tiles
	citadel_texture = citadel
	barrier_texture = barrier
	background_texture = background
	background_fill_texture = null
	queue_redraw()


func show_level(value, top_left: Vector2) -> void:
	level = value
	origin = top_left
	background_fill_texture = null
	wall_texture = null
	solid_fill_texture = null
	corridor_texture = null
	wall_signature = ""
	queue_redraw()


func _draw() -> void:
	if level == null:
		return
	# The original board keeps the level/background texture visible and overlays
	# antialiased neon wall primitives. Reconstruct that as a single wall mask
	# from the recovered 44 px maze graph so corners and junctions join cleanly.
	_ensure_wall_texture()
	if background_fill_texture != null:
		draw_texture(background_fill_texture, Vector2.ZERO)
	if corridor_texture != null:
		draw_texture(corridor_texture, Vector2.ZERO, Color(0.0, 0.0, 0.0, 0.88))
	if solid_fill_texture != null:
		var fill_color: Color = level.wall_color
		fill_color.a = 0.12
		draw_texture(solid_fill_texture, Vector2.ZERO, fill_color)
	var glow: Color = level.wall_color
	glow = glow.lightened(0.24)
	glow.a = 0.34
	var shadow := Color(0.0, 0.0, 0.0, 0.30)
	var face: Color = level.wall_color.lightened(0.46)
	face.a = 0.92
	var highlight := Color(1.0, 1.0, 1.0, 0.16)
	if wall_texture != null:
		draw_texture(wall_texture, SHADOW_OFFSET, shadow)
		draw_texture(wall_texture, Vector2.ZERO, glow)
		draw_texture(wall_texture, Vector2.ZERO, face)
		draw_texture(wall_texture, HIGHLIGHT_OFFSET, highlight)
	if citadel_texture != null:
		_draw_citadel()
	if barrier_texture != null:
		_draw_barrier()


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


func _ensure_wall_texture() -> void:
	var signature := "%s|%s" % [str(origin), "|".join(level.rows)]
	if wall_texture != null and wall_signature == signature:
		return
	var distances := PackedFloat32Array()
	distances.resize(VIEWPORT_SIZE.x * VIEWPORT_SIZE.y)
	distances.fill(1_000_000.0)
	for segment in _wall_segments():
		_update_corridor_distance(distances, segment[0], segment[1])
	var source_background: Image = null
	if background_texture != null:
		source_background = background_texture.get_image()
	var wall_image := Image.create(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
	var background_fill_image := Image.create(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
	var fill_image := Image.create(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
	var corridor_image := Image.create(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
	wall_image.fill(Color.TRANSPARENT)
	background_fill_image.fill(Color.TRANSPARENT)
	fill_image.fill(Color.TRANSPARENT)
	corridor_image.fill(Color.TRANSPARENT)
	for y in VIEWPORT_SIZE.y:
		for x in VIEWPORT_SIZE.x:
			var distance := distances[y * VIEWPORT_SIZE.x + x]
			if distance < PATH_HALF_WIDTH - 2.0:
				corridor_image.set_pixel(x, y, Color.WHITE)
			var non_playable := distance > PATH_HALF_WIDTH + 5.0 and _inside_level_bounds(Vector2i(x, y))
			if non_playable:
				fill_image.set_pixel(x, y, Color.WHITE)
				if source_background != null and source_background.get_width() > 0 and source_background.get_height() > 0:
					background_fill_image.set_pixel(
						x,
						y,
						source_background.get_pixel(x % source_background.get_width(), y % source_background.get_height())
					)
			var alpha := _wall_alpha(distance)
			if alpha > 0.0:
				wall_image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	wall_texture = ImageTexture.create_from_image(wall_image)
	background_fill_texture = ImageTexture.create_from_image(background_fill_image)
	solid_fill_texture = ImageTexture.create_from_image(fill_image)
	corridor_texture = ImageTexture.create_from_image(corridor_image)
	wall_signature = signature


func _wall_segments() -> Array:
	var result: Array = []
	for y in level.rows.size():
		var row: String = level.rows[y]
		for x in row.length():
			var mask := row.unicode_at(x) - "A".unicode_at(0)
			if mask <= 0 or mask > 15:
				continue
			var cell := Vector2i(x, y)
			var center := _cell_center(cell)
			if mask & 2:
				result.append([center, _path_endpoint(cell, center, 2)])
			if mask & 8:
				result.append([center, _path_endpoint(cell, center, 8)])
			if mask & 1 and cell.x == 0:
				result.append([center, _path_endpoint(cell, center, 1)])
	return result


func _update_corridor_distance(distances: PackedFloat32Array, start: Vector2, end: Vector2) -> void:
	var min_x := maxi(int(floor(minf(start.x, end.x) - PATH_HALF_WIDTH - WALL_TEXTURE_PADDING)), 0)
	var max_x := mini(int(ceil(maxf(start.x, end.x) + PATH_HALF_WIDTH + WALL_TEXTURE_PADDING)), VIEWPORT_SIZE.x - 1)
	var min_y := maxi(int(floor(minf(start.y, end.y) - PATH_HALF_WIDTH - WALL_TEXTURE_PADDING)), 0)
	var max_y := mini(int(ceil(maxf(start.y, end.y) + PATH_HALF_WIDTH + WALL_TEXTURE_PADDING)), VIEWPORT_SIZE.y - 1)
	var axis := end - start
	var length_squared := axis.length_squared()
	if length_squared <= 0.0:
		return
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var point := Vector2(x + 0.5, y + 0.5)
			var projection := clampf((point - start).dot(axis) / length_squared, 0.0, 1.0)
			var closest := start + axis * projection
			var distance := point.distance_to(closest)
			var index := y * VIEWPORT_SIZE.x + x
			if distance < distances[index]:
				distances[index] = distance


func _wall_alpha(distance_to_centerline: float) -> float:
	var edge_distance := absf(distance_to_centerline - PATH_HALF_WIDTH)
	if edge_distance <= 0.75:
		return 0.95
	if edge_distance <= 2.5:
		return lerpf(0.95, 0.56, (edge_distance - 0.75) / 1.75)
	if edge_distance <= 5.5:
		return lerpf(0.30, 0.0, (edge_distance - 2.5) / 3.0)
	return 0.0


func _inside_level_bounds(point: Vector2i) -> bool:
	if level.rows.is_empty():
		return false
	var size := Vector2(level.rows[0].length(), level.rows.size()) * CELL_SIZE
	return (
		point.x >= int(origin.x)
		and point.y >= int(origin.y)
		and point.x < int(origin.x + size.x)
		and point.y < int(origin.y + size.y)
	)


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


func _draw_barrier() -> void:
	for y in level.rows.size():
		var row: String = level.rows[y]
		for x in row.length():
			if row.substr(x, 1) == "R":
				var entry_cell := Vector2i(x, y - 1)
				var center := _cell_center(entry_cell) + Vector2(0, HALF_CELL - 4.0)
				draw_texture(barrier_texture, center - Vector2(20, 4))
				return


func _cell_center(cell: Vector2i) -> Vector2:
	return origin + Vector2(cell) * CELL_SIZE + Vector2(HALF_CELL, HALF_CELL)


func position_for_cell(cell: Vector2i) -> Vector2:
	return _cell_center(cell)

class_name MazeView
extends Node2D

const CELL_SIZE := 44.0
const HALF_CELL := CELL_SIZE / 2.0
const SHADOW_OFFSET := Vector2(2.0, 2.0)
const HIGHLIGHT_OFFSET := Vector2(-1.25, -1.25)
const VIEWPORT_SIZE := Vector2i(640, 480)
const PATH_HALF_WIDTH := 15.0
const NEON_GLOW_WIDTH := 10.0
const NEON_FACE_WIDTH := 5.0

# Tile sheet is 33×77 px: 3 columns × 7 rows of 11×11 frames.
# Frame layout (row-major):
#   0=TL-outer  1=top-edge   2=TR-outer
#   3=left-edge 4=interior   5=right-edge
#   6=BL-outer  7=bot-edge   8=BR-outer
#   9=TL-inset 10=TR-inset 11=fill
#  12=BL-inset 13=BR-inset 14=fill
#  15-20 = fill variants (unused here)
const TILE_COLS := 3
const TILE_SIZE := 11
const SUBTILES_PER_CELL := 4

const FRAME_NONE := -1
const FRAME_OUTER_TOP_LEFT := 0
const FRAME_OUTER_TOP := 1
const FRAME_OUTER_TOP_RIGHT := 2
const FRAME_OUTER_LEFT := 3
const FRAME_OUTER_RIGHT := 5
const FRAME_OUTER_BOTTOM_LEFT := 6
const FRAME_OUTER_BOTTOM := 7
const FRAME_OUTER_BOTTOM_RIGHT := 8
const FRAME_INSET_TOP_LEFT := 9
const FRAME_INSET_TOP_RIGHT := 10
const FRAME_FILL := 11
const FRAME_INSET_BOTTOM_LEFT := 12
const FRAME_INSET_BOTTOM_RIGHT := 13

var level
var origin := Vector2.ZERO
var background_texture: Texture2D
var tile_texture: Texture2D
var citadel_texture: Texture2D
var barrier_texture: Texture2D
var background_fill_texture: Texture2D
var wall_texture: Texture2D
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
	wall_signature = ""
	queue_redraw()


func _draw() -> void:
	if level == null:
		return
	_ensure_wall_texture()
	if background_fill_texture != null:
		draw_texture(background_fill_texture, Vector2.ZERO)
	if wall_texture != null:
		var glow: Color = level.wall_color.lightened(0.24)
		glow.a = 0.34
		var shadow := Color(0.0, 0.0, 0.0, 0.30)
		var face: Color = level.wall_color.lightened(0.46)
		face.a = 0.92
		var highlight := Color(1.0, 1.0, 1.0, 0.16)
		draw_texture(wall_texture, SHADOW_OFFSET, shadow)
		draw_texture(wall_texture, Vector2.ZERO, glow)
		draw_texture(wall_texture, Vector2.ZERO, face)
		draw_texture(wall_texture, HIGHLIGHT_OFFSET, highlight)
	if citadel_texture != null:
		_draw_citadel()
	if barrier_texture != null:
		_draw_barrier()


func _ensure_wall_texture() -> void:
	var signature := "%s|%s" % [str(origin), "|".join(level.rows)]
	if wall_texture != null and wall_signature == signature:
		return

	var source_background: Image = null
	if background_texture != null:
		source_background = background_texture.get_image()
	var playable_subtiles := build_playable_subtiles(level.rows)

	# Background: tile the level texture across the whole board. Blocked
	# subtile regions receive the original wall primitive/lightening overlay
	# below; the background itself is still present under playable corridors.
	var background_fill_image := Image.create(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
	background_fill_image.fill(Color.TRANSPARENT)
	if source_background != null and source_background.get_width() > 0 and source_background.get_height() > 0:
		var bg_w := source_background.get_width()
		var bg_h := source_background.get_height()
		_stamp_board_background(background_fill_image, source_background, bg_w, bg_h)

	# Wall: compose from 11×11 tile primitives around blocked/non-playable
	# subtiles. This renders the obstacle/island field, not the playable graph.
	var wall_image := Image.create(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
	wall_image.fill(Color.TRANSPARENT)
	if tile_texture != null:
		var tile_image := tile_texture.get_image()
		if tile_image != null and tile_image.get_width() >= TILE_COLS * TILE_SIZE and tile_image.get_height() >= 7 * TILE_SIZE:
			var rgba_tile := _as_rgba_alpha(tile_image)
			var frame_grid: Array = build_wall_frame_grid(level.rows)
			_stamp_tile_walls(wall_image, rgba_tile, frame_grid)

	wall_texture = ImageTexture.create_from_image(wall_image)
	background_fill_texture = ImageTexture.create_from_image(background_fill_image)
	wall_signature = signature


# Convert to RGBA8: if the image already has an alpha channel, use it directly.
# For RGB-only images (alpha always 1.0 after _load_wall_mask_texture), fall back to
# pixel luminance as alpha so the glow profile is preserved.
func _as_rgba_alpha(img: Image) -> Image:
	if img.get_format() == Image.FORMAT_RGBA8:
		return img
	var result := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var pixel := img.get_pixel(x, y)
			result.set_pixel(x, y, Color(1.0, 1.0, 1.0, pixel.get_luminance()))
	return result


static func build_playable_subtiles(rows: PackedStringArray) -> Array:
	var result: Array = []
	var height := rows.size() * SUBTILES_PER_CELL
	var width := 0 if rows.is_empty() else rows[0].length() * SUBTILES_PER_CELL
	for ignored_y in height:
		var row := PackedByteArray()
		row.resize(width)
		result.append(row)
	for cy in rows.size():
		var source_row: String = rows[cy]
		for cx in source_row.length():
			var mask := source_row.unicode_at(cx) - "A".unicode_at(0)
			if mask <= 0 or mask > 15:
				continue
			var base_x := cx * SUBTILES_PER_CELL
			var base_y := cy * SUBTILES_PER_CELL
			_mark_playable_subtile(result, base_x + 1, base_y + 1)
			_mark_playable_subtile(result, base_x + 2, base_y + 1)
			_mark_playable_subtile(result, base_x + 1, base_y + 2)
			_mark_playable_subtile(result, base_x + 2, base_y + 2)
			if mask & 1:
				_mark_playable_subtile(result, base_x, base_y + 1)
				_mark_playable_subtile(result, base_x, base_y + 2)
			if mask & 2:
				_mark_playable_subtile(result, base_x + 3, base_y + 1)
				_mark_playable_subtile(result, base_x + 3, base_y + 2)
			if mask & 4:
				_mark_playable_subtile(result, base_x + 1, base_y)
				_mark_playable_subtile(result, base_x + 2, base_y)
			if mask & 8:
				_mark_playable_subtile(result, base_x + 1, base_y + 3)
				_mark_playable_subtile(result, base_x + 2, base_y + 3)
	return result


static func tile_frame_for_blocked_neighbors(
	north_blocked: bool,
	east_blocked: bool,
	south_blocked: bool,
	west_blocked: bool,
	north_west_blocked: bool = true,
	north_east_blocked: bool = true,
	south_east_blocked: bool = true,
	south_west_blocked: bool = true,
	at_top: bool = false,
	at_right: bool = false,
	at_bottom: bool = false,
	at_left: bool = false
) -> int:
	if at_top and at_left:
		return FRAME_OUTER_TOP_LEFT
	if at_top and at_right:
		return FRAME_OUTER_TOP_RIGHT
	if at_bottom and at_left:
		return FRAME_OUTER_BOTTOM_LEFT
	if at_bottom and at_right:
		return FRAME_OUTER_BOTTOM_RIGHT
	if at_top:
		return FRAME_OUTER_TOP
	if at_bottom:
		return FRAME_OUTER_BOTTOM
	if at_left:
		return FRAME_OUTER_LEFT
	if at_right:
		return FRAME_OUTER_RIGHT
	var north_open := not north_blocked
	var east_open := not east_blocked
	var south_open := not south_blocked
	var west_open := not west_blocked
	var north_west_open := not north_west_blocked
	var north_east_open := not north_east_blocked
	var south_east_open := not south_east_blocked
	var south_west_open := not south_west_blocked
	if north_open and west_open:
		return FRAME_INSET_TOP_LEFT
	if north_open and east_open:
		return FRAME_INSET_TOP_RIGHT
	if south_open and west_open:
		return FRAME_INSET_BOTTOM_LEFT
	if south_open and east_open:
		return FRAME_INSET_BOTTOM_RIGHT
	if north_west_open and north_blocked and west_blocked:
		return FRAME_OUTER_BOTTOM_RIGHT
	if north_east_open and north_blocked and east_blocked:
		return FRAME_OUTER_BOTTOM_LEFT
	if south_west_open and south_blocked and west_blocked:
		return FRAME_OUTER_TOP_RIGHT
	if south_east_open and south_blocked and east_blocked:
		return FRAME_OUTER_TOP_LEFT
	if north_open:
		return FRAME_OUTER_BOTTOM
	if south_open:
		return FRAME_OUTER_TOP
	if west_open:
		return FRAME_OUTER_RIGHT
	if east_open:
		return FRAME_OUTER_LEFT
	return FRAME_FILL


static func _mark_playable_subtile(subtiles: Array, sx: int, sy: int) -> void:
	if sy < 0 or sy >= subtiles.size():
		return
	var row: PackedByteArray = subtiles[sy]
	if sx < 0 or sx >= row.size():
		return
	row[sx] = 1


static func _is_playable_subtile(subtiles: Array, sx: int, sy: int) -> bool:
	if sy < 0 or sy >= subtiles.size():
		return false
	var row: PackedByteArray = subtiles[sy]
	if sx < 0 or sx >= row.size():
		return false
	return row[sx] != 0


static func _is_blocked_subtile(subtiles: Array, sx: int, sy: int) -> bool:
	if subtiles.is_empty():
		return false
	if sy < 0 or sy >= subtiles.size():
		return false
	var row: PackedByteArray = subtiles[sy]
	if sx < 0 or sx >= row.size():
		return false
	return row[sx] == 0


static func frame_for_blocked_subtile(subtiles: Array, sx: int, sy: int) -> int:
	if not _is_blocked_subtile(subtiles, sx, sy):
		return FRAME_NONE
	var height := subtiles.size()
	var width := 0 if height == 0 else (subtiles[0] as PackedByteArray).size()
	if sx > 0 and sy > 0 and sx < width - 1 and sy < height - 1:
		return frame_for_surface_profile(surface_profile_for_blocked_subtile(subtiles, sx, sy))
	return _legacy_frame_for_blocked_subtile(subtiles, sx, sy)


static func _legacy_frame_for_blocked_subtile(subtiles: Array, sx: int, sy: int) -> int:
	var height := subtiles.size()
	var width := 0 if height == 0 else (subtiles[0] as PackedByteArray).size()
	return tile_frame_for_blocked_neighbors(
		_is_blocked_subtile(subtiles, sx, sy - 1),
		_is_blocked_subtile(subtiles, sx + 1, sy),
		_is_blocked_subtile(subtiles, sx, sy + 1),
		_is_blocked_subtile(subtiles, sx - 1, sy),
		_is_blocked_subtile(subtiles, sx - 1, sy - 1),
		_is_blocked_subtile(subtiles, sx + 1, sy - 1),
		_is_blocked_subtile(subtiles, sx + 1, sy + 1),
		_is_blocked_subtile(subtiles, sx - 1, sy + 1),
		sy == 0,
		sx == width - 1,
		sy == height - 1,
		sx == 0
	)


static func surface_profile_for_blocked_subtile(subtiles: Array, sx: int, sy: int) -> PackedByteArray:
	if not _is_blocked_subtile(subtiles, sx, sy):
		return PackedByteArray([0, 0, 0, 0])
	# A quadrant is wall surface only when the four blocked/playable samples
	# touching that quadrant are all blocked. Neighboring frames compute their
	# shared edge bits from the same samples, so T-junctions and corners cannot
	# disagree without the source surface field disagreeing.
	var north := _is_blocked_subtile(subtiles, sx, sy - 1)
	var east := _is_blocked_subtile(subtiles, sx + 1, sy)
	var south := _is_blocked_subtile(subtiles, sx, sy + 1)
	var west := _is_blocked_subtile(subtiles, sx - 1, sy)
	var north_west := _is_blocked_subtile(subtiles, sx - 1, sy - 1)
	var north_east := _is_blocked_subtile(subtiles, sx + 1, sy - 1)
	var south_east := _is_blocked_subtile(subtiles, sx + 1, sy + 1)
	var south_west := _is_blocked_subtile(subtiles, sx - 1, sy + 1)
	return PackedByteArray([
		1 if north and west and north_west else 0,
		1 if north and east and north_east else 0,
		1 if south and west and south_west else 0,
		1 if south and east and south_east else 0,
	])


static func frame_surface_profile(frame: int) -> PackedByteArray:
	# Four logical surface bits, row-major: top-left, top-right,
	# bottom-left, bottom-right. 1 means framed/lightened wall surface;
	# 0 means playable/black surface. This is the non-visual contract used
	# to validate that adjacent 11×11 tile primitives join coherently.
	match frame:
		FRAME_NONE:
			return PackedByteArray([0, 0, 0, 0])
		FRAME_OUTER_TOP_LEFT:
			return PackedByteArray([1, 1, 1, 0])
		FRAME_OUTER_TOP:
			return PackedByteArray([1, 1, 0, 0])
		FRAME_OUTER_TOP_RIGHT:
			return PackedByteArray([1, 1, 0, 1])
		FRAME_OUTER_LEFT:
			return PackedByteArray([1, 0, 1, 0])
		FRAME_OUTER_RIGHT:
			return PackedByteArray([0, 1, 0, 1])
		FRAME_OUTER_BOTTOM_LEFT:
			return PackedByteArray([1, 0, 1, 1])
		FRAME_OUTER_BOTTOM:
			return PackedByteArray([0, 0, 1, 1])
		FRAME_OUTER_BOTTOM_RIGHT:
			return PackedByteArray([0, 1, 1, 1])
		FRAME_INSET_TOP_LEFT:
			return PackedByteArray([0, 0, 0, 1])
		FRAME_INSET_TOP_RIGHT:
			return PackedByteArray([0, 0, 1, 0])
		FRAME_FILL:
			return PackedByteArray([1, 1, 1, 1])
		FRAME_INSET_BOTTOM_LEFT:
			return PackedByteArray([0, 1, 0, 0])
		FRAME_INSET_BOTTOM_RIGHT:
			return PackedByteArray([1, 0, 0, 0])
	return PackedByteArray([0, 0, 0, 0])


static func frame_for_surface_profile(profile: PackedByteArray) -> int:
	if profile.size() < 4:
		return FRAME_NONE
	var key := "%d%d%d%d" % [profile[0], profile[1], profile[2], profile[3]]
	match key:
		"0000":
			return FRAME_NONE
		"1110":
			return FRAME_OUTER_TOP_LEFT
		"1100":
			return FRAME_OUTER_TOP
		"1101":
			return FRAME_OUTER_TOP_RIGHT
		"1010":
			return FRAME_OUTER_LEFT
		"0101":
			return FRAME_OUTER_RIGHT
		"1011":
			return FRAME_OUTER_BOTTOM_LEFT
		"0011":
			return FRAME_OUTER_BOTTOM
		"0111":
			return FRAME_OUTER_BOTTOM_RIGHT
		"0001":
			return FRAME_INSET_TOP_LEFT
		"0010":
			return FRAME_INSET_TOP_RIGHT
		"1111":
			return FRAME_FILL
		"0100":
			return FRAME_INSET_BOTTOM_LEFT
		"1000":
			return FRAME_INSET_BOTTOM_RIGHT
	return FRAME_NONE


static func build_wall_frame_grid(rows: PackedStringArray) -> Array:
	var playable_subtiles := build_playable_subtiles(rows)
	var result: Array = []
	for sy in playable_subtiles.size():
		var playable_row: PackedByteArray = playable_subtiles[sy]
		var frame_row := PackedInt32Array()
		frame_row.resize(playable_row.size())
		frame_row.fill(FRAME_NONE)
		for sx in playable_row.size():
			if playable_row[sx] == 0:
				frame_row[sx] = frame_for_blocked_subtile(playable_subtiles, sx, sy)
		result.append(frame_row)
	_apply_warp_boundary_frames(result, rows)
	return result


static func _apply_warp_boundary_frames(frame_grid: Array, rows: PackedStringArray) -> void:
	var height: int = rows.size()
	if height <= 0:
		return
	var width: int = rows[0].length()
	for cy in height:
		var row: String = rows[cy]
		for cx in row.length():
			var mask: int = row.unicode_at(cx) - "A".unicode_at(0)
			if mask <= 0 or mask > 15:
				continue
			var base_x: int = cx * SUBTILES_PER_CELL
			var base_y: int = cy * SUBTILES_PER_CELL
			if cy == 0 and mask & 4:
				var top_frames: Array[int] = warp_boundary_frames(4)
				_set_existing_frame(frame_grid, base_x - 1, base_y, FRAME_OUTER_TOP_RIGHT)
				_set_existing_frame(frame_grid, base_x, base_y, top_frames[0])
				_set_existing_frame(frame_grid, base_x + 3, base_y, top_frames[1])
				_set_existing_frame(frame_grid, base_x + 4, base_y, FRAME_OUTER_TOP_LEFT)
			if cy == height - 1 and mask & 8:
				var bottom_frames: Array[int] = warp_boundary_frames(8)
				_set_existing_frame(frame_grid, base_x - 1, base_y + 3, FRAME_OUTER_BOTTOM_RIGHT)
				_set_existing_frame(frame_grid, base_x, base_y + 3, bottom_frames[0])
				_set_existing_frame(frame_grid, base_x + 3, base_y + 3, bottom_frames[1])
				_set_existing_frame(frame_grid, base_x + 4, base_y + 3, FRAME_OUTER_BOTTOM_LEFT)
			if cx == 0 and mask & 1:
				var left_frames: Array[int] = warp_boundary_frames(1)
				_set_existing_frame(frame_grid, base_x, base_y - 1, FRAME_OUTER_BOTTOM_LEFT)
				_set_existing_frame(frame_grid, base_x, base_y, left_frames[0])
				_set_existing_frame(frame_grid, base_x, base_y + 3, left_frames[1])
				_set_existing_frame(frame_grid, base_x, base_y + 4, FRAME_OUTER_TOP_LEFT)
			if cx == width - 1 and mask & 2:
				var right_frames: Array[int] = warp_boundary_frames(2)
				_set_existing_frame(frame_grid, base_x + 3, base_y - 1, FRAME_OUTER_BOTTOM_RIGHT)
				_set_existing_frame(frame_grid, base_x + 3, base_y, right_frames[0])
				_set_existing_frame(frame_grid, base_x + 3, base_y + 3, right_frames[1])
				_set_existing_frame(frame_grid, base_x + 3, base_y + 4, FRAME_OUTER_TOP_RIGHT)


static func _set_existing_frame(frame_grid: Array, sx: int, sy: int, frame: int) -> void:
	if sy < 0 or sy >= frame_grid.size():
		return
	var row: PackedInt32Array = frame_grid[sy]
	if sx < 0 or sx >= row.size():
		return
	if row[sx] == FRAME_NONE:
		return
	row[sx] = frame


func _stamp_board_background(background_fill_image: Image, source_background: Image, bg_w: int, bg_h: int) -> void:
	for y in VIEWPORT_SIZE.y:
		for x in VIEWPORT_SIZE.x:
			if not _inside_level_bounds(Vector2i(x, y)):
				continue
			background_fill_image.set_pixel(x, y, source_background.get_pixel(x % bg_w, y % bg_h))


func _stamp_tile_walls(wall_image: Image, tile_image: Image, frame_grid: Array) -> void:
	for sy in frame_grid.size():
		var row: PackedInt32Array = frame_grid[sy]
		for sx in row.size():
			if row[sx] == FRAME_NONE:
				continue
			_blit_subtile(row[sx], wall_image, tile_image, sx, sy)


static func warp_boundary_frames(direction: int) -> Array[int]:
	match direction:
		4:
			return [FRAME_INSET_BOTTOM_RIGHT, FRAME_INSET_BOTTOM_LEFT]
		8:
			return [FRAME_INSET_TOP_RIGHT, FRAME_INSET_TOP_LEFT]
		1:
			return [FRAME_OUTER_TOP, FRAME_OUTER_BOTTOM]
		2:
			return [FRAME_OUTER_TOP, FRAME_OUTER_BOTTOM]
	return []


func _blit_subtile(frame: int, wall_image: Image, tile_image: Image, sx: int, sy: int) -> void:
	if frame < 0:
		return
	var src := Rect2i((frame % TILE_COLS) * TILE_SIZE, (frame / TILE_COLS) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	var dest := Vector2i(int(origin.x) + sx * TILE_SIZE, int(origin.y) + sy * TILE_SIZE)
	if dest.x < 0 or dest.y < 0 or dest.x + TILE_SIZE > VIEWPORT_SIZE.x or dest.y + TILE_SIZE > VIEWPORT_SIZE.y:
		return
	wall_image.blit_rect(tile_image, src, dest)


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

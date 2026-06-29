class_name MazeView
extends Node2D

const CELL_SIZE := 44.0
const HALF_CELL := CELL_SIZE / 2.0
const SHADOW_OFFSET := Vector2(2.0, 2.0)
const HIGHLIGHT_OFFSET := Vector2(-1.25, -1.25)
const VIEWPORT_SIZE := Vector2i(640, 480)

# Tile sheet is 33×77 px: 3 columns × 7 rows of 11×11 frames.
# Frame layout (row-major):
#   0=TL-outer  1=top-edge   2=TR-outer
#   3=left-edge 4=interior   5=right-edge
#   6=BL-outer  7=bot-edge   8=BR-outer
#   9=TL-conc  10=TR-conc   11=fill
#  12=BL-conc  13=BR-conc   14=fill
#  15-20 = fill variants (unused here)
const TILE_COLS := 3
const TILE_SIZE := 11

# Corner frame lookup: index = (nw?1:0)|(ne?2:0)|(sw?4:0)|(se?8:0)
# -1 means no tile (transparent — skip the blit).
const CORNER_FRAMES := [-1, 8, 6, 7, 2, 5, -1, 13, 0, -1, 3, 12, 1, 10, 9, -1]

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

	# Background: tile the level texture over ALL pixels inside the level bounds —
	# both playable corridors and enclosed islands use the same background.
	var background_fill_image := Image.create(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
	background_fill_image.fill(Color.TRANSPARENT)
	if source_background != null and source_background.get_width() > 0 and source_background.get_height() > 0:
		var bg_w := source_background.get_width()
		var bg_h := source_background.get_height()
		for y in VIEWPORT_SIZE.y:
			for x in VIEWPORT_SIZE.x:
				if _inside_level_bounds(Vector2i(x, y)):
					background_fill_image.set_pixel(x, y, source_background.get_pixel(x % bg_w, y % bg_h))

	# Wall: compose from 11×11 tile primitives placed at subcell positions.
	var wall_image := Image.create(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
	wall_image.fill(Color.TRANSPARENT)
	if tile_texture != null:
		var tile_image := tile_texture.get_image()
		if tile_image != null and tile_image.get_width() >= TILE_COLS * TILE_SIZE and tile_image.get_height() >= 7 * TILE_SIZE:
			var rgba_tile := _as_rgba_alpha(tile_image)
			_stamp_tile_walls(wall_image, rgba_tile)

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


func _stamp_tile_walls(wall_image: Image, tile_image: Image) -> void:
	for cy in level.rows.size():
		var row: String = level.rows[cy]
		for cx in row.length():
			var mask := row.unicode_at(cx) - "A".unicode_at(0)
			if mask <= 0 or mask > 15:
				continue
			_stamp_cell(wall_image, tile_image, cx, cy, mask)


func _stamp_cell(wall_image: Image, tile_image: Image, cx: int, cy: int, mask: int) -> void:
	var has_up    := (mask & 4) != 0
	var has_down  := (mask & 8) != 0
	var has_left  := (mask & 1) != 0
	var has_right := (mask & 2) != 0

	# Non-corner edge subcells: place straight-edge frame when no connection exists.
	_blit(-1 if has_up    else 1, wall_image, tile_image, cx, cy, 1, 0)
	_blit(-1 if has_up    else 1, wall_image, tile_image, cx, cy, 2, 0)
	_blit(-1 if has_down  else 7, wall_image, tile_image, cx, cy, 1, 3)
	_blit(-1 if has_down  else 7, wall_image, tile_image, cx, cy, 2, 3)
	_blit(-1 if has_left  else 3, wall_image, tile_image, cx, cy, 0, 1)
	_blit(-1 if has_left  else 3, wall_image, tile_image, cx, cy, 0, 2)
	_blit(-1 if has_right else 5, wall_image, tile_image, cx, cy, 3, 1)
	_blit(-1 if has_right else 5, wall_image, tile_image, cx, cy, 3, 2)

	# Corner subcells: determined by the four cells sharing each corner point.
	# Bit encoding for CORNER_FRAMES: bit0=NW, bit1=NE, bit2=SW, bit3=SE.
	# The current navigable cell occupies one of the four quadrants (shown below).

	# TL corner: NW=(cx-1,cy-1)  NE=(cx,cy-1)  SW=(cx-1,cy)  SE=(cx,cy)=current
	_blit(
		CORNER_FRAMES[
			(1 if _is_open(cx-1,cy-1) else 0)
			| (2 if _is_open(cx,cy-1) else 0)
			| (4 if _is_open(cx-1,cy) else 0)
			| 8
		],
		wall_image, tile_image, cx, cy, 0, 0
	)
	# TR corner: NW=(cx,cy-1)  NE=(cx+1,cy-1)  SW=(cx,cy)=current  SE=(cx+1,cy)
	_blit(
		CORNER_FRAMES[
			(1 if _is_open(cx,cy-1) else 0)
			| (2 if _is_open(cx+1,cy-1) else 0)
			| 4
			| (8 if _is_open(cx+1,cy) else 0)
		],
		wall_image, tile_image, cx, cy, 3, 0
	)
	# BL corner: NW=(cx-1,cy)  NE=(cx,cy)=current  SW=(cx-1,cy+1)  SE=(cx,cy+1)
	_blit(
		CORNER_FRAMES[
			(1 if _is_open(cx-1,cy) else 0)
			| 2
			| (4 if _is_open(cx-1,cy+1) else 0)
			| (8 if _is_open(cx,cy+1) else 0)
		],
		wall_image, tile_image, cx, cy, 0, 3
	)
	# BR corner: NW=(cx,cy)=current  NE=(cx+1,cy)  SW=(cx,cy+1)  SE=(cx+1,cy+1)
	_blit(
		CORNER_FRAMES[
			1
			| (2 if _is_open(cx+1,cy) else 0)
			| (4 if _is_open(cx,cy+1) else 0)
			| (8 if _is_open(cx+1,cy+1) else 0)
		],
		wall_image, tile_image, cx, cy, 3, 3
	)


func _is_open(cx: int, cy: int) -> bool:
	if cy < 0 or cy >= level.rows.size():
		return false
	var row: String = level.rows[cy]
	if cx < 0 or cx >= row.length():
		return false
	var m := row.unicode_at(cx) - "A".unicode_at(0)
	return m > 0 and m <= 15


func _blit(frame: int, wall_image: Image, tile_image: Image, cx: int, cy: int, sx: int, sy: int) -> void:
	if frame < 0:
		return
	var src := Rect2i((frame % TILE_COLS) * TILE_SIZE, (frame / TILE_COLS) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	var dest := Vector2i(int(origin.x) + cx * 44 + sx * TILE_SIZE, int(origin.y) + cy * 44 + sy * TILE_SIZE)
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

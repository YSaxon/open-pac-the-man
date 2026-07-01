class_name FontTextView
extends Node2D

const GLYPH_SIZE := Vector2i(16, 26)
const DIGITS := "0123456789"
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const X2_BADGE_COLUMN := 54

var texture: Texture2D
var text := ""
var color_row := 0
var tracking := 0
var _single_glyph_column := -1


func set_font_texture(value: Texture2D) -> void:
	texture = value
	queue_redraw()


func show_text(value: String, row := 0, extra_tracking := 0) -> void:
	text = value.to_upper()
	color_row = maxi(row, 0)
	tracking = extra_tracking
	_single_glyph_column = -1
	queue_redraw()


# The font sheet's last column is a single dedicated "x2" badge glyph, not the
# two characters "X" and "2" — use this instead of show_text("X2", ...) so
# ordinary text (names, scores) never gets silently swapped for the badge.
func show_x2_badge(row := 0) -> void:
	text = ""
	color_row = maxi(row, 0)
	tracking = 0
	_single_glyph_column = X2_BADGE_COLUMN
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	if _single_glyph_column >= 0:
		_draw_glyph(_single_glyph_column, 0.0)
		return
	var cursor := 0.0
	for index in text.length():
		var character := text.substr(index, 1)
		if character == " ":
			cursor += GLYPH_SIZE.x * 0.55 + tracking
			continue
		var column := _glyph_column(character)
		if column < 0:
			cursor += GLYPH_SIZE.x * 0.55 + tracking
			continue
		_draw_glyph(column, cursor)
		cursor += GLYPH_SIZE.x + tracking


func _draw_glyph(column: int, cursor: float) -> void:
	draw_texture_rect_region(
		texture,
		Rect2(Vector2(cursor, 0), Vector2(GLYPH_SIZE)),
		Rect2(Vector2i(column * GLYPH_SIZE.x, color_row * GLYPH_SIZE.y), GLYPH_SIZE),
	)


func _glyph_column(character: String) -> int:
	var digit := DIGITS.find(character)
	if digit >= 0:
		return digit
	var letter := LETTERS.find(character)
	if letter >= 0:
		return 10 + letter
	match character:
		"-":
			return 37
		"+":
			return 38
		"=":
			return 39
	return -1

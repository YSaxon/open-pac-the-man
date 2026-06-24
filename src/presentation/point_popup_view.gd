class_name PointPopupView
extends Node2D

const PointPopupMotionScript := preload("res://src/core/point_popup_motion.gd")

const FRAME_SIZE := Vector2i(18, 21)
const GLYPH_WIDTHS := [16, 12, 16, 16, 18, 16, 16, 16]

var motions: Array = []
var sprites: Array[Sprite2D] = []


func show_points(texture: Texture2D, points: int, collision_position: Vector2, color_row: int) -> void:
	z_index = 8
	var text := str(points)
	var glyphs: Array[int] = []
	var total_width := 0
	for character in text:
		var glyph := _glyph_index(character)
		if glyph < 0:
			continue
		glyphs.append(glyph)
		total_width += GLYPH_WIDTHS[glyph]
	var left := collision_position.x + 16.0 - total_width * 0.5
	for digit_index in glyphs.size():
		var glyph: int = glyphs[digit_index]
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.region_rect = Rect2(
			glyph * FRAME_SIZE.x,
			(color_row % 5) * FRAME_SIZE.y,
			FRAME_SIZE.x,
			FRAME_SIZE.y,
		)
		var motion = PointPopupMotionScript.new(collision_position.y, digit_index)
		sprite.position = Vector2(left + FRAME_SIZE.x * 0.5, motion.y + FRAME_SIZE.y * 0.5)
		add_child(sprite)
		sprites.append(sprite)
		motions.append(motion)
		left += GLYPH_WIDTHS[glyph]


func step_reference_frames(frame_count: int) -> void:
	for ignored in frame_count:
		for index in motions.size():
			motions[index].step()
			sprites[index].position.y = motions[index].y + FRAME_SIZE.y * 0.5
	if expired():
		queue_free()


func expired() -> bool:
	return motions.is_empty() or motions[0].expired()


static func _glyph_index(character: String) -> int:
	if character == "8":
		return 7
	var value := int(character)
	return value if value >= 0 and value <= 6 else -1

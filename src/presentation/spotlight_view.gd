class_name SpotlightView
extends Node2D

const HALF_SIZE := 150.0
const COVER_SIZE := 2000.0

var spot_texture: Texture2D


func show_spot(texture: Texture2D) -> void:
	spot_texture = texture
	queue_redraw()


func follow_player(player_top_left: Vector2) -> void:
	position = player_top_left + Vector2(16, 16)


func _draw() -> void:
	if spot_texture == null:
		return
	var black := Color.BLACK
	draw_rect(Rect2(-COVER_SIZE, -COVER_SIZE, COVER_SIZE - HALF_SIZE, COVER_SIZE * 2.0), black)
	draw_rect(Rect2(HALF_SIZE, -COVER_SIZE, COVER_SIZE - HALF_SIZE, COVER_SIZE * 2.0), black)
	draw_rect(Rect2(-HALF_SIZE, -COVER_SIZE, HALF_SIZE * 2.0, COVER_SIZE - HALF_SIZE), black)
	draw_rect(Rect2(-HALF_SIZE, HALF_SIZE, HALF_SIZE * 2.0, COVER_SIZE - HALF_SIZE), black)
	draw_texture(spot_texture, Vector2(-HALF_SIZE, -HALF_SIZE))

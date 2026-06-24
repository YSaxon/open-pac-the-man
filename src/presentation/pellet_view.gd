class_name PelletView
extends Node2D

const PelletFieldScript := preload("res://src/core/pellet_field.gd")
const SUPER_PELLET_FPS := 15.0

var field
var pellet_texture: Texture2D
var super_pellet_texture: Texture2D
var super_frame := 0
var animation_elapsed := 0.0


func set_artwork(normal: Texture2D, power: Texture2D) -> void:
	pellet_texture = normal
	super_pellet_texture = power
	set_process(power != null)
	queue_redraw()


func show_field(value) -> void:
	field = value
	queue_redraw()


func field_changed() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	animation_elapsed += delta
	var frame_duration := 1.0 / SUPER_PELLET_FPS
	if animation_elapsed >= frame_duration:
		var advanced := int(animation_elapsed / frame_duration)
		animation_elapsed -= advanced * frame_duration
		super_frame = (super_frame + advanced) % 5
		queue_redraw()


func _draw() -> void:
	if field == null:
		return
	for center in field.pellets:
		var type: int = field.pellets[center]
		if type == PelletFieldScript.SUPER and super_pellet_texture != null:
			draw_texture_rect_region(
				super_pellet_texture,
				Rect2(Vector2(center) - Vector2(15, 15), Vector2(30, 30)),
				Rect2(super_frame * 30, 0, 30, 30)
			)
		elif type == PelletFieldScript.NORMAL and pellet_texture != null:
			draw_texture(pellet_texture, Vector2(center) - Vector2(5, 5))
		else:
			var radius := 8.0 if type == PelletFieldScript.SUPER else 2.5
			draw_circle(Vector2(center), radius, Color("fff4cf"))

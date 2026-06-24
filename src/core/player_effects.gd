class_name PlayerEffects
extends RefCounted

const EXTRA_POINTS: Array[int] = [500, 1000, 2000, 3000, 5000]
const INVULNERABLE_SECONDS := 8

var double_speed := false
var double_score := false
var invulnerable_ticks := 0


func apply_extra(extra_number: int, ticks_per_second := 60) -> int:
	if extra_number < 0 or extra_number >= EXTRA_POINTS.size():
		return 0
	match extra_number:
		0:
			double_speed = true
		1:
			double_score = true
		2:
			invulnerable_ticks = INVULNERABLE_SECONDS * ticks_per_second
	return EXTRA_POINTS[extra_number]


func step() -> void:
	invulnerable_ticks = maxi(invulnerable_ticks - 1, 0)


func is_invulnerable() -> bool:
	return invulnerable_ticks > 0


func reset_on_death() -> void:
	double_speed = false
	double_score = false
	invulnerable_ticks = 0

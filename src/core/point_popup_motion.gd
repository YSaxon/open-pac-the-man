class_name PointPopupMotion
extends RefCounted

# Recovered from TPoints in the 1.5.1 PowerPC executable. Point sprites use
# the original 60 Hz animation clock even though gameplay advances at 30 Hz.
const REFERENCE_FPS := 60
const LIFETIME_FRAMES := 3 * REFERENCE_FPS / 2
const SPEED_FACTOR := 0.5
const LAUNCH_SPEED := -14.0
const GRAVITY := 0.5

var y := 0.0
var landing_y := 0
var velocity_y := 0.0
var delay_frames := 0
var remaining_frames := LIFETIME_FRAMES
var landed := false


func _init(collision_y: float, digit_index: int) -> void:
	landing_y = int(collision_y) + 6
	y = int(collision_y) + 10
	delay_frames = digit_index * 2


func step() -> void:
	remaining_frames -= 1
	if remaining_frames <= 0 or landed:
		return
	if delay_frames > -1:
		if delay_frames == 0:
			velocity_y = LAUNCH_SPEED
		delay_frames -= 1
		return
	y += velocity_y * SPEED_FACTOR
	if velocity_y > 0.01 and int(y) > landing_y:
		velocity_y = 0.0
		y = landing_y
		landed = true
		return
	velocity_y += GRAVITY


func expired() -> bool:
	return remaining_frames <= 0

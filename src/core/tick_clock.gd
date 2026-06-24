class_name TickClock
extends RefCounted

const DEFAULT_TICKS_PER_SECOND := 60

var ticks_per_second: int
var tick: int = 0


func _init(rate: int = DEFAULT_TICKS_PER_SECOND) -> void:
	assert(rate > 0, "Tick rate must be positive")
	ticks_per_second = rate


func step(count: int = 1) -> void:
	assert(count >= 0, "Cannot step backwards")
	tick += count


func reset() -> void:
	tick = 0


func elapsed_seconds() -> float:
	return float(tick) / float(ticks_per_second)


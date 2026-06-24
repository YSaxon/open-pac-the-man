class_name ScoreState
extends RefCounted

const GHOST_SCORE_TABLE := [
	[200, 400, 800, 2000],
	[400, 1000, 2000, 4000],
	[1000, 2000, 4000, 5000],
	[1000, 3000, 5000, 10000],
]
const EXTRA_LIFE_INTERVAL := 25_000

var score := 0
var lives := 3
var double_score := false


func add(base_points: int) -> int:
	var old_bucket := score / EXTRA_LIFE_INTERVAL
	var awarded := base_points * (2 if double_score else 1)
	score += awarded
	var new_bucket := score / EXTRA_LIFE_INTERVAL
	lives += new_bucket - old_bucket
	return awarded


static func ghost_points(level_number: int, ghosts_eaten: int) -> int:
	var group := 0
	if level_number > 18:
		group = 3
	elif level_number > 12:
		group = 2
	elif level_number > 6:
		group = 1
	return GHOST_SCORE_TABLE[group][clampi(ghosts_eaten, 0, 3)]

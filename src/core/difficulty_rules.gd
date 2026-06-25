class_name DifficultyRules
extends RefCounted

enum Level { EASY = 1, NORMAL = 2, HARD = 3, MASTER = 4 }


static func parse(value: String) -> int:
	match value.strip_edges().to_lower():
		"easy", "1":
			return Level.EASY
		"hard", "3":
			return Level.HARD
		"master", "4":
			return Level.MASTER
	return Level.NORMAL


static func key(level: int) -> String:
	match level:
		Level.EASY:
			return "easy"
		Level.HARD:
			return "hard"
		Level.MASTER:
			return "master"
	return "normal"


static func label(level: int) -> String:
	return key(level).capitalize()


static func ghost_speed(level: int) -> float:
	return 0.8 if level == Level.EASY else 0.9


static func random_override_max(level: int) -> int:
	# The original requests an inclusive random value and overrides only on 1.
	match level:
		Level.EASY:
			return 2 # 1 in 3
		Level.NORMAL:
			return 26 # 1 in 27
	return -1


static func uses_spotlight(level: int) -> bool:
	return level == Level.MASTER

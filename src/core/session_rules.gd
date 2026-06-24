class_name SessionRules
extends RefCounted

enum Mode {
	SOLO,
	SIMULTANEOUS,
	TWO_HANDED,
}

var mode := Mode.SOLO
var avatar_count := 1
var account_count := 1


func _init(requested_mode := Mode.SOLO, requested_avatars := 1) -> void:
	mode = requested_mode
	match mode:
		Mode.SOLO:
			avatar_count = 1
			account_count = 1
		Mode.SIMULTANEOUS:
			avatar_count = clampi(requested_avatars, 2, 4)
			account_count = avatar_count
		Mode.TWO_HANDED:
			avatar_count = 2
			account_count = 1


func score_owner(avatar_index: int) -> int:
	assert(avatar_index >= 0 and avatar_index < avatar_count)
	return 0 if mode == Mode.TWO_HANDED else avatar_index


func lives_owner(avatar_index: int) -> int:
	return score_owner(avatar_index)


func eliminated_avatars_after_death(avatar_index: int, remaining_lives: int) -> Array[int]:
	assert(avatar_index >= 0 and avatar_index < avatar_count)
	if remaining_lives > 0:
		return []
	# A shared account shares only its reserve pool. An avatar already alive when
	# that pool becomes empty keeps playing until its own next death.
	return [avatar_index]


func high_score_category() -> String:
	match mode:
		Mode.SIMULTANEOUS:
			return "simultaneous_%dp" % avatar_count
		Mode.TWO_HANDED:
			return "two_handed"
	return "solo"

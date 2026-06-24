class_name GhostReleaseSchedule
extends RefCounted


static func delay_seconds(level_number: int) -> int:
	if level_number > 22:
		return 3
	if level_number > 17:
		return 4
	if level_number > 12:
		return 5
	if level_number > 7:
		return 6
	return 7

class_name LevelImporter
extends RefCounted

const PlistXmlScript := preload("res://src/import/plist_xml.gd")
const LevelDataScript := preload("res://src/core/level_data.gd")


func parse(bytes: PackedByteArray) -> Dictionary:
	var plist_result: Dictionary = PlistXmlScript.new().parse(bytes)
	if plist_result.has("error"):
		return plist_result
	var source: Variant = plist_result["value"]
	if not source is Array:
		return {"error": "Level property list root must be an array"}

	var levels: Array = []
	var errors := PackedStringArray()
	for index in source.size():
		var item: Variant = source[index]
		if not item is Dictionary:
			errors.append("Level %d is not a dictionary" % index)
			continue
		var level = _convert_level(item)
		var validation: PackedStringArray = level.validate()
		for message in validation:
			errors.append("Level %d: %s" % [index, message])
		levels.append(level)
	return {"levels": levels, "errors": errors}


func _convert_level(source: Dictionary):
	var level = LevelDataScript.new()
	level.background = str(source.get("background", ""))
	level.citadel = str(source.get("citadel", ""))
	level.tileset = str(source.get("tileset", ""))
	level.wait_time = int(source.get("wait_time", 0))
	level.item = int(source.get("item", 0))
	level.rows = PackedStringArray(source.get("tiles", []))
	level.player_one = _point(source.get("position1", {}))
	level.player_two = _point(source.get("position2", {}))
	var color: Dictionary = source.get("color", {})
	level.wall_color = Color8(
		int(color.get("red", 255)),
		int(color.get("green", 255)),
		int(color.get("blue", 255)),
	)
	for pellet in source.get("super_pellets", []):
		level.super_pellets.append(_point(pellet))
	return level


func _point(source: Dictionary) -> Vector2i:
	return Vector2i(int(source.get("x", 0)), int(source.get("y", 0)))


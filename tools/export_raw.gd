extends SceneTree

const OriginalArchiveScript := preload("res://src/import/original_archive.gd")
const RawSpriteScript := preload("res://src/import/raw_sprite.gd")


func _initialize() -> void:
	var arguments := _arguments()
	for required in ["archive", "entry", "output"]:
		if not arguments.has(required):
			push_error("Missing --%s=... argument" % required)
			quit(2)
			return
	var entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
		arguments["archive"], arguments["entry"]
	)
	if entry.has("error"):
		push_error(entry["error"])
		quit(3)
		return
	var decoded: Dictionary = RawSpriteScript.new().decode(entry["bytes"])
	if decoded.has("error"):
		push_error(decoded["error"])
		quit(4)
		return
	var error: Error = decoded["image"].save_png(arguments["output"])
	print("Exported %s (%dx%d, %d-bit): %s" % [
		arguments["entry"],
		decoded["width"],
		decoded["height"],
		decoded["bits_per_pixel"],
		error_string(error),
	])
	quit(error)


func _arguments() -> Dictionary:
	var result := {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var separator := argument.find("=")
			result[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return result

class_name OriginalArchive
extends RefCounted

const REQUIRED_SUFFIXES := [
	"/Contents/MacOS/Pac the Man X",
	"/Contents/Resources/Levels/The X Levels.plist",
	"/Contents/Resources/Sprites/player1.raw",
]

static var _readers_by_path: Dictionary = {}
static var _files_by_path: Dictionary = {}


func inspect(path: String) -> Dictionary:
	var result := {
		"path": path,
		"sha256": "",
		"entry_count": 0,
		"extensions": {},
		"missing_required": PackedStringArray(),
	}
	if not FileAccess.file_exists(path):
		result["error"] = "Archive does not exist"
		return result

	var reader := ZIPReader.new()
	var open_error := reader.open(path)
	if open_error != OK:
		result["error"] = "Could not open ZIP archive (error %d)" % open_error
		return result

	var files := reader.get_files()
	result["sha256"] = FileAccess.get_sha256(path)
	result["entry_count"] = files.size()
	var extension_counts: Dictionary = {}
	for file in files:
		if file.ends_with("/"):
			continue
		var extension := file.get_extension().to_lower()
		if extension.is_empty():
			extension = "(none)"
		extension_counts[extension] = int(extension_counts.get(extension, 0)) + 1
	result["extensions"] = extension_counts

	var missing := PackedStringArray()
	for suffix in REQUIRED_SUFFIXES:
		var found := false
		for file in files:
			if file.ends_with(suffix):
				found = true
				break
		if not found:
			missing.append(suffix)
	result["missing_required"] = missing
	reader.close()
	return result


func read_file_by_suffix(path: String, suffix: String) -> Dictionary:
	var reader: ZIPReader = _readers_by_path.get(path)
	if reader == null:
		reader = ZIPReader.new()
		var open_error := reader.open(path)
		if open_error != OK:
			return {"error": "Could not open ZIP archive (error %d)" % open_error}
		_readers_by_path[path] = reader
		_files_by_path[path] = reader.get_files()
	var files: PackedStringArray = _files_by_path[path]
	for file in files:
		if file.ends_with(suffix):
			var bytes := reader.read_file(file)
			return {"path": file, "bytes": bytes}
	return {"error": "Archive entry not found: %s" % suffix}

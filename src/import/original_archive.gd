class_name OriginalArchive
extends RefCounted

const REQUIRED_SUFFIXES := [
	"/Contents/MacOS/Pac the Man X",
	"/Contents/Resources/Levels/The X Levels.plist",
	"/Contents/Resources/Sprites/player1.raw",
	"/Contents/Resources/Sprites/points.raw",
]

static var _readers_by_path: Dictionary = {}
static var _files_by_path: Dictionary = {}
static var _directory_files_by_path: Dictionary = {}


func inspect(path: String) -> Dictionary:
	var resolved_path := _resolve_path(path)
	var result := {
		"path": resolved_path,
		"kind": "",
		"sha256": "",
		"entry_count": 0,
		"extensions": {},
		"missing_required": PackedStringArray(),
	}
	if DirAccess.dir_exists_absolute(resolved_path):
		result["kind"] = "directory"
		var files := _files_for_directory(resolved_path)
		_populate_file_report(result, files)
		return result

	if not FileAccess.file_exists(resolved_path):
		result["error"] = "Archive/app path does not exist"
		return result

	var reader := ZIPReader.new()
	var open_error := reader.open(resolved_path)
	if open_error != OK:
		result["error"] = "Could not open ZIP archive (error %d)" % open_error
		return result

	var files := reader.get_files()
	result["kind"] = "zip"
	result["sha256"] = FileAccess.get_sha256(resolved_path)
	_populate_file_report(result, files)
	reader.close()
	return result


func read_file_by_suffix(path: String, suffix: String) -> Dictionary:
	var resolved_path := _resolve_path(path)
	if DirAccess.dir_exists_absolute(resolved_path):
		var directory_files := _files_for_directory(resolved_path)
		for alternate_suffix in _suffix_alternates(suffix):
			for file in directory_files:
				var relative_path: String = file["path"]
				if relative_path.ends_with(alternate_suffix):
					var bytes := FileAccess.get_file_as_bytes(file["absolute"])
					return {"path": relative_path, "bytes": bytes}
		return {"error": "App/resource entry not found: %s" % suffix}

	var reader: ZIPReader = _readers_by_path.get(resolved_path)
	if reader == null:
		reader = ZIPReader.new()
		var open_error := reader.open(resolved_path)
		if open_error != OK:
			return {"error": "Could not open ZIP archive (error %d)" % open_error}
		_readers_by_path[resolved_path] = reader
	if not _files_by_path.has(resolved_path):
		_files_by_path[resolved_path] = reader.get_files()
	var files: PackedStringArray = _files_by_path[resolved_path]
	for alternate_suffix in _suffix_alternates(suffix):
		for file in files:
			if file.ends_with(alternate_suffix):
				var bytes := reader.read_file(file)
				return {"path": file, "bytes": bytes}
	return {"error": "Archive entry not found: %s" % suffix}


func _suffix_alternates(suffix: String) -> PackedStringArray:
	var alternates := PackedStringArray([suffix])
	if suffix.begins_with("/Contents/Resources/Sprites/"):
		alternates.append(suffix.replace("/Contents/Resources/Sprites/", "/Contents/Resources/Graphics/"))
	if suffix.begins_with("/Contents/Resources/Backgrounds/"):
		alternates.append(suffix.replace("/Contents/Resources/Backgrounds/", "/Contents/Resources/Graphics/Backgrounds/"))
	if suffix == "/Contents/Resources/Levels/The X Levels.plist":
		alternates.append("/Contents/Resources/CustomLevels/The X Levels.plist")
	if suffix == "/Contents/Resources/Pac the Man X Editor.app/Contents/Resources/Levels.plist":
		alternates.append("/Contents/Resources/Pac the Man Editor.app/Contents/Resources/Levels.plist")
		alternates.append("/Contents/Resources/Pac the Man Editor.app/Contents/Resources/Standard Levels.plist")
	return alternates


func _any_file_ends_with(files, suffix: String) -> bool:
	for alternate_suffix in _suffix_alternates(suffix):
		for file in files:
			if file is Dictionary:
				file = file["path"]
			var file_path: String = file
			if file_path.ends_with(alternate_suffix):
				return true
	return false


func _populate_file_report(result: Dictionary, files) -> void:
	result["entry_count"] = files.size()
	var extension_counts: Dictionary = {}
	for file in files:
		if file is Dictionary:
			file = file["path"]
		var file_path: String = file
		if file_path.ends_with("/"):
			continue
		var extension: String = file_path.get_extension().to_lower()
		if extension.is_empty():
			extension = "(none)"
		extension_counts[extension] = int(extension_counts.get(extension, 0)) + 1
	result["extensions"] = extension_counts

	var missing := PackedStringArray()
	for suffix in REQUIRED_SUFFIXES:
		if not _any_file_ends_with(files, suffix):
			missing.append(suffix)
	result["missing_required"] = missing


func _files_for_directory(path: String) -> Array:
	var resolved_path := _resolve_path(path)
	if not _directory_files_by_path.has(resolved_path):
		var files: Array = []
		_collect_directory_files(resolved_path, resolved_path, files)
		_directory_files_by_path[resolved_path] = files
	return _directory_files_by_path[resolved_path]


func _collect_directory_files(root: String, current: String, files: Array) -> void:
	var dir := DirAccess.open(current)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var absolute := current.path_join(name)
			if dir.current_is_dir():
				_collect_directory_files(root, absolute, files)
			else:
				var relative := absolute.replace("\\", "/").trim_prefix(root.replace("\\", "/"))
				if not relative.begins_with("/"):
					relative = "/" + relative
				files.append({"path": relative, "absolute": absolute})
		name = dir.get_next()
	dir.list_dir_end()


func _resolve_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path

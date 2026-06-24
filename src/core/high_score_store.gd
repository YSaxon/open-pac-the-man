class_name HighScoreStore
extends RefCounted

const FORMAT_VERSION := 1
const DEFAULT_LIMIT := 10

var path := "user://high_scores.json"
var tables: Dictionary = {}


func _init(storage_path := "user://high_scores.json") -> void:
	path = storage_path


func load_scores() -> bool:
	if not FileAccess.file_exists(path):
		tables = {}
		return true
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("version", 0)) != FORMAT_VERSION:
		return false
	var loaded: Variant = parsed.get("tables", {})
	if not loaded is Dictionary:
		return false
	tables = loaded
	return true


func save_scores() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": FORMAT_VERSION, "tables": tables}, "\t"))
	return file.get_error() == OK


func record(category: String, player_name: String, score: int, limit := DEFAULT_LIMIT) -> int:
	var entries: Array = tables.get(category, [])
	entries.append({"name": _clean_name(player_name), "score": maxi(score, 0)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	if entries.size() > limit:
		entries.resize(limit)
	tables[category] = entries
	for index in entries.size():
		var entry: Dictionary = entries[index]
		if entry["name"] == _clean_name(player_name) and int(entry["score"]) == maxi(score, 0):
			return index
	return -1


func entries(category: String) -> Array:
	return tables.get(category, []).duplicate(true)


func best(category: String) -> int:
	var category_entries := entries(category)
	return 0 if category_entries.is_empty() else int(category_entries[0]["score"])


func qualifies(category: String, score: int, limit := DEFAULT_LIMIT) -> bool:
	var category_entries := entries(category)
	return (
		category_entries.size() < limit
		or maxi(score, 0) >= int(category_entries[category_entries.size() - 1]["score"])
	)


func _clean_name(value: String) -> String:
	var cleaned := value.strip_edges().to_upper()
	if cleaned.is_empty():
		cleaned = "PLAYER"
	return cleaned.substr(0, 12)

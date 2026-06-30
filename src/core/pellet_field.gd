class_name PelletField
extends RefCounted

const MazeDirectionScript := preload("res://src/core/direction.gd")
const MazeTopologyScript := preload("res://src/core/maze_topology.gd")

const NORMAL := 1
const SUPER := 2
const NORMAL_POINTS := 5
const SUPER_POINTS := 10
const NODE_ORIGIN := Vector2i(56, 58)
const GRID_SPACING := 44
const HALF_SPACING := GRID_SPACING / 2

var pellets: Dictionary = {}


func build(level) -> void:
	pellets.clear()
	var topology = MazeTopologyScript.new(level.rows)
	var citadel_entry: Vector2i = topology.citadel_entry()
	var citadel_cell: Vector2i = topology.find_marker("R")
	var super_cells: Dictionary = {}
	for cell in level.super_pellets:
		super_cells[cell] = true
	for y in level.rows.size():
		var row: String = level.rows[y]
		for x in row.length():
			var cell := Vector2i(x, y)
			var mask := row.unicode_at(x) - "A".unicode_at(0)
			if mask <= 0 or mask > 15:
				continue
			var center := node_center(cell)
			if not _is_outer_screen_perimeter_cell(level.rows, cell):
				pellets[center] = SUPER if super_cells.has(cell) else NORMAL
			if mask & MazeDirectionScript.RIGHT and not _enters_citadel(
				cell, MazeDirectionScript.RIGHT, citadel_entry, citadel_cell
			):
				pellets[center + Vector2i(HALF_SPACING, 0)] = NORMAL
			if mask & MazeDirectionScript.DOWN and not _enters_citadel(
				cell, MazeDirectionScript.DOWN, citadel_entry, citadel_cell
			):
				pellets[center + Vector2i(0, HALF_SPACING)] = NORMAL


func collect(player_top_left: Vector2) -> Dictionary:
	var result := {"points": 0, "normal": 0, "super": 0}
	for center in pellets.keys():
		var type: int = pellets[center]
		if _intersects(player_top_left, center, type):
			pellets.erase(center)
			if type == SUPER:
				result["points"] += SUPER_POINTS
				result["super"] += 1
			else:
				result["points"] += NORMAL_POINTS
				result["normal"] += 1
	return result


func remaining() -> int:
	return pellets.size()


static func node_center(cell: Vector2i) -> Vector2i:
	return NODE_ORIGIN + cell * GRID_SPACING


static func _is_outer_screen_perimeter_cell(rows: PackedStringArray, cell: Vector2i) -> bool:
	if rows.is_empty():
		return false
	return cell.x == 0 or cell.y == 0 or cell.x == rows[0].length() - 1 or cell.y == rows.size() - 1

static func _enters_citadel(
	cell: Vector2i,
	direction: int,
	citadel_entry: Vector2i,
	citadel_cell: Vector2i,
) -> bool:
	return cell == citadel_entry and cell + MazeDirectionScript.vector(direction) == citadel_cell


func _intersects(player_top_left: Vector2, pellet_center: Vector2i, type: int) -> bool:
	# Original collision code insets the 32x32 player bounds by 10 for a regular
	# pellet and 15 for a super pellet before intersecting sprite bounds.
	var inset := 15 if type == SUPER else 10
	var player_bounds := Rect2(player_top_left + Vector2(inset, inset), Vector2(32 - inset * 2, 32 - inset * 2))
	var pellet_size := 30 if type == SUPER else 10
	var pellet_bounds := Rect2(pellet_center - Vector2i(pellet_size / 2, pellet_size / 2), Vector2i(pellet_size, pellet_size))
	return player_bounds.intersects(pellet_bounds)

extends SceneTree

const TickClockScript := preload("res://src/core/tick_clock.gd")
const LevelDataScript := preload("res://src/core/level_data.gd")
const OriginalArchiveScript := preload("res://src/import/original_archive.gd")
const PlistXmlScript := preload("res://src/import/plist_xml.gd")
const LevelImporterScript := preload("res://src/import/level_importer.gd")
const RawSpriteScript := preload("res://src/import/raw_sprite.gd")
const MazeViewScript := preload("res://src/presentation/maze_view.gd")
const MazeTopologyScript := preload("res://src/core/maze_topology.gd")
const PlayerMotionScript := preload("res://src/core/player_motion.gd")
const MazeDirectionScript := preload("res://src/core/direction.gd")
const PlayerSpriteLayoutScript := preload("res://src/presentation/player_sprite_layout.gd")
const PelletFieldScript := preload("res://src/core/pellet_field.gd")
const ScoreStateScript := preload("res://src/core/score_state.gd")
const GhostMotionScript := preload("res://src/core/ghost_motion.gd")
const GhostStateScript := preload("res://src/core/ghost_state.gd")
const GhostSpriteLayoutScript := preload("res://src/presentation/ghost_sprite_layout.gd")
const GhostCollisionScript := preload("res://src/core/ghost_collision.gd")
const GhostReleaseScheduleScript := preload("res://src/core/ghost_release_schedule.gd")
const SessionRulesScript := preload("res://src/core/session_rules.gd")
const PlayerEffectsScript := preload("res://src/core/player_effects.gd")
const ExtraMotionScript := preload("res://src/core/extra_motion.gd")
const ExtraSpawnerScript := preload("res://src/core/extra_spawner.gd")
const HighScoreStoreScript := preload("res://src/core/high_score_store.gd")
const WavAudioScript := preload("res://src/import/wav_audio.gd")
const PointPopupMotionScript := preload("res://src/core/point_popup_motion.gd")

var failures := 0


func _initialize() -> void:
	_test_tick_clock()
	_test_level_validation()
	_test_plist_parser()
	_test_tile_alphabet()
	_test_player_motion()
	_test_pellets_and_score()
	_test_ghost_motion()
	_test_session_rules()
	_test_player_effects()
	_test_extras()
	_test_point_popup()
	_test_high_scores()
	_inspect_requested_archive()
	if failures == 0:
		print("PASS: bootstrap test suite")
	else:
		push_error("FAIL: %d bootstrap test(s)" % failures)
	quit(failures)


func _test_tick_clock() -> void:
	var clock = TickClockScript.new(60)
	clock.step(90)
	_expect(clock.tick == 90, "clock advances by explicit ticks")
	_expect(is_equal_approx(clock.elapsed_seconds(), 1.5), "clock derives elapsed seconds")
	clock.reset()
	_expect(clock.tick == 0, "clock resets deterministically")


func _test_level_validation() -> void:
	var level = LevelDataScript.new()
	level.rows = PackedStringArray(["ABCDEFGHIJKLM", "ABCDEFGHIJKLM"])
	level.tileset = "tile2"
	level.citadel = "citadel3"
	_expect(level.validate().is_empty(), "well-shaped level metadata validates")
	level.rows[1] = "short"
	_expect(level.validate().size() == 1, "invalid row width is rejected")


func _test_plist_parser() -> void:
	var xml := "<?xml version=\"1.0\"?><plist><dict><key>name</key><string>test</string><key>count</key><integer>3</integer><key>enabled</key><true/><key>items</key><array><string>a</string><string>b</string></array></dict></plist>"
	var result: Dictionary = PlistXmlScript.new().parse(xml.to_utf8_buffer())
	_expect(not result.has("error"), "XML property list parses")
	if not result.has("error"):
		var value: Dictionary = result["value"]
		_expect(value.get("name") == "test", "property-list string is preserved")
		_expect(value.get("count") == 3, "property-list integer is converted")
		_expect(value.get("enabled") == true, "property-list boolean is converted")
		_expect(value.get("items") == ["a", "b"], "property-list array is converted")


func _test_tile_alphabet() -> void:
	_expect("D".unicode_at(0) - "A".unicode_at(0) == 3, "D encodes a horizontal connection")
	_expect("M".unicode_at(0) - "A".unicode_at(0) == 12, "M encodes a vertical connection")
	_expect(MazeViewScript.CELL_SIZE == 44.0, "maze presentation uses recovered grid scale")


func _test_player_motion() -> void:
	var topology = MazeTopologyScript.new(PackedStringArray(["KLJ", "MAM", "GDF"]))
	_expect(topology.direction_allowed(Vector2i(1, 0), MazeDirectionScript.LEFT), "tile mask allows encoded left direction")
	_expect(topology.direction_allowed(Vector2i(1, 0), MazeDirectionScript.RIGHT), "tile mask allows encoded right direction")
	_expect(not topology.direction_allowed(Vector2i(1, 0), MazeDirectionScript.UP), "tile mask rejects absent direction")

	var motion = PlayerMotionScript.new(topology, Vector2i(0, 0))
	motion.request(MazeDirectionScript.RIGHT)
	motion.step()
	_expect(motion.position == Vector2(45, 42), "normal update advances ten half-pixel substeps")
	for ignored in 7:
		motion.step()
	_expect(motion.position == Vector2(80, 42), "movement approaches the next node deterministically")
	motion.request(MazeDirectionScript.DOWN)
	motion.step()
	_expect(motion.position == Vector2(84, 43), "buffered turn executes exactly at the node")

	var reversing = PlayerMotionScript.new(topology, Vector2i(0, 0))
	reversing.request(MazeDirectionScript.RIGHT)
	reversing.step()
	_expect(not reversing.is_on_node(), "reversal regression starts between maze nodes")
	reversing.request(MazeDirectionScript.LEFT)
	reversing.step()
	_expect(reversing.direction == MazeDirectionScript.LEFT and reversing.position == Vector2(40, 42), "opposite input reverses immediately between nodes")
	reversing.release(MazeDirectionScript.RIGHT)
	_expect(reversing.requested_direction == MazeDirectionScript.LEFT, "releasing the old direction does not cancel a held reversal")

	var fast = PlayerMotionScript.new(topology, Vector2i(0, 0))
	fast.request(MazeDirectionScript.RIGHT)
	fast.step(true)
	_expect(fast.position == Vector2(47, 42), "double speed advances fourteen half-pixel substeps")

	var wrap = PlayerMotionScript.new(topology, Vector2i.ZERO)
	wrap.position = Vector2(PlayerMotionScript.MIN_X, 42)
	wrap.direction = MazeDirectionScript.LEFT
	wrap.step()
	_expect(wrap.position == Vector2(602, 42), "horizontal tunnel wraps at recovered screen bounds")

	_expect(PlayerSpriteLayoutScript.frame_cell(MazeDirectionScript.LEFT, 0) == Vector2i(0, 0), "left animation starts closed")
	_expect(PlayerSpriteLayoutScript.frame_cell(MazeDirectionScript.LEFT, 7) == Vector2i(7, 0), "left animation reaches its open frame")
	_expect(PlayerSpriteLayoutScript.frame_cell(MazeDirectionScript.RIGHT, 7) == Vector2i(8, 0), "right animation uses the mirrored sheet half")
	_expect(PlayerSpriteLayoutScript.frame_cell(MazeDirectionScript.UP, 7) == Vector2i(8, 1), "up animation uses the lower sheet row")


func _test_pellets_and_score() -> void:
	var level = LevelDataScript.new()
	level.rows = PackedStringArray(["KLJ", "MAM", "GDF"])
	level.super_pellets.append(Vector2i(0, 0))
	var field = PelletFieldScript.new()
	field.build(level)
	_expect(field.pellets[Vector2i(56, 58)] == PelletFieldScript.SUPER, "super pellet occupies the recovered node center")
	_expect(field.pellets[Vector2i(78, 58)] == PelletFieldScript.NORMAL, "normal pellet occupies the horizontal midpoint")
	_expect(field.pellets[Vector2i(56, 80)] == PelletFieldScript.NORMAL, "normal pellet occupies the vertical midpoint")
	var collected: Dictionary = field.collect(Vector2i(40, 42))
	_expect(collected["points"] == 10 and collected["super"] == 1, "super pellet collision awards ten points")
	_expect(not field.pellets.has(Vector2i(56, 58)), "collected pellet is removed")

	var citadel_level = LevelDataScript.new()
	citadel_level.rows = PackedStringArray(["L", "R"])
	field.build(citadel_level)
	_expect(field.pellets.has(Vector2i(56, 58)), "citadel entry keeps its reachable node pellet")
	_expect(
		not field.pellets.has(Vector2i(56, 80)),
		"citadel doorway does not receive an unreachable midpoint pellet",
	)

	var score = ScoreStateScript.new()
	score.score = 24_995
	_expect(score.add(5) == 5 and score.lives == 4, "crossing 25,000 points awards an extra life")
	score.double_score = true
	_expect(score.add(5) == 10 and score.score == 25_010, "double-score state doubles awarded points")


func _test_ghost_motion() -> void:
	var topology = MazeTopologyScript.new(PackedStringArray([
		"KLDDLJMKLDDLJ",
		"MGLLNGPFOLLFM",
		"ODFMODHDNMGDN",
		"ODLNODLDNOLDN",
		"GJMGNQRQOFMKF",
		"DNMKNQQQOJMOD",
		"KHHNGDLDFOHHJ",
		"ODJOLDPDLNKDN",
		"MKHFMKPJMGHJM",
		"GHDDHFMGHDDHF",
	]))
	_expect(topology.find_marker("R") == Vector2i(6, 4), "citadel marker is discovered from level topology")
	_expect(topology.citadel_entry() == Vector2i(6, 3), "citadel entry is derived from its connecting maze node")
	_expect(topology.shortest_direction(Vector2i(0, 0), Vector2i(6, 3)) == MazeDirectionScript.RIGHT, "shortest-path field routes around maze obstacles")
	var citadel_blocked = PlayerMotionScript.new(topology, Vector2i(6, 3))
	citadel_blocked.request(MazeDirectionScript.DOWN)
	citadel_blocked.step()
	_expect(citadel_blocked.position == Vector2(PlayerMotionScript.pixel_for_cell(Vector2i(6, 3))), "player cannot enter the ghost citadel")

	var line = MazeTopologyScript.new(PackedStringArray(["KLJ", "MAM", "GDF"]))
	var ghost = GhostMotionScript.new(line, Vector2i(1, 0), 0)
	ghost.direction = MazeDirectionScript.RIGHT
	ghost.start_hunting(true)
	ghost.step(PlayerMotionScript.pixel_for_cell(Vector2i(2, 0)))
	_expect(ghost.position == Vector2(89, 42), "hunting ghost advances ten half-pixel substeps")
	ghost.position = Vector2(PlayerMotionScript.pixel_for_cell(Vector2i(1, 0)))
	ghost.direction = MazeDirectionScript.RIGHT
	ghost.start_frightened(10)
	ghost.step(PlayerMotionScript.pixel_for_cell(Vector2i(2, 0)))
	_expect(ghost.state == GhostStateScript.FRIGHTENED, "super-pellet transition enters frightened state")
	_expect(ghost.position == Vector2(81.5, 42), "frightened ghost reverses and advances five half-pixel substeps")
	ghost.start_returning()
	ghost.reached_target = true
	ghost.position = Vector2(PlayerMotionScript.pixel_for_cell(Vector2i(2, 0)))
	ghost.direction = MazeDirectionScript.LEFT
	ghost.step(PlayerMotionScript.pixel_for_cell(Vector2i.ZERO))
	_expect(ghost.position == Vector2(112, 42), "returning ghost advances thirty-two half-pixel substeps")
	var returning = GhostMotionScript.new(topology, Vector2i(0, 0), 0, Vector2i(6, 4))
	returning.position = Vector2(PlayerMotionScript.pixel_for_cell(Vector2i(0, 0)))
	returning.start_returning()
	returning.step(PlayerMotionScript.pixel_for_cell(Vector2i.ZERO))
	_expect(returning.direction == MazeDirectionScript.RIGHT, "returning ghost follows shortest-path field rather than greedy obstacle loops")
	for ignored in 100:
		if returning.state == GhostStateScript.WAITING:
			break
		returning.step(PlayerMotionScript.pixel_for_cell(Vector2i.ZERO))
	_expect(returning.state == GhostStateScript.WAITING, "returning ghost reaches its citadel home without path loops")
	_expect(GhostSpriteLayoutScript.frame_cell(2, MazeDirectionScript.DOWN, 4, GhostStateScript.HUNTING) == Vector2i(4, 5), "ghost sheet maps color, direction, and animation frame")
	_expect(GhostSpriteLayoutScript.frame_cell(0, MazeDirectionScript.UP, 0, GhostStateScript.RETURNING) == Vector2i(2, 8), "returning ghost uses eyes-only sprite row")
	_expect(GhostCollisionScript.classify(Vector2.ZERO, Vector2(10, 10), GhostStateScript.FRIGHTENED) == GhostCollisionScript.GHOST_EATEN, "frightened ghost collides at recovered axis threshold")
	_expect(GhostCollisionScript.classify(Vector2.ZERO, Vector2(11, 0), GhostStateScript.HUNTING) == GhostCollisionScript.NONE, "ghost outside recovered collision threshold does not collide")
	_expect(GhostCollisionScript.classify(Vector2.ZERO, Vector2.ZERO, GhostStateScript.HUNTING) == GhostCollisionScript.PLAYER_HIT, "hunting ghost collision hits player")
	_expect(GhostCollisionScript.classify(Vector2.ZERO, Vector2.ZERO, GhostStateScript.WAITING) == GhostCollisionScript.NONE, "waiting ghost collision is ignored")
	_expect(ScoreStateScript.ghost_points(0, 0) == 200 and ScoreStateScript.ghost_points(0, 3) == 2000, "early-level ghost score ladder matches recovered table")
	_expect(ScoreStateScript.ghost_points(19, 3) == 10_000, "late-level fourth ghost awards recovered score")
	_expect(GhostReleaseScheduleScript.delay_seconds(0) == 7, "early levels release waiting ghosts every seven seconds")
	_expect(GhostReleaseScheduleScript.delay_seconds(23) == 3, "late levels release waiting ghosts every three seconds")
	var home_ghost = GhostMotionScript.new(topology, Vector2i(5, 4), 1)
	home_ghost.start_hunting(false)
	home_ghost.step(PlayerMotionScript.pixel_for_cell(Vector2i.ZERO))
	_expect(home_ghost.position == Vector2(PlayerMotionScript.pixel_for_cell(Vector2i(5, 4))) + Vector2(5, 0), "released side ghost routes toward citadel center")


func _test_session_rules() -> void:
	var simultaneous = SessionRulesScript.new(SessionRulesScript.Mode.SIMULTANEOUS, 4)
	_expect(simultaneous.avatar_count == 4 and simultaneous.account_count == 4, "simultaneous mode supports four independent avatars")
	_expect(simultaneous.score_owner(3) == 3, "simultaneous avatars own independent scores and lives")
	_expect(simultaneous.high_score_category() == "simultaneous_4p", "simultaneous player count has a distinct high-score category")
	var two_handed = SessionRulesScript.new(SessionRulesScript.Mode.TWO_HANDED)
	_expect(two_handed.avatar_count == 2 and two_handed.account_count == 1, "two-handed mode has two avatars and one shared account")
	_expect(two_handed.score_owner(0) == 0 and two_handed.score_owner(1) == 0, "two-handed avatars share score and lives")
	_expect(two_handed.eliminated_avatars_after_death(0, 0) == [0], "exhausting shared lives eliminates only the avatar that died")
	_expect(two_handed.eliminated_avatars_after_death(1, 1).is_empty(), "an avatar respawns while a shared reserve life remains")
	_expect(two_handed.high_score_category() == "two_handed", "two-handed mode has a separate high-score table")


func _test_player_effects() -> void:
	var first = PlayerEffectsScript.new()
	var second = PlayerEffectsScript.new()
	_expect(first.apply_extra(0) == 500 and first.double_speed, "extra zero enables double speed and awards 500")
	_expect(first.apply_extra(1) == 1000 and first.double_score, "extra one enables double score and awards 1000")
	_expect(first.apply_extra(2, 20) == 2000 and first.invulnerable_ticks == 160, "extra two grants eight seconds of per-avatar invulnerability")
	_expect(first.apply_extra(3) == 3000 and first.apply_extra(4) == 5000, "score-only extras use recovered values")
	_expect(not second.double_speed and not second.double_score and not second.is_invulnerable(), "power-up state remains independent between avatars")
	first.reset_on_death()
	_expect(not first.double_speed and not first.double_score and not first.is_invulnerable(), "death clears temporary avatar effects")


func _test_extras() -> void:
	var line = MazeTopologyScript.new(PackedStringArray(["KDJ", "GDF"]))
	var motion = ExtraMotionScript.new(line, Vector2i(1, 0), 2, 20, 7)
	motion.direction = MazeDirectionScript.RIGHT
	motion.step()
	_expect(motion.position == Vector2(PlayerMotionScript.pixel_for_cell(Vector2i(1, 0))) + Vector2(1, 0), "extra moves two half-pixel substeps per update")
	_expect(motion.remaining_ticks == 199, "extra lifetime starts at recovered ten seconds")
	_expect(motion.animation_frame() == 1, "extra animation starts on its recovered center frame")
	motion.step()
	motion.step()
	_expect(motion.animation_frame() == 2, "extra animation advances at the recovered six frames per second")
	_expect(motion.collides(motion.position + Vector2(10, 10)), "extra collision uses recovered ten-pixel axis threshold")
	var spawner = ExtraSpawnerScript.new(line, 20, 3)
	var forced: Dictionary = spawner.force_spawn(Vector2i(1, 0), 4)
	_expect(forced["extra_number"] == 4 and spawner.active and spawner.appeared == 1, "extra spawner tracks active and appearance limits")
	spawner.released()
	_expect(not spawner.active, "collected or expired extra releases active slot")


func _test_point_popup() -> void:
	var first = PointPopupMotionScript.new(100.0, 0)
	_expect(first.y == 110.0 and first.landing_y == 106, "point popup starts ten pixels below collision and lands six pixels below")
	first.step()
	_expect(first.y == 110.0 and first.velocity_y == -14.0, "first point digit launches at recovered vertical speed")
	first.step()
	_expect(first.y == 103.0 and first.velocity_y == -13.5, "point digit uses recovered half-speed movement and gravity")
	var staggered = PointPopupMotionScript.new(100.0, 1)
	staggered.step()
	staggered.step()
	_expect(staggered.velocity_y == 0.0, "point digits wait two frames per character position")
	staggered.step()
	_expect(staggered.velocity_y == -14.0, "staggered point digit launches after its recovered delay")
	for ignored in PointPopupMotionScript.LIFETIME_FRAMES - 2:
		first.step()
	_expect(first.expired(), "point popup expires after recovered one-and-a-half seconds")


func _test_high_scores() -> void:
	var path := "res://build/test-high-scores.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var store = HighScoreStoreScript.new(path)
	_expect(store.record("solo", "low", 100) == 0, "first high score takes first rank")
	_expect(store.record("solo", "high", 500) == 0, "higher score sorts ahead of existing score")
	store.record("two_handed", "shared", 300)
	_expect(store.best("solo") == 500 and store.best("two_handed") == 300, "mode-specific high-score tables remain separate")
	_expect(store.qualifies("solo", 50), "an unfilled high-score table accepts another result")
	for index in 8:
		store.record("solo", "fill%d" % index, 200 + index)
	_expect(not store.qualifies("solo", 50) and store.qualifies("solo", 250), "a full table only accepts a top-ten result")
	_expect(store.save_scores(), "high scores persist as versioned local data")
	var loaded = HighScoreStoreScript.new(path)
	_expect(loaded.load_scores() and loaded.entries("solo").size() == 10, "persisted high scores load successfully")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _inspect_requested_archive() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--archive="):
			var path := argument.trim_prefix("--archive=")
			var report: Dictionary = OriginalArchiveScript.new().inspect(path)
			if report.has("error"):
				_expect(false, "archive inspection: %s" % report["error"])
				return
			_expect(report["missing_required"].is_empty(), "archive contains required original files")
			print("ARCHIVE: %s" % JSON.stringify(report))
			_test_original_levels(path)
			_test_original_sprite(path)
			_test_original_audio(path)
			return


func _test_original_levels(archive_path: String) -> void:
	var entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
		archive_path, "/Contents/Resources/Levels/The X Levels.plist"
	)
	_expect(not entry.has("error"), "original X-level data can be read")
	if entry.has("error"):
		return
	var result: Dictionary = LevelImporterScript.new().parse(entry["bytes"])
	_expect(not result.has("error"), "original X-level plist parses")
	if result.has("error"):
		return
	_expect(result["levels"].size() > 0, "original X-level set contains levels")
	_expect(result["errors"].is_empty(), "all imported X levels validate")
	var unreachable_cells := 0
	for level_index in result["levels"].size():
		var level = result["levels"][level_index]
		var topology = MazeTopologyScript.new(level.rows)
		var home: Vector2i = topology.citadel_entry()
		for y in level.rows.size():
			var row: String = level.rows[y]
			for x in row.length():
				var code := row.substr(x, 1)
				# A is the zero-connection/empty tile; B-P are traversable masks.
				if code <= "A" or code > "P":
					continue
				var cell := Vector2i(x, y)
				if cell != home and topology.shortest_direction(cell, home) == MazeDirectionScript.NONE:
					unreachable_cells += 1
	_expect(unreachable_cells == 0, "every X-level path cell has a loop-free route to ghost home")
	print("LEVELS: imported %d X levels" % result["levels"].size())


func _test_original_sprite(archive_path: String) -> void:
	var entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
		archive_path, "/Contents/Resources/Sprites/player1.raw"
	)
	_expect(not entry.has("error"), "original player sprite can be read")
	if entry.has("error"):
		return
	var result: Dictionary = RawSpriteScript.new().decode(entry["bytes"])
	_expect(not result.has("error"), "original player sprite decodes")
	if result.has("error"):
		return
	_expect(result["width"] == 512 and result["height"] == 64, "player sprite dimensions match")
	_expect(result["bits_per_pixel"] == 32, "player sprite RGBA depth matches")
	var title_entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
		archive_path, "/Contents/Resources/Sprites/title.raw"
	)
	var title_result: Dictionary = RawSpriteScript.new().decode(title_entry.get("bytes", PackedByteArray()))
	_expect(not title_result.has("error"), "original 24-bit title sprite decodes")
	if not title_result.has("error"):
		_expect(title_result["width"] == 640 and title_result["height"] == 480, "title sprite dimensions match")
		_expect(title_result["bits_per_pixel"] == 24, "title sprite RGB depth matches")
	var points_entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
		archive_path, "/Contents/Resources/Sprites/points.raw"
	)
	var points_result: Dictionary = RawSpriteScript.new().decode(points_entry.get("bytes", PackedByteArray()))
	_expect(not points_result.has("error"), "original point-popup sprite decodes")
	if not points_result.has("error"):
		_expect(points_result["width"] == 144 and points_result["height"] == 105, "point-popup sheet contains eight digits in five colors")


func _test_original_audio(archive_path: String) -> void:
	var entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
		archive_path, "/Contents/Resources/Sounds/eat_pelletB.wav"
	)
	_expect(not entry.has("error"), "original WAV sound can be read")
	if entry.has("error"):
		return
	var result: Dictionary = WavAudioScript.new().decode(entry["bytes"])
	_expect(not result.has("error") and result["stream"] is AudioStreamWAV, "original WAV sound decodes to a Godot audio stream")
	if not result.has("error"):
		_expect(result["sample_rate"] > 0 and result["bits_per_sample"] in [8, 16], "original WAV sample metadata validates")


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		push_error("FAIL: %s" % description)

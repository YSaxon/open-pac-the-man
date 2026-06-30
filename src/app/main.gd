extends Node2D

const OriginalArchiveScript := preload("res://src/import/original_archive.gd")
const LevelImporterScript := preload("res://src/import/level_importer.gd")
const MazeViewScript := preload("res://src/presentation/maze_view.gd")
const RawSpriteScript := preload("res://src/import/raw_sprite.gd")
const MazeTopologyScript := preload("res://src/core/maze_topology.gd")
const PlayerMotionScript := preload("res://src/core/player_motion.gd")
const MazeDirectionScript := preload("res://src/core/direction.gd")
const PlayerSpriteLayoutScript := preload("res://src/presentation/player_sprite_layout.gd")
const PelletFieldScript := preload("res://src/core/pellet_field.gd")
const PelletViewScript := preload("res://src/presentation/pellet_view.gd")
const ScoreStateScript := preload("res://src/core/score_state.gd")
const GhostMotionScript := preload("res://src/core/ghost_motion.gd")
const GhostStateScript := preload("res://src/core/ghost_state.gd")
const GhostSpriteLayoutScript := preload("res://src/presentation/ghost_sprite_layout.gd")
const GhostCollisionScript := preload("res://src/core/ghost_collision.gd")
const GhostReleaseScheduleScript := preload("res://src/core/ghost_release_schedule.gd")
const PlayerEffectsScript := preload("res://src/core/player_effects.gd")
const ExtraMotionScript := preload("res://src/core/extra_motion.gd")
const ExtraSpawnerScript := preload("res://src/core/extra_spawner.gd")
const HighScoreStoreScript := preload("res://src/core/high_score_store.gd")
const SessionRulesScript := preload("res://src/core/session_rules.gd")
const WavAudioScript := preload("res://src/import/wav_audio.gd")
const PointPopupViewScript := preload("res://src/presentation/point_popup_view.gd")
const DifficultyRulesScript := preload("res://src/core/difficulty_rules.gd")
const SpotlightViewScript := preload("res://src/presentation/spotlight_view.gd")
const FontTextViewScript := preload("res://src/presentation/font_text_view.gd")

const TICKS_PER_SECOND := 30
const FRIGHTENED_DURATION_TICKS := 8 * TICKS_PER_SECOND
const LEVEL_CLEAR_DURATION_TICKS := 2 * TICKS_PER_SECOND
const GHOST_EAT_PAUSE_TICKS := TICKS_PER_SECOND
const SPOTLIGHT_Z_INDEX := 100
const EXTRA_ABOVE_SPOTLIGHT_Z_INDEX := 110

var player_motion
var player_sprite: Sprite2D
var pellet_field
var pellet_view
var score_state
var session_rules
var score_states: Array = []
var player_motions: Array = []
var player_sprites: Array[Sprite2D] = []
var player_effects_by_avatar: Array = []
var player_start_cells: Array[Vector2i] = []
var player_active: Array[bool] = []
var player_normal_textures: Array[Texture2D] = []
var player_flash_textures: Array[Texture2D] = []
var player_death_textures: Array[Texture2D] = []
var player_burst_textures: Array[Texture2D] = []
var ghosts_eaten_by_avatar: Array[int] = []
var ghost_motions: Array = []
var ghost_sprites: Array[Sprite2D] = []
var ghost_texture: Texture2D
var frightened_ghost_texture: Texture2D
var player_start_cell := Vector2i.ZERO
var ghosts_eaten := 0
var level_number := 0
var ghost_release_ticks := 0
var archive_path := ""
var levels: Array = []
var level_pack := "x"
var level_root: Node2D
var level_transition_pending := false
var level_transition_ticks := 0
var game_over := false
var game_finished := false
var player_effects
var player_texture: Texture2D
var player_flash_texture: Texture2D
var player_death_texture: Texture2D
var player_death_burst_texture: Texture2D
var heart_texture: Texture2D
var hud_lives := -1
var hud_lives_signature := ""
var extra_texture: Texture2D
var extra_spawner
var extra_motion
var extra_sprite: Sprite2D
var high_scores
var high_score_category := "solo"
var score_recorded := false
var player_dying_ticks := 0
var player_dying_index := -1
var round_start_ticks := 0
var ready_sprite: Sprite2D
var game_over_sprite: Sprite2D
var pause_sprite: Sprite2D
var paused_game := false
var menu_active := false
var sound_cache: Dictionary = {}
var music_cache: Dictionary = {}
var current_music_name := ""
var music_enabled := true
var pellet_sound_alternate := false
var name_entry_active := false
var point_texture: Texture2D
var point_popup_color := 0
var point_popups: Array = []
var difficulty := DifficultyRulesScript.Level.NORMAL
var spotlight_view
var hud_font_texture: Texture2D
var hud_score_text
var hud_second_score_text
var hud_level_text
var hud_double_texts: Array = []
var ghost_eat_pause_ticks := 0
var ghost_eat_hidden_index := -1


func _ready() -> void:
	print("Maze Engine bootstrap ready")
	$NameEntry/Panel/Name.text_submitted.connect(_submit_high_score_name)
	level_root = $LevelRoot
	archive_path = _archive_path()
	if archive_path.is_empty():
		$Status.text = "Maze Engine\nPut original data in original/pacx151a.zip or pass --archive=/path/to/Pac the Man X.app"
		return
	level_pack = "x" if _argument_value("--level-pack=").to_lower() == "x" else "standard"
	if not _load_level_pack(level_pack):
		$Status.text = "Maze Engine\nCould not import level data"
		return
	_setup_hud_font()
	high_scores = HighScoreStoreScript.new()
	high_scores.load_scores()
	session_rules = _requested_session_rules()
	difficulty = DifficultyRulesScript.parse(_argument_value("--difficulty="))
	if DifficultyRulesScript.uses_spotlight(difficulty) and session_rules.avatar_count > 1:
		difficulty = DifficultyRulesScript.Level.HARD
	high_score_category = _current_high_score_category()
	for ignored in session_rules.account_count:
		score_states.append(ScoreStateScript.new())
	score_state = score_states[0]
	_start_level(clampi(int(_argument_value("--level=")), 0, levels.size() - 1))
	if not _argument_value("--mode=").is_empty():
		_play_music("PacManiac")
	var qa_extra := _argument_value("--qa-extra=")
	if not qa_extra.is_empty():
		var forced_cell := _argument_cell("--qa-extra-cell=", player_start_cell)
		var forced: Dictionary = extra_spawner.force_spawn(forced_cell, int(qa_extra))
		_create_extra(forced["cell"], forced["extra_number"])
	var qa_points := _argument_value("--qa-points=")
	if not qa_points.is_empty():
		round_start_ticks = 0
		if ready_sprite != null:
			ready_sprite.visible = false
		_spawn_point_popup(player_motion.position, int(qa_points))
	var qa_death_frame := _argument_value("--qa-death-frame=")
	if not qa_death_frame.is_empty():
		round_start_ticks = 0
		if ready_sprite != null:
			ready_sprite.visible = false
		_start_player_dying(0)
		player_dying_ticks = 3 * TICKS_PER_SECOND - int(float(int(qa_death_frame)) * TICKS_PER_SECOND / 18.0)
	if _has_argument("--qa-next-level"):
		_advance_level()
	if _has_argument("--qa-game-over"):
		score_state.lives = 0
		game_over = true
		if ready_sprite != null:
			ready_sprite.visible = false
		_record_score()
		_update_status()
	if _has_argument("--qa-name-entry"):
		score_state.score = 12_345
		game_over = true
		if ready_sprite != null:
			ready_sprite.visible = false
		_prompt_for_high_score()
		_update_status()
	if _has_argument("--qa-multiplayer-motion") and player_motions.size() > 1:
		round_start_ticks = 0
		if ready_sprite != null:
			ready_sprite.visible = false
		for avatar_index in player_motions.size():
			var choices: Array[int] = player_motions[avatar_index].topology.directions_at(player_start_cells[avatar_index])
			if not choices.is_empty():
				player_motions[avatar_index].request(choices[avatar_index % choices.size()])
	if _has_argument("--qa-escape"):
		var escape_event := InputEventKey.new()
		escape_event.keycode = KEY_ESCAPE
		escape_event.pressed = true
		_unhandled_key_input(escape_event)
	if (
		_argument_value("--mode=").is_empty()
		and (_argument_value("--screenshot=").is_empty() or _has_argument("--qa-menu"))
	):
		_show_mode_menu()
	var screenshot_path := _argument_value("--screenshot=")
	if not screenshot_path.is_empty():
		_save_screenshot.call_deferred(screenshot_path)


func _start_level(index: int) -> void:
	_clear_level()
	level_number = index
	var level = levels[level_number]
	if point_texture == null:
		point_texture = _load_raw_texture("/Contents/Resources/Sprites/points.raw")
	var background_texture := _load_background_texture(archive_path, level.background)
	var maze = MazeViewScript.new()
	level_root.add_child(maze)
	var citadel_name: String = "citadel1" if level.citadel == "citadel" else level.citadel
	var tile_texture := _load_wall_mask_texture("/Contents/Resources/Sprites/%s.raw" % level.tileset)
	var citadel_texture := _load_wall_mask_texture("/Contents/Resources/Sprites/%s.raw" % citadel_name)
	var barrier_texture := _load_raw_texture("/Contents/Resources/Sprites/barrier.raw")
	maze.set_artwork(tile_texture, citadel_texture, barrier_texture, background_texture)
	maze.show_level(level, Vector2(34, 36))
	pellet_field = PelletFieldScript.new()
	pellet_field.build(level)
	pellet_view = PelletViewScript.new()
	level_root.add_child(pellet_view)
	pellet_view.set_artwork(
		_load_raw_texture("/Contents/Resources/Sprites/pellet.raw"),
		_load_raw_texture("/Contents/Resources/Sprites/super_pellet.raw"),
	)
	pellet_view.show_field(pellet_field)
	var topology = MazeTopologyScript.new(level.rows)
	_add_players(archive_path, level, topology)
	_add_extra_system(archive_path, topology)
	_add_ghosts(archive_path, topology)
	_add_spotlight()
	_add_ready_banner(archive_path)
	ghost_release_ticks = GhostReleaseScheduleScript.delay_seconds(level_number) * TICKS_PER_SECOND
	round_start_ticks = TICKS_PER_SECOND
	level_transition_pending = false
	level_transition_ticks = 0
	_update_status()


func _clear_level() -> void:
	for child in level_root.get_children():
		level_root.remove_child(child)
		child.free()
	player_motion = null
	player_effects = null
	player_motions.clear()
	player_sprites.clear()
	player_effects_by_avatar.clear()
	player_start_cells.clear()
	player_active.clear()
	player_normal_textures.clear()
	player_flash_textures.clear()
	player_death_textures.clear()
	player_burst_textures.clear()
	ghosts_eaten_by_avatar.clear()
	player_dying_ticks = 0
	player_dying_index = -1
	round_start_ticks = 0
	ready_sprite = null
	game_over_sprite = null
	pause_sprite = null
	paused_game = false
	extra_spawner = null
	extra_motion = null
	extra_sprite = null
	player_sprite = null
	pellet_field = null
	pellet_view = null
	ghost_motions.clear()
	ghost_sprites.clear()
	ghosts_eaten = 0
	level_transition_ticks = 0
	point_popups.clear()
	spotlight_view = null
	ghost_eat_pause_ticks = 0
	ghost_eat_hidden_index = -1


func _archive_path() -> String:
	var requested := _argument_value("--archive=")
	if not requested.is_empty():
		return requested
	var candidates := [
		ProjectSettings.globalize_path("res://original/pacx151a.zip"),
		ProjectSettings.globalize_path("res://original/Pac the Man X.app"),
		ProjectSettings.globalize_path("res://../clone/pacx151a.zip"),
	]
	for candidate in candidates:
		if FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(candidate):
			return candidate
	return ""


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _has_argument(value: String) -> bool:
	return value in OS.get_cmdline_user_args()


func _argument_cell(prefix: String, fallback: Vector2i) -> Vector2i:
	var value := _argument_value(prefix)
	if value.is_empty():
		return fallback
	var parts := value.split(",", false)
	if parts.size() != 2:
		return fallback
	return Vector2i(int(parts[0]), int(parts[1]))


func _load_level_pack(requested_pack: String) -> bool:
	var bytes := PackedByteArray()
	if requested_pack == "standard":
		var archive_entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
			archive_path, "/Contents/Resources/Pac the Man X Editor.app/Contents/Resources/Levels.plist"
		)
		if not archive_entry.has("error"):
			bytes = archive_entry["bytes"]
		else:
			var development_path := "res://original/samples/Levels.plist"
			if FileAccess.file_exists(development_path):
				bytes = FileAccess.get_file_as_bytes(development_path)
	else:
		var entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
			archive_path, "/Contents/Resources/Levels/The X Levels.plist"
		)
		if not entry.has("error"):
			bytes = entry["bytes"]
	if bytes.is_empty():
		return false
	var parsed: Dictionary = LevelImporterScript.new().parse(bytes)
	if parsed.has("error") or parsed["levels"].is_empty():
		return false
	levels = parsed["levels"]
	level_pack = requested_pack
	return true


func _current_high_score_category() -> String:
	var category: String = "%s_%s" % [
		session_rules.high_score_category(), DifficultyRulesScript.key(difficulty)
	]
	return "standard_%s" % category if level_pack == "standard" else category


func _requested_session_rules():
	match _argument_value("--mode=").to_lower():
		"simultaneous", "two_player", "2p":
			return SessionRulesScript.new(SessionRulesScript.Mode.SIMULTANEOUS, 2)
		"two_handed", "two-handed":
			return SessionRulesScript.new(SessionRulesScript.Mode.TWO_HANDED, 2)
	return SessionRulesScript.new(SessionRulesScript.Mode.SOLO, 1)


func _save_screenshot(path: String) -> void:
	var delay_frames := maxi(int(_argument_value("--screenshot-delay=")), 1)
	for ignored in delay_frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("Screenshot %s: %s" % [path, error_string(error)])
	get_tree().quit(error)


func _load_background_texture(source_archive: String, background_name: String) -> Texture2D:
	if background_name.is_empty():
		return null
	var entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
		source_archive, "/Contents/Resources/Backgrounds/%s.png" % background_name
	)
	if entry.has("error"):
		return null
	var image := Image.new()
	if image.load_png_from_buffer(entry["bytes"]) != OK or image.get_width() <= 0 or image.get_height() <= 0:
		return null
	# The original backgrounds are small repeating tiles. MazeView applies the
	# repeat only through its non-playable-region mask; playable corridors remain
	# dark instead of receiving the texture.
	return ImageTexture.create_from_image(image)


func _load_raw_texture(suffix: String) -> Texture2D:
	var entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(archive_path, suffix)
	if entry.has("error"):
		return null
	var decoded: Dictionary = RawSpriteScript.new().decode(entry["bytes"])
	if decoded.has("error"):
		return null
	return ImageTexture.create_from_image(decoded["image"])


func _setup_hud_font() -> void:
	hud_font_texture = _load_raw_texture("/Contents/Resources/Sprites/font.raw")
	if hud_font_texture == null:
		return
	$Hud/Score.visible = false
	$Hud/SecondPlayer/Score.visible = false
	$Hud/LevelNumber.visible = false
	hud_score_text = FontTextViewScript.new()
	hud_score_text.position = Vector2(72, 3)
	$Hud.add_child(hud_score_text)
	hud_level_text = FontTextViewScript.new()
	hud_level_text.position = Vector2(310, 3)
	$Hud.add_child(hud_level_text)
	hud_second_score_text = FontTextViewScript.new()
	hud_second_score_text.position = Vector2(444, 3)
	$Hud/SecondPlayer.add_child(hud_second_score_text)
	for index in 2:
		var indicator = FontTextViewScript.new()
		indicator.set_font_texture(hud_font_texture)
		indicator.show_text("X2", 0 if index == 0 else 1, -2)
		indicator.visible = false
		indicator.position = Vector2(68, 3) if index == 0 else Vector2(548, 3)
		if index == 0:
			$Hud.add_child(indicator)
		else:
			$Hud/SecondPlayer.add_child(indicator)
		hud_double_texts.append(indicator)
	for view in [hud_score_text, hud_level_text, hud_second_score_text]:
		view.set_font_texture(hud_font_texture)


func _load_wall_mask_texture(suffix: String) -> Texture2D:
	var entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(archive_path, suffix)
	if entry.has("error"):
		return null
	var decoded: Dictionary = RawSpriteScript.new().decode(entry["bytes"])
	if decoded.has("error"):
		return null
	var wall_image: Image = decoded["image"]
	# The original magenta pixels are an alpha mask tinted with each level's wall color.
	# Replacing their RGB channels with white lets CanvasItem modulation reproduce that.
	for y in wall_image.get_height():
		for x in wall_image.get_width():
			var pixel := wall_image.get_pixel(x, y)
			wall_image.set_pixel(x, y, Color(1.0, 1.0, 1.0, pixel.a))
	return ImageTexture.create_from_image(wall_image)


func _add_ready_banner(source_archive: String) -> void:
	var entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
		source_archive, "/Contents/Resources/Sprites/ready.raw"
	)
	if entry.has("error"):
		return
	var decoded: Dictionary = RawSpriteScript.new().decode(entry["bytes"])
	if decoded.has("error"):
		return
	ready_sprite = Sprite2D.new()
	ready_sprite.texture = ImageTexture.create_from_image(decoded["image"])
	ready_sprite.position = Vector2(320, 240)
	level_root.add_child(ready_sprite)


func _add_players(source_archive: String, level, topology) -> void:
	var death_texture := _load_raw_texture("/Contents/Resources/Sprites/die_part1.raw")
	var burst_texture := _load_raw_texture("/Contents/Resources/Sprites/die_part2.raw")
	var starts: Array[Vector2i] = [level.player_one, level.player_two]
	for avatar_index in session_rules.avatar_count:
		var number: int = avatar_index + 1
		var normal_texture := _load_raw_texture("/Contents/Resources/Sprites/player%d.raw" % number)
		var flash_texture := _load_raw_texture("/Contents/Resources/Sprites/player%d_flash.raw" % number)
		var sprite := Sprite2D.new()
		sprite.texture = normal_texture
		sprite.region_enabled = true
		# Both player sheets are 16x2 grids of 32-pixel animation frames.
		sprite.region_rect = PlayerSpriteLayoutScript.initial_idle_region()
		sprite.position = Vector2(PlayerMotionScript.pixel_for_cell(starts[avatar_index]) + Vector2i(16, 16))
		level_root.add_child(sprite)
		var motion = PlayerMotionScript.new(topology, starts[avatar_index])
		motion.frame = PlayerSpriteLayoutScript.INITIAL_IDLE_FRAME
		player_start_cells.append(starts[avatar_index])
		player_motions.append(motion)
		player_effects_by_avatar.append(PlayerEffectsScript.new())
		player_sprites.append(sprite)
		player_active.append(true)
		player_normal_textures.append(normal_texture)
		player_flash_textures.append(flash_texture)
		player_death_textures.append(death_texture)
		player_burst_textures.append(burst_texture)
		ghosts_eaten_by_avatar.append(0)
	# Compatibility aliases keep the proven solo code path and QA hooks intact.
	player_start_cell = player_start_cells[0]
	player_motion = player_motions[0]
	player_effects = player_effects_by_avatar[0]
	player_sprite = player_sprites[0]
	player_texture = player_normal_textures[0]
	player_flash_texture = player_flash_textures[0]
	player_death_texture = player_death_textures[0]
	player_death_burst_texture = player_burst_textures[0]
	heart_texture = _load_raw_texture("/Contents/Resources/Sprites/heart.raw")
	$Hud/PlayerIcon.texture = player_texture
	$Hud/PlayerIcon.region_rect = Rect2(6 * 32, 0, 32, 32)
	$Hud/SecondPlayer.visible = session_rules.avatar_count > 1
	if session_rules.avatar_count > 1:
		$Hud/SecondPlayer/PlayerIcon.texture = player_normal_textures[1]
		$Hud/SecondPlayer/PlayerIcon.region_rect = Rect2(6 * 32, 0, 32, 32)
	hud_lives = -1
	hud_lives_signature = ""


func _add_extra_system(source_archive: String, topology) -> void:
	extra_spawner = ExtraSpawnerScript.new(topology, TICKS_PER_SECOND)
	var entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
		source_archive, "/Contents/Resources/Sprites/extra.raw"
	)
	if entry.has("error"):
		return
	var decoded: Dictionary = RawSpriteScript.new().decode(entry["bytes"])
	if not decoded.has("error"):
		extra_texture = ImageTexture.create_from_image(decoded["image"])


func _add_ghosts(archive_path: String, topology) -> void:
	var entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
		archive_path, "/Contents/Resources/Sprites/ghost.raw"
	)
	if entry.has("error"):
		return
	var decoded: Dictionary = RawSpriteScript.new().decode(entry["bytes"])
	if decoded.has("error"):
		return
	ghost_texture = ImageTexture.create_from_image(decoded["image"])
	var run_entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
		archive_path, "/Contents/Resources/Sprites/ghost_run.raw"
	)
	if not run_entry.has("error"):
		var run_decoded: Dictionary = RawSpriteScript.new().decode(run_entry["bytes"])
		if not run_decoded.has("error"):
			frightened_ghost_texture = ImageTexture.create_from_image(run_decoded["image"])

	var entry_cell: Vector2i = topology.citadel_entry()
	if entry_cell.x < 0:
		return
	var spawn_cells := [
		entry_cell,
		entry_cell + Vector2i(-1, 1),
		entry_cell + Vector2i(0, 1),
		entry_cell + Vector2i(1, 1),
	]
	for number in 4:
		var return_cell: Vector2i = spawn_cells[number]
		if number == 0:
			return_cell = entry_cell + Vector2i.DOWN
		var motion = GhostMotionScript.new(
			topology, spawn_cells[number], number, return_cell, difficulty
		)
		if number == 0:
			motion.direction = MazeDirectionScript.LEFT
			motion.start_hunting(true)
		else:
			motion.direction = MazeDirectionScript.DOWN
		var sprite := Sprite2D.new()
		sprite.region_enabled = true
		ghost_motions.append(motion)
		ghost_sprites.append(sprite)
		level_root.add_child(sprite)
		_update_ghost_sprite(number)


func _add_spotlight() -> void:
	if not DifficultyRulesScript.uses_spotlight(difficulty) or player_motions.is_empty():
		return
	var texture := _load_raw_texture("/Contents/Resources/Sprites/spot.raw")
	if texture == null:
		return
	spotlight_view = SpotlightViewScript.new()
	spotlight_view.z_index = SPOTLIGHT_Z_INDEX
	level_root.add_child(spotlight_view)
	spotlight_view.show_spot(texture)
	spotlight_view.follow_player(player_motions[0].position)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_pressed() and event.keycode == KEY_ESCAPE:
		if menu_active:
			get_tree().quit()
		else:
			if name_entry_active:
				_submit_high_score_name("")
			_end_current_game()
		return
	if name_entry_active:
		return
	if event.is_pressed() and event.keycode == KEY_M:
		music_enabled = not music_enabled
		if music_enabled:
			_play_music(current_music_name if not current_music_name.is_empty() else "PacManiac")
		else:
			$Music.stop()
		return
	if menu_active and event.is_pressed():
		match event.keycode:
			KEY_D:
				difficulty = difficulty % DifficultyRulesScript.Level.MASTER + 1
				_refresh_mode_menu_text()
			KEY_1, KEY_KP_1, KEY_ENTER:
				_begin_mode(SessionRulesScript.Mode.SOLO, "standard")
			KEY_2, KEY_KP_2:
				_begin_mode(SessionRulesScript.Mode.SIMULTANEOUS, "standard")
			KEY_T, KEY_3, KEY_KP_3:
				_begin_mode(SessionRulesScript.Mode.TWO_HANDED, "standard")
			KEY_4, KEY_KP_4:
				_begin_mode(SessionRulesScript.Mode.SOLO, "x")
		return
	if event.is_pressed() and event.keycode in [KEY_P, KEY_SPACE] and not game_over and not game_finished:
		_toggle_pause()
		return
	if paused_game:
		return
	if event.is_pressed() and (game_over or game_finished) and event.keycode in [KEY_ENTER, KEY_R]:
		score_states.clear()
		for ignored in session_rules.account_count:
			score_states.append(ScoreStateScript.new())
		score_state = score_states[0]
		score_recorded = false
		game_over = false
		game_finished = false
		_start_level(0)
		_play_music("PacManiac")
		return
	if player_motion == null or game_over or game_finished or level_transition_pending or player_dying_ticks > 0:
		return
	var avatar_index := 0
	var requested := MazeDirectionScript.NONE
	match event.keycode:
		KEY_LEFT:
			requested = MazeDirectionScript.LEFT
		KEY_RIGHT:
			requested = MazeDirectionScript.RIGHT
		KEY_UP:
			requested = MazeDirectionScript.UP
		KEY_DOWN:
			requested = MazeDirectionScript.DOWN
		KEY_A:
			requested = MazeDirectionScript.LEFT
			avatar_index = 1 if session_rules.avatar_count > 1 else 0
		KEY_D:
			requested = MazeDirectionScript.RIGHT
			avatar_index = 1 if session_rules.avatar_count > 1 else 0
		KEY_W:
			requested = MazeDirectionScript.UP
			avatar_index = 1 if session_rules.avatar_count > 1 else 0
		KEY_S:
			requested = MazeDirectionScript.DOWN
			avatar_index = 1 if session_rules.avatar_count > 1 else 0
	if requested == MazeDirectionScript.NONE:
		return
	if avatar_index >= player_motions.size() or not player_active[avatar_index]:
		return
	if event.is_pressed():
		player_motions[avatar_index].request(requested)
	else:
		player_motions[avatar_index].release(requested)


func _physics_process(_delta: float) -> void:
	if menu_active or paused_game or player_motion == null or player_sprite == null or game_over or game_finished:
		return
	_step_point_popups()
	if ghost_eat_pause_ticks > 0:
		ghost_eat_pause_ticks -= 1
		if ghost_eat_pause_ticks == 0:
			_finish_ghost_eat_pause()
		return
	if level_transition_pending:
		level_transition_ticks -= 1
		if level_transition_ticks <= 0:
			_advance_level()
		return
	if round_start_ticks > 0:
		for avatar_index in player_motions.size():
			if player_active[avatar_index]:
				player_motions[avatar_index].frame += 1
				_sync_player_sprite(avatar_index)
		if spotlight_view != null and not player_motions.is_empty():
			spotlight_view.follow_player(player_motions[0].position)
		round_start_ticks -= 1
		if round_start_ticks == 0 and ready_sprite != null:
			ready_sprite.visible = false
		return
	if player_dying_ticks > 0:
		_step_player_dying()
		return
	for avatar_index in player_motions.size():
		if not player_active[avatar_index]:
			continue
		var effects = player_effects_by_avatar[avatar_index]
		var motion = player_motions[avatar_index]
		var sprite: Sprite2D = player_sprites[avatar_index]
		effects.step()
		motion.step(effects.double_speed)
		_sync_player_sprite(avatar_index)
	if spotlight_view != null and not player_motions.is_empty():
		spotlight_view.follow_player(player_motions[0].position)
	for index in ghost_motions.size():
		ghost_motions[index].step(_ghost_target_position(index))
		_update_ghost_sprite(index)
	_step_ghost_release()
	for avatar_index in player_motions.size():
		if player_active[avatar_index]:
			_collect_pellet_for_avatar(avatar_index)
	_step_extra()
	_handle_ghost_collisions()
	if pellet_field.remaining() == 0 and not game_over:
		level_transition_pending = true
		level_transition_ticks = LEVEL_CLEAR_DURATION_TICKS
		_play_sound("level_clear")


func _ghost_target_position(ghost_number: int) -> Vector2:
	if player_motions.size() == 1:
		return player_motions[0].position
	var preferred := ghost_number % 2
	if preferred < player_motions.size() and player_active[preferred]:
		return player_motions[preferred].position
	for avatar_index in player_motions.size():
		if player_active[avatar_index]:
			return player_motions[avatar_index].position
	return player_motion.position


func _collect_pellet_for_avatar(avatar_index: int) -> void:
	var collected: Dictionary = pellet_field.collect(player_motions[avatar_index].position)
	if collected["points"] <= 0:
		return
	var effects = player_effects_by_avatar[avatar_index]
	var account = _score_for_avatar(avatar_index)
	account.double_score = effects.double_score
	_award_score_for_avatar(avatar_index, collected["points"])
	if collected["super"] > 0:
		ghosts_eaten_by_avatar[avatar_index] = 0
		for ghost in ghost_motions:
			ghost.start_frightened(FRIGHTENED_DURATION_TICKS)
		_play_sound("eat_superpellet")
		_play_sound("scared")
	else:
		_play_sound("eat_pelletB2" if pellet_sound_alternate else "eat_pelletB")
		pellet_sound_alternate = not pellet_sound_alternate
	pellet_view.field_changed()
	_update_status()


func _update_ghost_sprite(index: int) -> void:
	var motion = ghost_motions[index]
	var sprite: Sprite2D = ghost_sprites[index]
	var frightened: bool = (
		motion.state == GhostStateScript.FRIGHTENED
		or motion.state == GhostStateScript.FRIGHTENED_WAITING
	)
	sprite.texture = frightened_ghost_texture if frightened and frightened_ghost_texture != null else ghost_texture
	sprite.region_rect = GhostSpriteLayoutScript.region(
		motion.ghost_number,
		motion.direction,
		motion.frame,
		motion.state,
		motion.frightened_ticks,
	)
	sprite.position = motion.position + Vector2(16, 16)


func _step_extra() -> void:
	if extra_spawner == null:
		return
	if extra_motion == null:
		var player_positions: Array[Vector2] = []
		for avatar_index in player_motions.size():
			if player_active[avatar_index]:
				player_positions.append(player_motions[avatar_index].position)
		var spawn: Dictionary = extra_spawner.step(player_positions, pellet_field.remaining())
		if not spawn.is_empty():
			_create_extra(spawn["cell"], spawn["extra_number"])
		return
	extra_motion.step()
	extra_sprite.position = extra_motion.position + Vector2(16, 16)
	extra_sprite.region_rect = Rect2(extra_motion.animation_frame() * 32, extra_motion.extra_number * 32, 32, 32)
	extra_sprite.rotation_degrees = extra_motion.rotation_degrees
	for avatar_index in player_motions.size():
		if not player_active[avatar_index] or not extra_motion.collides(player_motions[avatar_index].position):
			continue
		var effects = player_effects_by_avatar[avatar_index]
		var account = _score_for_avatar(avatar_index)
		var double_before: bool = effects.double_score
		var points: int = effects.apply_extra(extra_motion.extra_number, TICKS_PER_SECOND)
		account.double_score = double_before
		var awarded := _award_score_for_avatar(avatar_index, points)
		account.double_score = effects.double_score
		_spawn_point_popup(player_motions[avatar_index].position, awarded)
		_play_sound("extra_eaten")
		_remove_extra()
		_update_status()
		return
	if extra_motion.expired():
		_remove_extra()


func _sync_player_sprite(avatar_index: int) -> void:
	var effects = player_effects_by_avatar[avatar_index]
	var motion = player_motions[avatar_index]
	var sprite: Sprite2D = player_sprites[avatar_index]
	var flash: Texture2D = player_flash_textures[avatar_index]
	sprite.texture = flash if effects.is_invulnerable() and flash != null else player_normal_textures[avatar_index]
	sprite.position = motion.position + Vector2(16, 16)
	sprite.region_rect = PlayerSpriteLayoutScript.region(motion.direction, motion.frame)


func _create_extra(cell: Vector2i, number: int) -> void:
	extra_motion = ExtraMotionScript.new(
		extra_spawner.topology,
		cell,
		number,
		TICKS_PER_SECOND,
	)
	extra_sprite = Sprite2D.new()
	extra_sprite.z_index = EXTRA_ABOVE_SPOTLIGHT_Z_INDEX
	extra_sprite.texture = extra_texture
	extra_sprite.region_enabled = true
	extra_sprite.region_rect = Rect2(Vector2i(32, number * 32), Vector2i(32, 32))
	extra_sprite.position = extra_motion.position + Vector2(16, 16)
	level_root.add_child(extra_sprite)
	_play_sound("extra_appear")


func _remove_extra() -> void:
	if extra_sprite != null:
		extra_sprite.queue_free()
	extra_sprite = null
	extra_motion = null
	extra_spawner.released()


func _handle_ghost_collisions() -> void:
	for ghost_index in ghost_motions.size():
		var motion = ghost_motions[ghost_index]
		for avatar_index in player_motions.size():
			if not player_active[avatar_index]:
				continue
			var effects = player_effects_by_avatar[avatar_index]
			var result := GhostCollisionScript.classify(
				player_motions[avatar_index].position,
				motion.position,
				motion.state,
				effects.is_invulnerable(),
			)
			if result == GhostCollisionScript.GHOST_EATEN:
				motion.start_returning()
				ghost_sprites[ghost_index].visible = false
				ghost_eat_hidden_index = ghost_index
				var awarded := _award_score_for_avatar(
					avatar_index,
					ScoreStateScript.ghost_points(level_number, ghosts_eaten_by_avatar[avatar_index]),
				)
				_spawn_point_popup(player_motions[avatar_index].position, awarded)
				ghosts_eaten_by_avatar[avatar_index] += 1
				_play_sound("eat_ghost")
				ghost_eat_pause_ticks = GHOST_EAT_PAUSE_TICKS
				_update_status()
				return
			elif result == GhostCollisionScript.PLAYER_HIT:
				var account = _score_for_avatar(avatar_index)
				account.lives = maxi(account.lives - 1, 0)
				effects.reset_on_death()
				account.double_score = false
				_start_player_dying(avatar_index)
				_update_status()
				return


func _finish_ghost_eat_pause() -> void:
	if ghost_eat_hidden_index >= 0 and ghost_eat_hidden_index < ghost_sprites.size():
		ghost_sprites[ghost_eat_hidden_index].visible = true
		_update_ghost_sprite(ghost_eat_hidden_index)
	ghost_eat_hidden_index = -1


func _start_player_dying(avatar_index: int) -> void:
	player_dying_index = avatar_index
	player_dying_ticks = 3 * TICKS_PER_SECOND
	var motion = player_motions[avatar_index]
	var sprite: Sprite2D = player_sprites[avatar_index]
	motion.direction = MazeDirectionScript.NONE
	motion.requested_direction = MazeDirectionScript.NONE
	ghosts_eaten_by_avatar[avatar_index] = 0
	for index in ghost_motions.size():
		ghost_motions[index].reset_to_spawn()
		ghost_sprites[index].visible = false
	if player_death_textures[avatar_index] != null:
		sprite.texture = player_death_textures[avatar_index]
		sprite.region_rect = Rect2(0, 0, 32, 32)
	_play_sound("player_die")


func _step_player_dying() -> void:
	var avatar_index := player_dying_index
	if avatar_index < 0 or avatar_index >= player_sprites.size():
		player_dying_ticks = 0
		return
	var motion = player_motions[avatar_index]
	var sprite: Sprite2D = player_sprites[avatar_index]
	var death_texture: Texture2D = player_death_textures[avatar_index]
	var burst_texture: Texture2D = player_burst_textures[avatar_index]
	player_dying_ticks -= 1
	var elapsed_ticks := 3 * TICKS_PER_SECOND - player_dying_ticks
	var animation_frame := int(float(elapsed_ticks) * 18.0 / TICKS_PER_SECOND)
	if animation_frame < 16 and death_texture != null:
		sprite.texture = death_texture
		sprite.region_rect = Rect2(animation_frame * 32, 0, 32, 32)
		sprite.visible = true
	elif animation_frame < 32 and burst_texture != null:
		var burst_frame := animation_frame - 16
		sprite.texture = burst_texture
		sprite.region_rect = Rect2((burst_frame % 8) * 96, (burst_frame / 8) * 96, 96, 96)
		sprite.visible = true
	else:
		sprite.visible = false
	if player_dying_ticks > 0:
		return
	var account = _score_for_avatar(avatar_index)
	for eliminated_index in session_rules.eliminated_avatars_after_death(avatar_index, account.lives):
		player_active[eliminated_index] = false
		player_sprites[eliminated_index].visible = false
	if _all_players_out():
		game_over = true
		$Music.stop()
		_play_sound("gameover")
		_prompt_for_high_score()
		_update_status()
		return
	if player_active[avatar_index]:
		sprite.visible = true
		motion.position = Vector2(PlayerMotionScript.pixel_for_cell(player_start_cells[avatar_index]))
		sprite.position = motion.position + Vector2(16, 16)
		sprite.texture = player_normal_textures[avatar_index]
		motion.frame = PlayerSpriteLayoutScript.INITIAL_IDLE_FRAME
		sprite.region_rect = PlayerSpriteLayoutScript.initial_idle_region()
	for index in ghost_motions.size():
		ghost_motions[index].reset_to_spawn()
		ghost_sprites[index].visible = true
		_update_ghost_sprite(index)
	round_start_ticks = TICKS_PER_SECOND
	if ready_sprite != null:
		ready_sprite.visible = true
	player_dying_index = -1


func _all_players_out() -> bool:
	for active in player_active:
		if active:
			return false
	return true


func _account_double_score_active(account_index: int) -> bool:
	for avatar_index in player_effects_by_avatar.size():
		if session_rules.score_owner(avatar_index) == account_index:
			var effects = player_effects_by_avatar[avatar_index]
			if effects != null and effects.double_score:
				return true
	return false


func _advance_level() -> void:
	if level_number + 1 >= levels.size():
		game_finished = true
		$Music.stop()
		if ready_sprite != null:
			ready_sprite.visible = false
		var ending_texture := _load_raw_texture("/Contents/Resources/Sprites/the_end.raw")
		if ending_texture != null:
			var ending := Sprite2D.new()
			ending.texture = ending_texture
			ending.position = Vector2(320, 115)
			level_root.add_child(ending)
		_prompt_for_high_score()
		level_transition_pending = false
		_update_status()
		return
	_start_level(level_number + 1)


func _step_ghost_release() -> void:
	ghost_release_ticks -= 1
	if ghost_release_ticks > 0:
		return
	ghost_release_ticks = GhostReleaseScheduleScript.delay_seconds(level_number) * TICKS_PER_SECOND
	for motion in ghost_motions:
		if motion.state == GhostStateScript.WAITING:
			motion.start_hunting(false)
			_play_sound("ghost_starts")
			return
		if motion.state == GhostStateScript.FRIGHTENED_WAITING:
			motion.state = GhostStateScript.FRIGHTENED
			motion.reached_target = false
			_play_sound("ghost_starts")
			return


func _update_status() -> void:
	$Hud/Score.text = "%06d" % score_state.score
	if hud_score_text != null:
		hud_score_text.position = Vector2(104, 3) if _account_double_score_active(0) else Vector2(72, 3)
		hud_score_text.show_text("%06d" % score_state.score, 0)
	if session_rules.mode == SessionRulesScript.Mode.SIMULTANEOUS:
		$Hud/SecondPlayer/Score.text = "%06d" % score_states[1].score
		if hud_second_score_text != null:
			hud_second_score_text.show_text("%06d" % score_states[1].score, 1)
	elif session_rules.mode == SessionRulesScript.Mode.TWO_HANDED:
		$Hud/SecondPlayer/Score.text = "SHARED"
		if hud_second_score_text != null:
			hud_second_score_text.show_text("SHARED", 1, -2)
	$Hud/LevelNumber.text = "%d" % (level_number + 1)
	if hud_level_text != null:
		hud_level_text.show_text("%d" % (level_number + 1), 2)
	if hud_double_texts.size() > 0:
		hud_double_texts[0].visible = _account_double_score_active(0)
	if hud_double_texts.size() > 1 and score_states.size() > 1:
		hud_double_texts[1].visible = (
			session_rules.mode == SessionRulesScript.Mode.SIMULTANEOUS
			and _account_double_score_active(1)
		)
	_update_life_display()
	if name_entry_active:
		$Status.text = "Type name, press Enter"
		_show_high_scores()
		return
	if game_over:
		$Status.text = "Enter/R to restart"
		_show_high_scores()
		return
	if game_finished:
		$Status.text = "Enter/R to restart"
		_show_high_scores()
		return
	$HighScorePanel.visible = false
	$Status.text = ""


func _toggle_pause() -> void:
	paused_game = not paused_game
	if pause_sprite == null:
		var texture := _load_raw_texture("/Contents/Resources/Sprites/pause.raw")
		if texture != null:
			pause_sprite = Sprite2D.new()
			pause_sprite.texture = texture
			pause_sprite.position = Vector2(320, 240)
			level_root.add_child(pause_sprite)
	if pause_sprite != null:
		pause_sprite.visible = paused_game


func _show_mode_menu() -> void:
	var texture := _load_raw_texture("/Contents/Resources/Sprites/title.raw")
	if texture != null:
		$ModeMenu/Title.texture = texture
	$ModeMenu.visible = true
	menu_active = true
	_refresh_mode_menu_text()
	_play_music("PacTitle")


func _refresh_mode_menu_text(master_warning := false) -> void:
	var warning := "\nMASTER IS SOLO ONLY" if master_warning else ""
	$ModeMenu/Choices/Text.text = (
		"1 / Enter   STANDARD SOLO — arrows or WASD\n"
		+ "2             STANDARD TWO PLAYERS — arrows + WASD\n"
		+ "3 / T         STANDARD TWO-HANDED — shared score/lives\n"
		+ "4             X LEVELS SOLO — bonus levels\n\n"
		+ "D changes difficulty: %s\n" % DifficultyRulesScript.label(difficulty).to_upper()
		+ "P / Space pauses · M music · Esc exits"
		+ warning
	)


func _end_current_game() -> void:
	name_entry_active = false
	$NameEntry.visible = false
	$NameEntry/Panel/Name.release_focus()
	game_over = false
	game_finished = false
	level_transition_pending = false
	_clear_level()
	_show_mode_menu()


func _begin_mode(mode: int, requested_pack := "x") -> void:
	if DifficultyRulesScript.uses_spotlight(difficulty) and mode != SessionRulesScript.Mode.SOLO:
		_refresh_mode_menu_text(true)
		return
	menu_active = false
	$ModeMenu.visible = false
	if requested_pack != level_pack and not _load_level_pack(requested_pack):
		requested_pack = level_pack
	session_rules = SessionRulesScript.new(mode, 2)
	high_score_category = _current_high_score_category()
	score_states.clear()
	for ignored in session_rules.account_count:
		score_states.append(ScoreStateScript.new())
	score_state = score_states[0]
	score_recorded = false
	game_over = false
	game_finished = false
	_start_level(0)
	_play_music("PacManiac")


func _update_life_display() -> void:
	if score_state == null:
		return
	var signature_parts := PackedStringArray()
	for account in score_states:
		signature_parts.append(str(account.lives))
	var signature := ",".join(signature_parts)
	if signature == hud_lives_signature:
		return
	hud_lives_signature = signature
	for child in $Hud/Lives.get_children():
		child.queue_free()
	for child in $Hud/SecondPlayer/Lives.get_children():
		child.queue_free()
	if heart_texture == null:
		return
	# The original HUD shows spare lives; the current avatar is represented by its icon.
	for index in maxi(score_state.lives - 1, 0):
		var heart := Sprite2D.new()
		heart.texture = heart_texture
		heart.position = Vector2(16, 54 + index * 18)
		$Hud/Lives.add_child(heart)
	if session_rules.mode == SessionRulesScript.Mode.SIMULTANEOUS:
		for index in maxi(score_states[1].lives - 1, 0):
			var heart := Sprite2D.new()
			heart.texture = heart_texture
			heart.position = Vector2(624, 54 + index * 18)
			$Hud/SecondPlayer/Lives.add_child(heart)


func _record_score() -> void:
	_record_score_named("")


func _record_score_named(player_name: String) -> void:
	if score_recorded or high_scores == null:
		return
	var total_score := 0
	for account in score_states:
		total_score += account.score
	var label := player_name.strip_edges()
	if label.is_empty():
		label = "PLAYER"
		if session_rules.mode == SessionRulesScript.Mode.SIMULTANEOUS:
			label = "%dP TEAM" % session_rules.avatar_count
		elif session_rules.mode == SessionRulesScript.Mode.TWO_HANDED:
			label = "TWO-HANDED"
	high_scores.record(high_score_category, label, total_score)
	high_scores.save_scores()
	score_recorded = true


func _prompt_for_high_score() -> void:
	if score_recorded or high_scores == null:
		return
	var total_score := 0
	for account in score_states:
		total_score += account.score
	if not high_scores.qualifies(high_score_category, total_score):
		score_recorded = true
		return
	name_entry_active = true
	$NameEntry.visible = true
	$NameEntry/Panel/Prompt.text = (
		"NEW %s HIGH SCORE — ENTER NAME" % high_score_category.replace("_", " ").to_upper()
	)
	$NameEntry/Panel/Name.text = ""
	$NameEntry/Panel/Name.grab_focus()


func _submit_high_score_name(value: String) -> void:
	if not name_entry_active:
		return
	name_entry_active = false
	$NameEntry.visible = false
	_record_score_named(value)
	_show_high_scores()


func _award_score(points: int) -> int:
	return _award_score_for_avatar(0, points)


func _score_for_avatar(avatar_index: int):
	return score_states[session_rules.score_owner(avatar_index)]


func _award_score_for_avatar(avatar_index: int, points: int) -> int:
	var account = _score_for_avatar(avatar_index)
	var old_lives: int = account.lives
	var awarded: int = account.add(points)
	if account.lives > old_lives:
		_play_sound("extra_life")
	return awarded


func _spawn_point_popup(collision_position: Vector2, points: int) -> void:
	if point_texture == null or points <= 0:
		return
	var popup = PointPopupViewScript.new()
	level_root.add_child(popup)
	popup.show_points(point_texture, points, collision_position, point_popup_color)
	point_popups.append(popup)
	point_popup_color = (point_popup_color + 1) % 5


func _step_point_popups() -> void:
	for index in range(point_popups.size() - 1, -1, -1):
		var popup = point_popups[index]
		if not is_instance_valid(popup) or popup.expired():
			point_popups.remove_at(index)
			continue
		# The recovered point animation runs at 60 Hz; gameplay runs at 30 Hz.
		popup.step_reference_frames(2)


func _play_sound(sound_name: String) -> void:
	var stream: AudioStream = sound_cache.get(sound_name)
	if stream == null:
		var entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
			archive_path, "/Contents/Resources/Sounds/%s.wav" % sound_name
		)
		if entry.has("error"):
			return
		var decoded: Dictionary = WavAudioScript.new().decode(entry["bytes"])
		if decoded.has("error"):
			return
		stream = decoded["stream"]
		sound_cache[sound_name] = stream
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _play_music(music_name: String) -> void:
	current_music_name = music_name
	if not music_enabled or music_name.is_empty():
		return
	var stream: AudioStreamMP3 = music_cache.get(music_name)
	if stream == null:
		var entry: Dictionary = OriginalArchiveScript.new().read_file_by_suffix(
			archive_path, "/Contents/Resources/Music/%s.mp3" % music_name
		)
		if entry.has("error"):
			return
		stream = AudioStreamMP3.load_from_buffer(entry["bytes"])
		if stream == null:
			return
		stream.loop = true
		music_cache[music_name] = stream
	$Music.stream = stream
	$Music.play()


func _show_high_scores() -> void:
	$HighScorePanel.visible = true
	if game_over and game_over_sprite == null:
		var texture := _load_raw_texture("/Contents/Resources/Sprites/game_over.raw")
		if texture != null:
			game_over_sprite = Sprite2D.new()
			game_over_sprite.texture = texture
			game_over_sprite.position = Vector2(320, 115)
			level_root.add_child(game_over_sprite)
	var heading := high_score_category.replace("_", " ").to_upper() + " HIGH SCORES"
	var lines: PackedStringArray = [heading, ""]
	var stored: Array = high_scores.entries(high_score_category) if high_scores != null else []
	if stored.is_empty():
		lines.append("No scores yet")
	else:
		for index in mini(stored.size(), 8):
			var entry: Dictionary = stored[index]
			lines.append("%2d. %-12s %06d" % [index + 1, entry["name"], entry["score"]])
	$HighScorePanel/HighScores.text = "\n".join(lines)

extends SceneTree

var game
var output = ""
var board: Node2D
var viewport: SubViewport
var mode = 0
var old_graphic: Dictionary
var original_actor: HordeActor
var before_actor: HordeActor

func _initialize() -> void: call_deferred("run")

func draw_board() -> void:
	board.draw_rect(Rect2(0, 0, 1920, 1200), Color("2b2237"))
	for i in range(12):
		var state = i / 2 if mode == 1 else 0
		var index = 0 if mode == 1 else i % 16
		if mode == 1:
			state = [0, 1, 2, 4, 5, 7][int(i / 2)]
			index = mini(int(game.item_lab.spec(0, state).x) - 1, 3)
		var pose: Dictionary = game.item_lab.sample(0, state, index)
		var left = i % 6 * 320
		var top = int(i / 6) * 600
		board.draw_string(ThemeDB.fallback_font, Vector2(left + 14, top + 28), "%s %d" % [game.item_lab.LABELS[state], index + 1], HORIZONTAL_ALIGNMENT_LEFT, 300, 20, Color.WHITE)
		for row in range(2):
			var foot = Vector2(left + 145, top + 295 + row * 280)
			var actor = before_actor if row == 0 else original_actor
			actor.paint(board, 0, foot, 220, pose.phase, pose.state, pose.time, pose.landing, Color.WHITE, i % 2 == 1, 1.0, true, pose.air_age, pose.vertical_speed, ["z_adventure"])
			board.draw_string(ThemeDB.fallback_font, Vector2(left + 10, foot.y + 18), "ANTES" if row == 0 else "DEPOIS", HORIZONTAL_ALIGNMENT_LEFT, 300, 17, Color("9ce4c7"))

func shot(name: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await game.capture_frame(output.path_join(name + ".png"))

func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = load("res://main.tscn").instantiate()
	viewport.add_child(game)
	game.test_mode = true;game.capture_mode = true
	game.set_process(false);game.set_physics_process(false)
	game.change_screen("developer");game.perform_action("item_lab_open")
	game.item_lab.selected = 5;game.item_lab.paused = true;game.item_lab.cursor = 5.0
	game.item_lab.zoom_index = 2
	original_actor = game.actor
	original_actor.cosmetics.ensure_data()
	before_actor = HordeActor.new(game.art)
	before_actor.cosmetics.ensure_data()
	before_actor.cosmetics.graphics["z_adventure"] = JSON.parse_string(FileAccess.get_file_as_string("res://tests/v119_before_adventure.json"))
	game.actor = before_actor
	await shot("adventure_before_zoom")
	game.actor = original_actor;game.item_lab.bounds_cache.clear()
	await shot("adventure_after_zoom")
	game.item_lab.zoom_index = 0
	await shot("adventure_after_full")
	game.item_lab.compare = true
	game.item_lab.zoom_index = 1
	await shot("adventure_after_compare")
	game.hide()
	viewport.size = Vector2i(1920, 1200)
	board = Node2D.new();viewport.add_child(board);board.draw.connect(draw_board)
	for m in range(2):
		mode = m;board.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output.path_join("adventure_board_%d.png" % m))
	print("V119_ADVENTURE_VISUAL_COMPLETE")
	game.queue_free();board.queue_free()
	await process_frame
	quit()

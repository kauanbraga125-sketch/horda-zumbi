extends SceneTree

const ITEMS = [["z_clown", "CABELO DO PALHAÇO", 1]]
var game
var viewport: SubViewport
var canvas: Node2D
var before_actor
var mode = 0
var active_id = "z_cyber"
var output = ""

func _initialize() -> void: call_deferred("run")

func draw_board() -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, viewport.size), Color("2b2237"))
	if mode == 0:
		for col in range(ITEMS.size()):
			var info = ITEMS[col]
			canvas.draw_string(ThemeDB.fallback_font, Vector2(col*960+15, 38), info[1], HORIZONTAL_ALIGNMENT_LEFT, 920, 29, Color("ffcf76"))
			for row in range(2):
				canvas.draw_string(ThemeDB.fallback_font, Vector2(col*960+15, 90+row*580), "ANTES — v0.10.24" if row == 0 else "DEPOIS — v0.10.25", HORIZONTAL_ALIGNMENT_LEFT, 920, 26, Color("9ce4c7"))
				var pose = game.item_lab.sample(0, 0, info[2])
				var actor = before_actor if row == 0 else game.actor
				for reverse in [false, true]:
					actor.paint(canvas, 0, Vector2(col*960+270+int(reverse)*425, 550+row*580), 400, pose.phase, pose.state, pose.time, pose.landing, Color.WHITE, reverse, 1.0, true, pose.air_age, pose.vertical_speed, [info[0]])
	else:
		for i in range(18):
			var state = int(i/2)
			var pose = game.item_lab.sample(0, state, mini(2, int(game.item_lab.spec(0,state).x)-1))
			var x = i%6*320
			var y = int(i/6)*400
			canvas.draw_string(ThemeDB.fallback_font, Vector2(x+10,y+25), game.item_lab.LABELS[state], HORIZONTAL_ALIGNMENT_LEFT, 300, 20, Color("9ce4c7"))
			game.actor.paint(canvas, 0, Vector2(x+150,y+385), 300, pose.phase, pose.state, pose.time, pose.landing, Color.WHITE, i%2==1, 1.0, true, pose.air_age, pose.vertical_speed, [active_id])

func shot(path: String) -> void:
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(path+".png"))

func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new();viewport.size=Vector2i(960,1200)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game=load("res://main.tscn").instantiate();viewport.add_child(game)
	game.test_mode=true;game.capture_mode=true;game.set_process(false);game.set_physics_process(false);game.hide()
	before_actor=HordeActor.new(game.art)
	before_actor.cosmetics=load("res://tests/v125_original_cosmetics.gd").new();before_actor.cosmetics.ensure_data()
	before_actor.cosmetics.graphics=JSON.parse_string(FileAccess.get_file_as_string("res://tests/v125_before_graphics.json"))
	canvas=Node2D.new();viewport.add_child(canvas);canvas.draw.connect(draw_board)
	await shot("hair_before_after")
	mode=1;viewport.size=Vector2i(1920,1200)
	for info in ITEMS:
		active_id=info[0]
		await shot(active_id+"_nine_states")
	canvas.queue_free();game.queue_free()
	await process_frame
	print("V125_ITEMS_VISUAL_COMPLETE")
	quit()

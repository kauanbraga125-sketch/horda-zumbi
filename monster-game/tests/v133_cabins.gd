extends SceneTree
var game
var folder = ""
var checks = 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(folder)
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_physics_process(false);game.capture_freeze = true;game.test_mode = true;game.lab_count = 8;game.start_lab("space");game.sound.set_enabled(false)
	for i in range(180): game.runner.advance(1.0/60,false);game.update_camera(1.0/60);game.configure_layout()
	var s = game.runner.space;s.next_group = 1e6;s.objects.clear();s.visual.controls_left = 0;s.visual.current.clear()
	game.runner.members[0].kind = 0;game.runner.members[0].cosmetics_0 = ["z_plumber"]
	game.runner.members[1].kind = 1;game.runner.members[1].cosmetics_1 = ["s_ice"]
	for kind in ["tour_bus","fighter"]:
		s.battle.pilot_kind = kind;s.battle.pilot_left = 7;s.battle.pilot_hp = 3
		for i in range(5):
			game.queue_redraw();game.foreground_canvas.queue_redraw();game.world_canvas.queue_redraw()
			await process_frame;await RenderingServer.frame_post_draw
		var view = game.get_node("SpaceCabin") as SubViewport
		var pixels = view.get_texture().get_image();var mask = s.visual.textures[kind+"-inside"].get_image()
		var outside = 0;var inside = 0
		for y in range(400):
			for x in range(640):
				if pixels.get_pixel(x,y).a<.01: continue
				if mask.get_pixel(x,y).a<.01: outside += 1
				else: inside += 1
		check(outside==0,"occupants and hats stay inside exact window stencil "+kind)
		check(inside>200,"occupants remain visible "+kind)
		pixels.save_png(folder+"/cabin-mask-"+kind+".png")
		root.get_texture().get_image().save_png(folder+"/cabin-"+kind+".png")
		print("CABIN_MASK ",kind," inside=",inside," outside=",outside)
	game.set_process(false);game.queue_free();game = null
	for i in range(8): await process_frame
	var f = FileAccess.open(folder+"/cabins.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures}));f.close()
	print("V133_CABINS checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)

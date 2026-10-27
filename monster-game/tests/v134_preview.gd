extends "res://tests/v134_visual.gd"
## Smooth, native 30 fps replay from packaged gameplay, using the real touch route.
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720);game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false)
	flight(20,true);var s = game.runner.space;s.next_group = 0;s.left = 30;game.lab_active = false
	var touch = InputEventScreenTouch.new();touch.index = 42;touch.position = Vector2(350,420);touch.pressed = true;game._input(touch)
	for frame in range(1020):
		if s.phase=="flight" and not game.runner.dead:
			var goal = Vector2(435,405);var nearest = INF
			for e in s.objects:
				if e.taken or e.x<s.x-15 or e.x>s.x+590: continue
				if e.kind in ["gate","exit"]:
					if e.x<nearest: nearest = e.x;goal = Vector2(440,float(e.y)+s.member_height(game.runner)*.5)
				elif e.kind in ["astronaut","coin","core","alien_power","orbital_power"] and e.x<nearest:
					nearest = e.x;goal = Vector2(440,float(e.y)+s.member_height(game.runner)*.5)
				elif s.battle.SHIPS.has(e.kind) and (not bool(e.get("counter",false)) or bool(e.get("core_open",false))):
					if e.x<nearest:
						nearest = e.x;goal = Vector2(435,float(e.y)+s.member_height(game.runner)*.5)
						if e.x-s.x<235 and absf(e.y-(s.y-s.member_height(game.runner)*.5))<65: game.perform_action("space_dash")
			var delta = (goal-Vector2(s.aim_x,s.aim_y)).limit_length(42)
			var drag = InputEventScreenDrag.new();drag.index = 42;drag.position = Vector2(350,420);drag.relative = delta*game.camera_zoom
			game._input(drag)
		step(1.0/30)
		game.configure_layout();game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_jpg(folder+"/frame-%04d.jpg" % frame,.94)==OK)
		if frame%150==0: print("PREVIEW_FRAME ",frame)
	var f = FileAccess.open(folder+"/replay.json",FileAccess.WRITE);f.store_string(JSON.stringify({"frames":1020,"fps":30,"souls":game.runner.souls,"members":game.runner.active_count(),"max_horde":game.runner.max_horde,"encounters":s.routes.history,"real_touch_inputs":true,"physical_device_tested":false},"  "));f.close()
	game.set_process(false);game.queue_free();game = null
	for i in range(8): await process_frame
	print("V134_PREVIEW_OK 1020 native frames");quit()

extends "res://tests/v134_visual.gd"
## Actual input-driven replay from the APK runtime, including a real mistake.
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720);game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults();game.data.wallet = 1000000;game.data.eyes = 10000
	game.lab_count = 10;game.start_lab("sewer");game.lab_active = false
	for i in range(game.runner.members.size()):
		var m = game.runner.members[i];m.kind = i%2
		m.cosmetics_0 = ["z_plumber"] if i%4==0 else [];m.cosmetics_1 = ["s_ice"] if i%4==1 else []
	var s = game.runner.sewer;var jumped: Dictionary = {};var held_until = -1.0
	for frame in range(1140):
		if s.active and s.phase=="ride" and not game.runner.dead:
			for e in s.objects:
				if e.taken or e.kind not in ["rubble","barrel"] or jumped.has(e.get("encounter",-1)): continue
				# Let the first barrel make real contact: no invulnerability or fake losses.
				if e.kind=="barrel" and int(e.encounter)==3: continue
				var eta = (float(e.x)-float(s.boats[0].x))/s.scroll_speed(game.runner)
				if eta<.45 and eta>.20:
					game.press_at(Vector2(900,350),81);held_until = s.age+.16;jumped[e.encounter] = true
			if held_until>=0 and s.age>=held_until: game.release_touch(81);held_until = -1
		for substep in range(2):
			game.runner.advance(STEP,game.jump_held);game.update_camera(STEP);game.configure_layout();game.consume_run_events();game.update_run_visuals(STEP);game.ui_time += STEP
			game.toast_left = maxf(0,game.toast_left-STEP);game.perfect_left = maxf(0,game.perfect_left-STEP)
		game.configure_layout();game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_jpg(folder+"/frame-%04d.jpg" % frame,.94)==OK)
		if frame%180==0: print("V137_PREVIEW_FRAME ",frame)
	var report = {"version":"0.10.37","frames":1140,"fps":30,"souls":game.runner.souls,"members":game.runner.active_count(),"losses":game.runner.losses,"captures":s.captured,"completed":s.completed,"safe_jumps":s.safe_jumps,"encounters":s.history,"real_touch_inputs":true,"physical_device_tested":false}
	var file = FileAccess.open(folder+"/replay.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	game.set_process(false);game.queue_free();game = null
	for i in range(8): await process_frame
	preload("res://scripts/bird_art.gd").textures.clear();preload("res://scripts/sewer_art.gd").textures.clear()
	print("V137_PREVIEW_OK 1140 native frames");quit()

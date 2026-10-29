extends "res://tests/v134_visual.gd"
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720);game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults();game.data.wallet = 1000000;game.data.eyes = 10000
	game.lab_count = 6;game.start_lab("sewer");game.lab_active = false
	for i in range(game.runner.members.size()):
		var m = game.runner.members[i];m.kind = i%2;m.cosmetics_0 = ["z_plumber"] if i==0 else [];m.cosmetics_1 = ["s_ice"] if i==1 else []
	var s = game.runner.sewer;var acted: Dictionary = {};var held_until = -1.0;var missed_barrel = -1;var duck_inputs = 0;var contacts: Array = []
	for frame in range(1650):
		if s.active and s.phase=="ride" and not game.runner.dead:
			for e in s.objects:
				if e.taken or e.kind not in ["rubble","barrel","rotor","collapse","pipe","gate"] or acted.has(e.get("encounter",-1)): continue
				if e.kind=="barrel" and missed_barrel<0: missed_barrel = int(e.encounter)
				if e.kind=="barrel" and int(e.encounter)==missed_barrel: continue
				var eta = (float(e.x)-float(s.boats[0].x))/s.scroll_speed(game.runner)
				if e.kind in ["pipe","gate"] and eta<.53 and eta>.3:
					var button = game.buttons.filter(func(b):return b.action=="sewer_duck")
					assert(not button.is_empty());game.press_at(button[0].rect.get_center(),82);game.release_touch(82);duck_inputs += 1;acted[e.encounter] = true
				elif e.kind not in ["pipe","gate"] and eta<(.53 if e.kind=="rubble" else .45) and eta>.24:
					game.press_at(Vector2(900,350),81);held_until = s.age+.19;acted[e.encounter] = true
			if held_until>=0 and s.age>=held_until: game.release_touch(81);held_until = -1
		for substep in range(2):
			game.runner.advance(STEP,game.jump_held);game.update_camera(STEP);game.configure_layout()
			for event in game.runner.events:
				if event.type=="sewer_hit": contacts.append({"time":s.ride_age,"cause":event.get("cause",""),"members":game.runner.active_count()})
			game.consume_run_events();game.update_run_visuals(STEP);game.ui_time += STEP
			game.toast_left = maxf(0,game.toast_left-STEP);game.perfect_left = maxf(0,game.perfect_left-STEP)
		game.configure_layout();game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_jpg(folder+"/frame-%04d.jpg" % frame,.94)==OK)
		if frame%180==0: print("V140_PREVIEW_FRAME ",frame)
	var report = {"version":"0.10.40","frames":1650,"fps":30,"souls":game.runner.souls,"members":game.runner.active_count(),"losses":game.runner.losses,"captures":s.captured,"fugitive_variants":s.history.filter(func(h):return h.kind=="fugitive"),"completed":s.completed,"safe_passes":s.safe_jumps,"duck_inputs":duck_inputs,"controlled_obstacles":acted.size(),"encounters":s.history,"contacts":contacts,"real_touch_inputs":true,"dock_arrival":true,"physical_device_tested":false}
	var file = FileAccess.open(folder+"/replay.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	assert(s.completed==1 and not s.active and duck_inputs>=2)
	game.set_process(false);game.queue_free();game = null
	for i in range(8): await process_frame
	preload("res://scripts/bird_art.gd").textures.clear();preload("res://scripts/sewer_art.gd").textures.clear()
	print("V140_PREVIEW_OK 1650 native frames");quit()

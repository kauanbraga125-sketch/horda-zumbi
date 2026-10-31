extends "res://tests/v134_visual.gd"
## Previa nativa curta de uma queda completa, usando o codigo real da corrida.
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	assert(not folder.is_empty())
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.capture_freeze = true
	game.set_physics_process(false)
	game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults()
	game.data.wallet = 1000000
	game.data.eyes = 10000
	game.lab_count = 6
	game.start_lab("sewer")
	game.runner.start_developer("sewer",6,0,14142)
	game.runner.developer_kind = ""
	game.runner.power_owned = [3,4]
	game.runner.entities.clear()
	game.runner.events.clear()
	game.runner.sewer.encounter.offer(game.runner,true)
	game.lab_active = false
	for i in range(game.runner.members.size()):
		var m = game.runner.members[i]
		m.kind = i%2
		m.cosmetics_0 = ["z_plumber"] if i==0 else []
		m.cosmetics_1 = ["s_ice"] if i==1 else []
	var entry_started: bool = false
	var entry_finished: bool = false
	var frames: int = 360
	var samples: Array = []
	for frame in range(frames):
		for substep in range(2):
			game.runner.advance(STEP,false)
			game.update_camera(STEP)
			game.configure_layout()
			game.consume_run_events()
			game.update_run_visuals(STEP)
			game.ui_time += STEP
			game.toast_left = maxf(0,game.toast_left-STEP)
			game.perfect_left = maxf(0,game.perfect_left-STEP)
		var s = game.runner.sewer
		if s.active and s.phase=="entry": entry_started = true
		if s.active and s.phase=="ride": entry_finished = true
		if frame%12==0:
			samples.append({"time":float(frame)/30.0,"phase":s.phase,"phase_age":s.phase_age,"camera_zoom":game.camera_zoom,"drop":s.entry_drop(),"street_alpha":game.sewer_street_canvas.modulate.a,"members":game.runner.active_count()})
		game.configure_layout()
		game.queue_redraw()
		game.world_canvas.queue_redraw()
		game.foreground_canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_jpg(folder+"/frame-%04d.jpg" % frame,.90)==OK)
		if frame%90==0: print("V142_PREVIEW_FRAME ",frame)
	var summary = {"version":"0.10.42","frames":frames,"fps":30,"entry_started":entry_started,"entry_finished":entry_finished,"members":game.runner.active_count(),"samples":samples,"physical_device_tested":false}
	var report = FileAccess.open(folder+"/transicao.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(summary,"  "))
	report.close()
	assert(entry_started and entry_finished and not game.runner.dead and game.runner.active_count()==6)
	game.set_process(false)
	game.queue_free()
	game = null
	for i in range(8): await process_frame
	print("V142_PREVIEW_OK ",frames," native frames")
	quit()

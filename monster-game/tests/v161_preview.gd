extends SceneTree

const STEP = 1.0/60.0
var game

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	var choice = OS.get_environment("HORDA_CHOICE")
	assert(not folder.is_empty() and choice in ["sky","sewer","street"])
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.capture_freeze = true
	game.set_physics_process(false)
	game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults()
	game.lab_count = 6
	game.start_lab("gap")
	var r = game.runner
	r.start_developer("gap",6,0,16161)
	r.developer_kind = ""
	r.entities.clear()
	r.rebuild_surfaces()
	r.next_pattern_world = 1e9
	r.bonus_director.next_window = 1e9
	game.lab_active = false
	assert(r.sewer.encounter.offer(r,true,"both"))
	game.camera_zoom = game.CAMERA_BASE_ZOOM
	game.camera_ground_shift = 0.0
	game.camera_sewer_pan = 0.0
	game.configure_layout()
	var overlay = CanvasLayer.new()
	root.add_child(overlay)
	var caption = Label.new()
	caption.position = Vector2(28,163)
	caption.add_theme_font_size_override("font_size",23)
	caption.add_theme_constant_override("outline_size",7)
	caption.add_theme_color_override("font_outline_color",Color("100c1b"))
	caption.text = {"sky":"1/3  PULA-PULA: SUBIDA", "sewer":"2/3  SEGUIR EM FRENTE: ESGOTO", "street":"3/3  PULAR E SEGURAR: CONTINUAR NA RUA"}[choice]
	overlay.add_child(caption)
	var pressed_at = -1.0
	var frames = {"sky":210,"sewer":310,"street":180}[choice]
	var trace: Array = []
	for frame in range(frames):
		for substep in range(2):
			if not r.sky.active and not r.sewer.active and pressed_at<0 and choice!="sewer":
				var lead = r.leader_index()
				if lead>=0 and r.sky.pad_world-r.world_px-float(r.members[lead].x)<=(150.0 if choice=="sky" else 80.0):
					game.press_at(Vector2(920,330),161)
					pressed_at = r.elapsed
			if pressed_at>=0 and r.elapsed-pressed_at>=(.08 if choice=="sky" else 1.25): game.release_touch(161)
			if r.sewer.active and r.sewer.phase=="ride": r.sewer.next_encounter = 1e9
			r.advance(STEP,game.jump_held)
			game.update_camera(STEP)
			game.configure_layout()
			game.consume_run_events()
			game.update_run_visuals(STEP)
			game.ui_time += STEP
			game.toast_left = maxf(0,game.toast_left-STEP)
			game.perfect_left = maxf(0,game.perfect_left-STEP)
		game.queue_redraw()
		game.world_canvas.queue_redraw()
		game.foreground_canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_jpg(folder+"/frame-%04d.jpg"%frame,.91)==OK)
		assert(not (r.sky.active and r.sewer.active) and not r.dead and r.active_count()==6)
		if frame%30==0:
			trace.append({"frame":frame,"phase":r.sewer.phase,"route":r.sewer.encounter.route,"sky":r.sky.active,"camera_drop":r.sewer.entry_drop(),"members":r.active_count()})
			print("V161_PREVIEW ",choice," ",frame,"/",frames)
	var report = {"choice":choice,"frames":frames,"fps":30,"real_touch_input":true,"route":r.sewer.encounter.route,"members":r.active_count(),"losses":r.losses,"trace":trace,"physical_device_tested":false}
	var file = FileAccess.open(folder+"/preview.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	game.set_process(false)
	game.queue_free()
	for i in range(8): await process_frame
	print("V161_PREVIEW_OK ",choice)
	quit()

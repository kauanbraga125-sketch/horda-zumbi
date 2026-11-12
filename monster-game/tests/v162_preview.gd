extends SceneTree

const STEP = 1.0/60.0
const TOUCH = 162
var game

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	assert(not folder.is_empty())
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
	r.start_developer("gap",6,0,16210)
	r.developer_kind = ""
	r.entities.clear();r.rebuild_surfaces()
	r.next_pattern_world = 1e9
	r.bonus_director.next_window = 1e9
	game.lab_active = false
	assert(r.sewer.encounter.offer(r,true,"both"))
	game.camera_zoom = game.CAMERA_BASE_ZOOM
	game.camera_ground_shift = 0.0
	game.camera_sewer_pan = 0.0
	game.configure_layout()
	var pilot = preload("res://tests/sky_preview_pilot.gd").new()
	pilot.tolerance = 95.0
	pilot.plan_support = false
	var pressed_at = -1.0
	var launched = false
	var landed_at = -1.0
	var trace: Array = []
	var touches: Array = []
	var counts: Dictionary = {}
	var frames = 0
	for frame in range(30*100):
		for substep in range(2):
			if pressed_at<0 and r.sky.pad_world-r.world_px-r.ANCHOR<=150.0:
				game.press_at(Vector2(920,330),TOUCH)
				pressed_at = r.elapsed
				touches.append({"time":r.elapsed,"action":"trampoline_jump"})
			if pressed_at>=0 and r.elapsed-pressed_at>=.08 and game.jump_held:
				game.release_touch(TOUCH)
			if r.sky.active and pilot.wants_tap(r):
				game.press_at(Vector2(920,330),TOUCH)
				game.release_touch(TOUCH)
				touches.append({"time":r.elapsed,"action":"sky_tap","altitude":r.sky.altitude})
			r.advance(STEP,game.jump_held)
			pilot.observe(r.events,r.sky.age)
			for event in r.events:
				if str(event.type).begins_with("sky_"):
					counts[event.type] = int(counts.get(event.type,0))+1
			game.update_camera(STEP)
			game.configure_layout()
			game.consume_run_events()
			game.update_run_visuals(STEP)
			game.ui_time += STEP
			game.toast_left = maxf(0,game.toast_left-STEP)
			game.perfect_left = maxf(0,game.perfect_left-STEP)
			game.shake = maxf(0,game.shake-STEP*20)
			game.flash = maxf(0,game.flash-STEP*1.7)
			if r.sky.active: launched = true
			elif launched and landed_at<0: landed_at = r.elapsed
		game.queue_redraw()
		game.world_canvas.queue_redraw()
		game.foreground_canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_jpg(folder+"/frame-%05d.jpg"%frame,.90)==OK)
		assert(not (r.sky.active and r.sewer.active) and not r.dead)
		frames = frame+1
		if frame%30==0:
			trace.append({"frame":frame,"sky":r.sky.active,"height":r.sky.altitude,"peak":r.sky.peak,"members":r.active_count(),"charges":r.sky.charges,"hole_visible":r.sewer.encounter.cutout_pending()})
			print("V162_PREVIEW ",frame," height=",snappedf(r.sky.altitude/30.0,.1),"m members=",r.active_count())
		if landed_at>=0 and r.elapsed-landed_at>=2.5: break
	assert(launched and landed_at>=0 and not r.sky.active)
	var report = {"version":"0.10.62","seed":16210,"frames":frames,"fps":30,"duration_seconds":frames/30.0,"real_touch_input":true,"physics":"unchanged; normal boosts, captures and hazards","peak_world":r.sky.peak,"peak_meters":r.sky.peak/30.0,"returned_to_street":true,"members":r.active_count(),"souls":r.souls,"events":counts,"touches":touches,"trace":trace,"physical_device_tested":false}
	var file = FileAccess.open(folder+"/preview.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	game.set_process(false)
	game.queue_free()
	for i in range(8): await process_frame
	print("V162_PREVIEW_OK ",frames," frames; peak ",r.sky.peak/30.0,"m")
	quit()

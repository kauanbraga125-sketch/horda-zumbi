extends "res://tests/v134_visual.gd"
## Native, frozen-camera comparisons catch phase-triggered background replacements.
var checks = 0
var failures: Array[String] = []
var comparisons: Array = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)
func picture() -> Image:
	game.configure_layout();game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func compare(a: Image,b: Image,label: String) -> void:
	var sum = 0.0;var peak = 0.0;var pixels = 0;var changed = 0
	for y in range(145,a.get_height()-8,5):
		for x in range(8,a.get_width()-8,5):
			var ca = a.get_pixel(x,y);var cb = b.get_pixel(x,y)
			var delta = (absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b))/3.0
			sum += delta;peak = maxf(peak,delta);pixels += 1
			if delta>.03: changed += 1
	var mean = sum/maxi(1,pixels)
	comparisons.append({"label":label,"mean_rgb_change":mean,"peak":peak,"changed_fraction":float(changed)/maxi(1,pixels),"pixels":pixels})
	check(mean<.005 and float(changed)/maxi(1,pixels)<.02,label+": no panel replacement")
	a.save_png(folder+"/"+label+"-before.png");b.save_png(folder+"/"+label+"-after.png")
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false);game.data = MonsterCatalog.defaults()
	for fixture in [[Vector2i(1280,720),6],[Vector2i(1800,810),12],[Vector2i(960,720),12]]:
		root.size = fixture[0];await process_frame
		game.lab_count = fixture[1];game.start_lab("sewer");game.lab_active = false
		var r = game.runner;var s = r.sewer
		s.encounter.pending = true;s.encounter.dock_world = r.world_px+s.LEAD
		game.self_modulate.a = 0;game.foreground_canvas.visible = false
		var label = "%dx%d-%d" % [root.size.x,root.size.y,fixture[1]]
		var approach = await picture()
		check(s.begin(r,true),label+": physical entry starts")
		var entry = await picture()
		compare(approach,entry,label+"-approach-entry")
		s.phase_age = 1.2;s.descent_camera = 450.0
		var early = await picture()
		s.phase_age = 2.8
		var late = await picture()
		compare(early,late,label+"-depth-not-clock")
		# Complete the actual world travel: the opening must have passed the camera.
		s.phase_age = 0;s.descent_camera = 0
		step(s.ENTRY_SECONDS+.02)
		s.life.people.clear();s.life.next_scene = 1e6
		check(s.entry_edge_world-r.world_px<game.scenery.view_left-100,label+": road edge passed before handoff")
		s.phase = "entry";s.phase_age = s.ENTRY_SECONDS;s.descent_camera = s.SHAFT_DEPTH
		var end_entry = await picture()
		s.phase = "ride";s.phase_age = 0;s.life.people.clear()
		var ride = await picture()
		compare(end_entry,ride,label+"-entry-ride")
		var geometry = s.visual.shaft.geometry(game,s)
		check(absf(geometry.gallery_top-(s.WATER-621.0))<.001,label+": gallery anchor is physical water minus a fixed height")
		s.phase = "exit";s.phase_age = 0
		var exit_start = await picture()
		compare(ride,exit_start,label+"-ride-exit")
		game.foreground_canvas.visible = true;game.self_modulate.a = 1
	var report = {"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"comparisons":comparisons,"physical_device_tested":false}
	var out = FileAccess.open(folder+"/surface.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
	game.queue_free();game = null
	for i in range(8): await process_frame
	print("V145_SURFACE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

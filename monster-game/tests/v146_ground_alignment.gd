extends "res://tests/v134_visual.gd"
## Render the actual underground layer both enabled and disabled. No pixel of
## that layer may obscure the bridge/cemetery above the physical road surface.
var checks = 0
var failures: Array[String] = []
var measurements: Array = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)
func picture() -> Image:
	game.configure_layout();game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func alignment(label: String) -> void:
	var r = game.runner;var s = r.sewer
	game.self_modulate.a = 0;game.foreground_canvas.self_modulate.a = 0
	game.sewer_background_canvas.self_modulate.a = 1
	var normal = await picture()
	game.sewer_background_canvas.self_modulate.a = 0
	var reference = await picture()
	var image_scale = Vector2(normal.get_size())/game.get_viewport_rect().size
	var drop = s.entry_drop() if s.active else 0.0
	var surface = ((game.world_to_ui(Vector2(0,r.FLOOR-drop))+game.layout_origin)*image_scale).y
	var edge = s.shore_edge() if s.active else s.encounter.dock_world-r.world_px-s.DOCK_TO_EDGE
	var first_x = maxi(8,ceili(((game.world_to_ui(Vector2(edge+24,0))+game.layout_origin)*image_scale).x))
	var last_y = mini(normal.get_height()-8,floori(surface-3))
	var sampled = 0;var covered = 0;var peak = 0.0
	for y in range(145,last_y,4):
		for x in range(first_x,normal.get_width()-8,5):
			var a = normal.get_pixel(x,y);var b = reference.get_pixel(x,y)
			var change = maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
			peak = maxf(peak,change);sampled += 1
			if change>.005: covered += 1
	check(sampled>100,label+": meaningful area above the opening is sampled")
	check(covered==0,label+": underground never covers the distant scene above the road")
	normal.save_png(folder+"/"+label+"-background.png")
	reference.save_png(folder+"/"+label+"-without-underground.png")
	# Isolate the shader against magenta and inspect the space immediately below
	# the lip, catching a gap introduced by moving the wall down.
	var clear = RenderingServer.get_default_clear_color()
	RenderingServer.set_default_clear_color(Color.MAGENTA)
	game.world_canvas.self_modulate.a = 0;game.sewer_street_canvas.self_modulate.a = 0
	game.sewer_background_canvas.self_modulate.a = 1
	var isolated = await picture()
	var visible_pixels = 0;var missing = 0
	for depth in [8.0,18.0,34.0]:
		for world_x in range(ceili(maxf(edge+40,game.scenery.view_left+8)),floori(game.scenery.view_right-8),33):
			var point = Vector2i((game.world_to_ui(Vector2(world_x,r.FLOOR-drop+depth))+game.layout_origin)*image_scale)
			if point.x<0 or point.y<145 or point.x>=isolated.get_width() or point.y>=isolated.get_height(): continue
			var color = isolated.get_pixelv(point);visible_pixels += 1
			if color.r>.98 and color.g<.02 and color.b>.98: missing += 1
	check(visible_pixels>10 and missing==0,label+": the wall fills the space immediately below the physical lip")
	measurements.append({"fixture":label,"surface_y_pixels":surface,"samples_above_surface":sampled,"covered_pixels":covered,"peak_rgb_change":peak,"samples_below_surface":visible_pixels,"missing_pixels_below":missing,"phase":s.phase,"phase_age":s.phase_age})
	RenderingServer.set_default_clear_color(clear)
	game.world_canvas.self_modulate.a = 1;game.sewer_street_canvas.self_modulate.a = 1
	game.self_modulate.a = 1;game.foreground_canvas.self_modulate.a = 1
	await picture()
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false);game.data = MonsterCatalog.defaults()
	for fixture in [[Vector2i(1280,720),6],[Vector2i(1800,810),12],[Vector2i(960,720),12]]:
		root.size = fixture[0];await process_frame
		game.lab_count = fixture[1];game.start_lab("sewer");game.lab_active = false
		var r = game.runner;var s = r.sewer
		# Place the approach in view without altering the ordinary far background.
		s.encounter.pending = true;s.encounter.dock_world = r.world_px+s.LEAD
		var name = "%dx%d-%d" % [root.size.x,root.size.y,fixture[1]]
		await alignment(name+"-approach")
		check(s.begin(r,true),name+": physical fall starts")
		for at in [.5,1.25,1.75]:
			step(at-s.phase_age)
			await alignment(name+"-entry-%.2f" % at)
	var report = {"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"measurements":measurements,"physical_device_tested":false}
	var out = FileAccess.open(folder+"/alignment.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
	game.queue_free();game = null
	for i in range(8): await process_frame
	print("V146_ALIGNMENT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

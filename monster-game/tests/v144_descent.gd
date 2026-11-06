extends "res://tests/v134_visual.gd"
## Actual terrain ends at the ledge; the distant background can continue below
## the walking plane until the deeper wall covers it without a visible cut.
var checks = 0
var failures: Array[String] = []
var handoffs: Array = []

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)

func picture() -> Image:
	game.configure_layout();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw();game.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func street_mask(label: String) -> void:
	var img = await preload("res://tests/sewer_render_probe.gd").terrain_image(game,self)
	var scale = Vector2(img.get_size())/game.get_viewport_rect().size
	var surface = ((game.world_to_ui(Vector2(0,game.runner.FLOOR-game.runner.sewer.entry_drop()))+game.layout_origin)*scale).y
	var first_x = maxi(15,ceili(((game.world_to_ui(Vector2(game.runner.sewer.shore_edge()+24,0))+game.layout_origin)*scale).x))
	var pixels = 0;var leaked = 0
	for y in range(maxi(150,ceili(surface+5)),img.get_height()-5,13):
		for x in range(first_x,img.get_width()-15,37):
			var color = img.get_pixel(x,y);pixels += 1
			if color.r<.98 or color.g>.02 or color.b<.98: leaked += 1
	check(pixels>10 and leaked==0,label+": actual terrain is absent inside the opening")
	img.save_png(folder+"/"+label+"-terrain-mask.png")
	await picture()

func handoff(label: String) -> void:
	var s = game.runner.sewer
	s.phase = "entry";s.phase_age = s.ENTRY_SECONDS
	s.life.people.clear();s.life.next_scene = 1e6
	game.foreground_canvas.visible = false;game.self_modulate.a = 0
	var before = await picture()
	s.phase = "ride";s.phase_age = 0
	var after = await picture()
	var difference = 0.0;var pixels = 0
	for y in range(145,before.get_height()-8,7):
		for x in range(8,before.get_width()-8,7):
			var a = before.get_pixel(x,y);var b = after.get_pixel(x,y)
			difference += (absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0;pixels += 1
	difference /= maxf(1,pixels)
	check(difference<.005,label+": entry and ride share the same rendered gallery")
	handoffs.append({"fixture":label,"mean_rgb_change":difference,"pixels":pixels})
	before.save_png(folder+"/"+label+"-before.png");after.save_png(folder+"/"+label+"-after.png")
	game.foreground_canvas.visible = true;game.self_modulate.a = 1
	await picture()

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults()
	for fixture in [[Vector2i(1280,720),6],[Vector2i(1800,810),12],[Vector2i(960,720),12]]:
		root.size = fixture[0];await process_frame
		game.lab_count = fixture[1];game.start_lab("sewer");game.lab_active = false
		var s = game.runner.sewer
		# Reach the ledge through the real approach. Forcing entry immediately
		# after offer() places the opening offscreen and samples no pit pixels.
		for i in range(600):
			step(STEP)
			if s.active: break
		check(s.active and s.phase=="entry","the actual approach starts the covered drop")
		check(s.boats.all(func(b):return absf(b.y-(s.WATER-24+s.entry_depth()))<.001),"entry boats start below the street before the first physics update")
		s.next_encounter = 1e6;s.life.next_scene = 1e6
		var label = "%dx%d-%d" % [root.size.x,root.size.y,fixture[1]]
		for age in [.15,.75,1.5,2.5,3.5,4.5]:
			step(age-s.phase_age)
			check(game.sewer_street_canvas.modulate.a==1.0,"street stays opaque during descent")
			await snap(label+"-%.2f" % age)
			await street_mask(label+"-%.2f" % age)
		step(s.ENTRY_SECONDS-s.phase_age+.02)
		check(game.runner.members.all(func(m):return m.sewer_pose=="ride"),"the real members reach their seats")
		await handoff(label)
	var report = {"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"handoffs":handoffs,"physical_device_tested":false}
	var out = FileAccess.open(folder+"/descent.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
	game.queue_free();game = null
	for i in range(8): await process_frame
	print("V144_DESCENT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

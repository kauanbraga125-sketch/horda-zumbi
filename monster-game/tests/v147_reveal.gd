extends "res://tests/v134_visual.gd"
## Rendering contracts for a deeper wall revealed by actual falling motion.
var checks = 0
var failures: Array[String] = []
var measurements: Array = []
var marker: Texture2D
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)
func picture(layout: bool = true) -> Image:
	if layout: game.configure_layout()
	game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw();game.sewer_background_canvas.queue_redraw();game.sewer_street_canvas.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func difference(a: Image,b: Image,left: int = 8,top: int = 145,bottom: int = -1) -> Dictionary:
	var pixels = 0;var changed = 0;var total = 0.0;var peak = 0.0
	if bottom<0: bottom = a.get_height()-8
	for y in range(maxi(0,top),mini(bottom,a.get_height()-8),4):
		for x in range(maxi(8,left),a.get_width()-8,5):
			var ca = a.get_pixel(x,y);var cb = b.get_pixel(x,y)
			var delta = (absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b))/3.0
			total += delta;peak = maxf(peak,delta);pixels += 1
			if delta>.005: changed += 1
	return {"pixels":pixels,"changed":changed,"mean":total/maxi(1,pixels),"peak":peak}
func texture_probe(label: String,empty: bool) -> void:
	game.self_modulate.a = 0;game.foreground_canvas.self_modulate.a = 0
	var normal = await picture()
	var mat: ShaderMaterial = game.sewer_background_canvas.material
	var soil = mat.get_shader_parameter("soil_texture");var sewer = mat.get_shader_parameter("sewer_texture")
	mat.set_shader_parameter("soil_texture",marker);mat.set_shader_parameter("sewer_texture",marker)
	var replaced = await picture(false)
	var change = difference(normal,replaced)
	check(change.pixels>1000,label+": textured-wall probe covers the scene")
	check(change.changed==0 if empty else change.changed>500,label+": no underground texture before falling" if empty else label+": descent physically reveals the underground texture")
	measurements.append({"fixture":label,"type":"texture_visibility","expect_empty":empty,"fall_age":game.runner.sewer.fall_age(game.runner),"drop":game.runner.sewer.entry_drop(),"throat_depth":game.runner.sewer.visual.shaft.throat_depth,"image_difference":change})
	mat.set_shader_parameter("soil_texture",soil);mat.set_shader_parameter("sewer_texture",sewer)
	normal.save_png(folder+"/"+label+".png")
	game.self_modulate.a = 1;game.foreground_canvas.self_modulate.a = 1
	await picture()
func upper_scene(label: String) -> void:
	game.self_modulate.a = 0;game.foreground_canvas.self_modulate.a = 0
	var normal = await picture()
	game.sewer_background_canvas.self_modulate.a = 0
	var without = await picture()
	var scale = Vector2(normal.get_size())/game.get_viewport_rect().size
	var surface = ((game.world_to_ui(Vector2(0,game.runner.FLOOR-game.runner.sewer.entry_drop()))+game.layout_origin)*scale).y
	var change = difference(normal,without,8,145,floori(surface-3))
	check(change.pixels>100 and change.changed==0,label+": the distant scene above the walking plane stays unobscured")
	measurements.append({"fixture":label,"type":"above_surface","surface_y_pixels":surface,"image_difference":change})
	game.sewer_background_canvas.self_modulate.a = 1;game.self_modulate.a = 1;game.foreground_canvas.self_modulate.a = 1
	await picture()
func hidden_clip(label: String) -> void:
	game.self_modulate.a = 0;game.foreground_canvas.self_modulate.a = 0
	var normal = await picture()
	game.sewer_street_clip.size.y += 1400
	var extended = await picture(false)
	var scale = Vector2(normal.get_size())/game.get_viewport_rect().size
	var x = ceili(((game.world_to_ui(Vector2(game.runner.sewer.shore_edge()+32,0))+game.layout_origin)*scale).x)
	var change = difference(normal,extended,x)
	check(change.pixels>1000 and change.mean<.00001,label+": changing the far-background clipping rectangle exposes no seam")
	measurements.append({"fixture":label,"type":"hidden_clip_boundary","image_difference":change})
	normal.save_png(folder+"/"+label+".png")
	game.self_modulate.a = 1;game.foreground_canvas.self_modulate.a = 1
	await picture()
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	var solid = Image.create(2,2,false,Image.FORMAT_RGBA8);solid.fill(Color.MAGENTA);marker = ImageTexture.create_from_image(solid)
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	# This probe deliberately replaces material uniforms between draws. Freeze
	# automatic layout too, otherwise _process silently restores the real textures.
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.set_process(false);game.sound.set_enabled(false);game.data = MonsterCatalog.defaults()
	for fixture in [[Vector2i(1280,720),6,false],[Vector2i(1800,810),12,false],[Vector2i(960,720),12,false],[Vector2i(960,720),12,true]]:
		root.size = fixture[0];await process_frame
		game.lab_count = fixture[1];game.start_lab("sewer");game.lab_active = false
		game.runner.start_developer("sewer",fixture[1],0,14142);game.runner.developer_kind = "";game.runner.entities.clear();game.runner.events.clear()
		game.runner.sewer.encounter.offer(game.runner,true)
		if fixture[2]: game.camera_zoom = game.CAMERA_MIN_ZOOM
		game.configure_layout()
		var label = "%dx%d-%d%s" % [root.size.x,root.size.y,fixture[1],"-wide-view" if fixture[2] else ""]
		var s = game.runner.sewer
		await texture_probe(label+"-approach",true)
		for i in range(600):
			step(STEP)
			if s.active: break
		check(s.active and s.fall_age(game.runner)<0,label+": entry starts before the first foot falls")
		await texture_probe(label+"-before-fall",true)
		for i in range(180):
			step(STEP)
			if s.fall_age(game.runner)>=0: break
		check(s.fall_age(game.runner)>=0,label+": an actual member crosses the ledge")
		var locked = s.visual.shaft.throat_depth
		await texture_probe(label+"-first-foot",true)
		step(.45)
		check(s.visual.shaft.throat_depth==locked,label+": the unseen throat stays world-anchored after falling starts")
		await upper_scene(label+"-falling")
		step(2.6-s.phase_age)
		await texture_probe(label+"-deeper",false)
		await hidden_clip(label+"-deeper-clip")
	var report = {"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"measurements":measurements,"physical_device_tested":false}
	var out = FileAccess.open(folder+"/reveal.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
	game.queue_free();game = null
	for i in range(8): await process_frame
	print("V147_REVEAL ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

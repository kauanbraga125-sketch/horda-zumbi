extends "res://tests/v147_reveal.gd"
## Rendered occlusion, local cloud motion and pause contracts for the seam.
func band_difference(a: Image,b: Image,from_depth: float,to_depth: float,opening_only: bool = false) -> Dictionary:
	var s = game.runner.sewer
	var scale = Vector2(a.get_size())/game.get_viewport_rect().size
	var surface = game.runner.FLOOR-s.entry_drop()
	var y0 = ((game.world_to_ui(Vector2(0,surface+from_depth))+game.layout_origin)*scale).y
	var y1 = ((game.world_to_ui(Vector2(0,surface+to_depth))+game.layout_origin)*scale).y
	var left = 8
	if opening_only: left = maxi(left,ceili(((game.world_to_ui(Vector2(s.shore_edge()+24,0))+game.layout_origin)*scale).x))
	return difference(a,b,left,maxi(145,ceili(y0)),floori(y1))

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.set_process(false);game.sound.set_enabled(false);game.data = MonsterCatalog.defaults()
	for fixture in [[Vector2i(1280,720),6],[Vector2i(1800,810),12],[Vector2i(960,720),12]]:
		root.size = fixture[0];await process_frame
		game.lab_count = fixture[1];game.start_lab("sewer");game.lab_active = false
		game.runner.start_developer("sewer",fixture[1],0,14142);game.runner.developer_kind = "";game.runner.entities.clear();game.runner.events.clear()
		game.runner.sewer.encounter.offer(game.runner,true)
		var s = game.runner.sewer
		for i in range(600):
			step(STEP)
			if s.active and s.fall_age(game.runner)>=1.35: break
		check(s.active and s.phase=="entry","the fixture reaches the actual falling seam")
		var label = "%dx%d-%d" % [root.size.x,root.size.y,fixture[1]]
		await snap(label+"-falling")
		game.self_modulate.a = 0;game.foreground_canvas.self_modulate.a = 0
		var normal = await picture()
		var mat: ShaderMaterial = game.sewer_background_canvas.material
		var clock = float(mat.get_shader_parameter("effect_time"))
		mat.set_shader_parameter("effect_time",clock+1.0)
		var later = await picture(false)
		var moving = band_difference(normal,later,35,s.visual.shaft.throat_depth+170)
		check(moving.pixels>1000 and moving.changed>500 and moving.mean>.001,label+": cloud banks move while the scene and camera stay fixed")
		measurements.append({"fixture":label,"cloud_motion":moving})
		mat.set_shader_parameter("effect_time",clock)
		var saved = game.sewer_street_canvas.modulate
		game.sewer_street_canvas.modulate = Color.BLACK
		var black = await picture(false)
		game.sewer_street_canvas.modulate = Color.MAGENTA
		var magenta = await picture(false)
		var opaque = band_difference(black,magenta,s.visual.shaft.throat_depth+98,1600,true)
		check(opaque.pixels>100 and opaque.changed==0,label+": the solid wall cannot show a contrasting distant scene through it")
		var air = band_difference(black,magenta,25,s.visual.shaft.throat_depth-15,true)
		check(air.pixels>500 and air.changed>100,label+": the contrasting-background probe detects open air above the wall")
		measurements.append({"fixture":label,"opaque_wall":opaque,"open_air_positive_control":air})
		game.sewer_street_canvas.modulate = saved
		game.frozen_world_time = game.ui_time;game.screen = "pause"
		var paused = await picture()
		var paused_clock = float(mat.get_shader_parameter("effect_time"))
		game.ui_time += 8.0
		var still = await picture()
		check(float(mat.get_shader_parameter("effect_time"))==paused_clock,label+": pausing freezes the cloud clock")
		var freeze = band_difference(paused,still,20,s.visual.shaft.throat_depth+235)
		check(freeze.pixels>1000 and freeze.changed==0,label+": paused fog stays visually still")
		game.screen = "run";game.ui_time = game.frozen_world_time
		# In 4:3 the lower gallery is still outside the first fog framing.
		# Reach it physically before requiring a nonempty deep-scene sample.
		step(2.7-s.phase_age)
		var deep_before = await picture()
		clock = float(mat.get_shader_parameter("effect_time"))
		mat.set_shader_parameter("effect_time",clock+1.0)
		var deep_after = await picture(false)
		var deep = band_difference(deep_before,deep_after,float(s.visual.shaft.geometry(game,s).gallery_offset)+120.0,1800,true)
		check(deep.pixels>100 and deep.changed==0,label+": cloud animation does not make the lower gallery flicker")
		measurements.append({"fixture":label,"deep_gallery_motion":deep})
		mat.set_shader_parameter("effect_time",clock)
		game.self_modulate.a = 1;game.foreground_canvas.self_modulate.a = 1
		await picture()
		step(3.0-s.phase_age);await snap(label+"-boarding")
	var report = {"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"measurements":measurements,"physical_device_tested":false}
	var out = FileAccess.open(folder+"/fog.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
	game.queue_free();game = null
	for i in range(8): await process_frame
	print("V148_FOG ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

extends "res://tests/v147_reveal.gd"

func image_point(point: Vector2, scale: Vector2) -> Vector2i:
	return Vector2i((game.world_to_ui(point) + game.layout_origin) * scale)

func opaque_hull(before: Image, after: Image, hull: Image, boat: Dictionary, height: float) -> Dictionary:
	var scale = Vector2(before.get_size()) / game.get_viewport_rect().size
	var size = Vector2(hull.get_size()) * height / hull.get_height()
	var result = {"pixels": 0, "changed": 0}
	for y in range(48, 84, 2):
		for x in range(20, 80, 2):
			var uv = Vector2(x, y) / 100.0
			# The painted interior is mostly alpha 252–253, with feathered edges.
			if hull.get_pixelv(Vector2i(uv * Vector2(hull.get_size()))).a < 0.987: continue
			var local = (uv - Vector2(0.5, 0.5)) * size
			var point = image_point(Vector2(boat.x, boat.y) + local.rotated(boat.angle), scale)
			if not Rect2i(Vector2i.ZERO, before.get_size()).has_point(point): continue
			result.pixels += 1
			var a = before.get_pixelv(point)
			var b = after.get_pixelv(point)
			if absf(a.r-b.r) + absf(a.g-b.g) + absf(a.b-b.b) > 0.06:
				result.changed += 1
	return result

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	assert(not folder.is_empty())
	DirAccess.make_dir_recursive_absolute(folder)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.capture_freeze = true
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults()

	var hull = Image.new()
	assert(hull.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/v149/jetski_solo.webp")) == OK)
	for fixture in [[Vector2i(1280, 720), 6], [Vector2i(1800, 810), 12], [Vector2i(960, 720), 12]]:
		root.size = fixture[0]
		await process_frame
		game.lab_count = fixture[1]
		game.start_lab("sewer")
		game.lab_active = false
		var r = game.runner
		r.start_developer("sewer", fixture[1], 0, 14142)
		r.developer_kind = ""
		r.entities.clear()
		r.events.clear()
		var s = r.sewer
		s.encounter.offer(r, true)
		for i in range(600):
			step(STEP)
			if s.phase == "ride": break
		var label = "%dx%d-%d" % [root.size.x, root.size.y, fixture[1]]
		check(s.phase == "ride", label + ": reaches the actual water ride")
		s.objects.clear()
		s.next_encounter = 1e6
		s.life.people.clear()
		s.life.next_scene = 1e6
		step(0.6)

		var normal = await picture()
		var scale = Vector2(normal.get_size()) / game.get_viewport_rect().size
		var far_bank = float(s.visual.shaft.geometry(game, s).gallery_top) + s.visual.shaft.GALLERY_HEIGHT * 0.708
		var water_top = image_point(Vector2(0, far_bank), scale).y
		var material: ShaderMaterial = game.sewer_background_canvas.material
		var clock = float(material.get_shader_parameter("water_clock"))
		material.set_shader_parameter("water_clock", clock + 0.63)
		var later = await picture(false)
		var moving = difference(normal, later, 8, water_top + 5)
		var above = difference(normal, later, 8, 145, water_top - 4)
		check(moving.pixels > 1000 and moving.changed > 500, label + ": reflections move at fixed camera and fleet positions")
		check(above.pixels > 1000 and above.changed == 0, label + ": the water animation leaves the wall and pilots above the bank untouched")
		material.set_shader_parameter("water_clock", clock)

		var boat: Dictionary = s.boats.reduce(func(nearest, next): return next if next.y > nearest.y else nearest)
		var water_fx = s.visual.water_fx
		var atlas: Texture2D = water_fx.atlas
		var solid = Image.create(atlas.get_width(), atlas.get_height(), false, Image.FORMAT_RGBA8)
		solid.fill(Color.MAGENTA)
		water_fx.atlas = ImageTexture.create_from_image(solid)
		s.splash(Vector2(boat.x, s.boat_waterline(boat)), false, "landing")
		s.splashes.back().age = 0.19
		var marked = await picture(false)
		var effect = difference(normal, marked, 8, water_top)
		var hull_probe = opaque_hull(normal, marked, hull, boat, s.HULL_HEIGHT)
		check(effect.changed > 100, label + ": the high contrast effect is visible around the craft")
		check(hull_probe.pixels > 100 and hull_probe.changed == 0, label + ": the opaque hull covers foam and splashes")
		measurements.append({"fixture":label,"moving_water":moving,"above_water":above,"visible_effect":effect,"opaque_hull":hull_probe})
		water_fx.atlas = atlas
		assert(normal.save_png(folder + "/" + label + ".png") == OK)

	var report = {"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"measurements":measurements}
	var out = FileAccess.open(folder + "/water.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "  "))
	out.close()
	game.queue_free()
	game = null
	for i in range(8): await process_frame
	print("V151_WATER ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

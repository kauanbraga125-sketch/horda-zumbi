extends SceneTree

var fitting: HordeCosmetics
var baseline
var lab
var canvas: Node2D
var viewport: SubViewport
var output = ""
var jobs: Array = []
var page: Array = []
var use_baseline = false
var failures: Array[String] = []
var checks = 0
var protected_renders = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("V117_STRAW_FAIL: " + message)

func paint_board() -> void:
	canvas.draw_rect(Rect2(0, 0, 1920, 1440), Color("2b2237"))
	for i in range(page.size()):
		var job: Dictionary = page[i]
		var pose: Dictionary = lab.sample(0, job.state, job.index)
		var foot = Vector2(i % 8 * 240 + 112, int(i / 8) * 240 + 224)
		var renderer = baseline if use_baseline else fitting
		renderer.paint(canvas, 0, foot, 154, pose.phase, pose.state, pose.time, pose.landing, Color.WHITE, job.reverse, pose.air_age, pose.vertical_speed, [job.id])

func render_image() -> Image:
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	fitting = HordeCosmetics.new();fitting.ensure_data()
	baseline = load("res://tests/v117_original_cosmetics.gd").new();baseline.ensure_data()
	baseline.graphics = JSON.parse_string(FileAccess.get_file_as_string("res://tests/v117_before_graphics.json"))
	lab = load("res://scripts/item_lab.gd").new();lab.selected = 4
	check(str(ProjectSettings.get_setting("application/config/version")) == "0.10.17", "Compiled version is 0.10.17")
	var unchanged = 0
	for id in fitting.graphics:
		if id == "z_straw": continue
		check(fitting.graphics[id] == baseline.graphics[id], "Graphic unchanged: " + id)
		unchanged += 1
	check(unchanged == 34, "All other 34 graphics preserved")
	var new_image: Image = fitting.texture(fitting.graphics.z_straw.file).get_image()
	var key_count = 0
	for key in fitting.frames:
		var f: Dictionary = fitting.frames[key]
		if int(f.kind) != 0: continue
		key_count += 1
		var transform = fitting.fit_transform("z_straw", f)
		check(transform.is_finite() and transform.determinant() > .000001, "Valid fit: " + key)
		check(absf(transform.x.length() - transform.y.length()) < .00001 and absf(transform.x.dot(transform.y)) < .00001, "No shear or stretched cloth: " + key)
		for eye in ["near", "far"]:
			var point = transform.affine_inverse() * HordeCosmetics.vector(f.landmarks[eye])
			var pixel = Vector2i(roundi(point.x), roundi(point.y))
			var hidden = false
			if Rect2i(Vector2i.ZERO, new_image.get_size()).has_point(pixel): hidden = new_image.get_pixelv(pixel).a > 8.0 / 255.0
			check(not hidden, "Eye center stays visible: " + key + ":" + eye)
	check(key_count == 96, "All 96 zombie frames measured")
	viewport = SubViewport.new();viewport.size = Vector2i(1920, 1440)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	canvas = Node2D.new();viewport.add_child(canvas);canvas.draw.connect(paint_board)
	for id in ["coveiro", "bruxa", "sobrevivente", "z_plumber"]:
		for state in range(lab.STATES.size()):
			for index in range(int(lab.spec(0, state).x)):
				for reverse in [false, true]: jobs.append({"id": id, "state": state, "index": index, "reverse": reverse})
	for offset in range(0, jobs.size(), 48):
		page = jobs.slice(offset, mini(offset + 48, jobs.size()))
		use_baseline = true
		var before: Image = await render_image()
		use_baseline = false
		var after: Image = await render_image()
		check(before.get_data() == after.get_data(), "Approved items pixel-identical: batch " + str(offset))
		protected_renders += page.size()
		if offset == 0: after.save_png(output.path_join("approved_items_preserved.png"))
	jobs.clear()
	for state in range(lab.STATES.size()):
		for index in range(int(lab.spec(0, state).x)):
			for reverse in [false, true]: jobs.append({"id": "z_straw", "state": state, "index": index, "reverse": reverse})
	for offset in range(0, jobs.size(), 48):
		page = jobs.slice(offset, mini(offset + 48, jobs.size()))
		var after: Image = await render_image()
		after.save_png(output.path_join("straw_all_frames_%03d.png" % offset))
	var result = {"version": "0.10.17", "checks": checks, "failures": failures, "unchanged_graphics": unchanged, "zombie_frames": key_count, "retained_item_renders_pixel_identical": protected_renders, "new_straw_renders": jobs.size(), "eye_centers_covered": 0 if failures.is_empty() else -1}
	var file = FileAccess.open(output.path_join("straw_validation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "));file.close()
	print("V117_STRAW_", "OK" if failures.is_empty() else "FAILED", " ", JSON.stringify(result))
	viewport.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)

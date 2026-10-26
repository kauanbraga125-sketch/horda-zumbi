extends SceneTree

const CHANGED = ["z_nightmare", "z_sorcerer", "z_electric"]
var fitting
var baseline
var untouched
var lab
var viewport: SubViewport
var canvas: Node2D
var output = ""
var failures: Array[String] = []
var checks = 0
var jobs: Array = []
var page: Array = []
var renderer_index = 0
var face_mode = false
var face_pose: Dictionary
var face_samples = 0
var body_samples = 0
var repaired_face_samples = 0
var new_face_mismatches = 0
var new_body_mismatches = 0
var mismatch_examples: Array = []
var max_face_channel_difference = 0.0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message);push_error("V120_ITEMS_FAIL: " + message)

func draw_board() -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(viewport.size)), Color("2b2237"))
	var actor = fitting if renderer_index == 0 else baseline if renderer_index == 1 else untouched
	if face_mode:
		for reverse in [false, true]:
			actor.paint(canvas, 0, Vector2(256 + 512 * int(reverse), 565), 350, face_pose.phase, face_pose.state, face_pose.time, face_pose.landing, Color.WHITE, reverse, face_pose.air_age, face_pose.vertical_speed, ["z_electric"])
		return
	for i in range(page.size()):
		var job: Dictionary = page[i]
		var pose: Dictionary = lab.sample(job.kind, job.state, job.index)
		var foot = Vector2(i % 8 * 240 + 112, int(i / 8) * 240 + 224)
		actor.paint(canvas, job.kind, foot, 154, pose.phase, pose.state, pose.time, pose.landing, Color.WHITE, job.reverse, pose.air_age, pose.vertical_speed, job.wear)

func render_image() -> Image:
	canvas.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func face_transform(f: Dictionary, reverse: bool) -> Transform2D:
	var origin = Vector2(256 + 512 * int(reverse), 565)
	var stretch = Vector2.ONE;var angle = 0.0
	if face_pose.state == "run" and face_pose.landing <= 0:
		var step = fposmod(face_pose.phase * 2.0, 1.0)
		if step > .76: origin.y -= 2.6 * pow(sin((step - .76) / .24 * PI), 2) * 350.0 / 112.0
		angle = .006 * sin((face_pose.phase * 2.0 - .1) * TAU)
	elif face_pose.state in ["idle", "aim"]:
		var breath = sin(face_pose.time * TAU / 2.4)
		stretch = Vector2(1.0 - breath * .004, 1.0 + breath * .009)
		angle = sin(face_pose.time * TAU / 4.8) * .004
	var result = Transform2D(angle * (-1 if reverse else 1), origin)
	result.x *= (-1 if reverse else 1) * stretch.x * 350.0 / float(f.height)
	result.y *= stretch.y * 350.0 / float(f.height)
	result.origin -= result.basis_xform(HordeCosmetics.vector(f.anchor))
	return result

func difference(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r-b.r), absf(a.g-b.g)), maxf(absf(a.b-b.b), absf(a.a-b.a)))

func different(a: Color, b: Color, tolerance: float = 2.1/255.0) -> bool:
	return difference(a,b) > tolerance

func compare_original_pixels(original: Image, actual: Image, old: Image) -> void:
	var f: Dictionary = fitting.frames[face_pose.key]
	var source: Image = fitting.texture(f.file).get_image()
	var w = float(f.head_width);var box: Array = f.box
	for reverse in [false, true]:
		var transform = face_transform(f, reverse)
		for y in range(0, int(f.rect[3]), 2):
			for x in range(0, int(f.rect[2]), 2):
				var face = x >= box[0]+.25*w and x <= box[2]+.04*w and y >= box[1]+.30*w and y <= box[3]+.035*w
				var body = y >= f.landmarks.neck[1]+.12*w
				if not face and not body: continue
				if x < 1 or y < 1 or x >= int(f.rect[2])-1 or y >= int(f.rect[3])-1: continue
				# Compare opaque interior pixels. A translucent outline naturally
				# blends with yellow cloth rather than the empty reference backdrop.
				var opaque = true
				for dy in [-1,0,1]:
					for dx in [-1,0,1]:
						if source.get_pixel(int(f.rect[0])+x+dx, int(f.rect[1])+y+dy).a < .99: opaque = false
				if not opaque: continue
				var point = Vector2i((transform * Vector2(x+.5, y+.5)).floor())
				if not Rect2i(Vector2i.ZERO, original.get_size()).has_point(point): continue
				var expected = original.get_pixelv(point)
				if face:
					face_samples += 1
					max_face_channel_difference = maxf(max_face_channel_difference, difference(expected,actual.get_pixelv(point)))
					# A triangle mesh and the original quad can differ by a few
					# bilinear rounding levels. This detects holes or lost outlines
					# while allowing those small rasterization differences.
					if different(expected, actual.get_pixelv(point), 8.1/255.0):
						new_face_mismatches += 1
						if mismatch_examples.size() < 20:
							var value = actual.get_pixelv(point)
							mismatch_examples.append({"frame":face_pose.key,"reverse":reverse,"source":[x,y],"expected":[expected.r8,expected.g8,expected.b8,expected.a8],"actual":[value.r8,value.g8,value.b8,value.a8]})
					if different(expected, old.get_pixelv(point), 8.1/255.0): repaired_face_samples += 1
				if body:
					body_samples += 1
					if different(expected, actual.get_pixelv(point)): new_body_mismatches += 1

func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	fitting = HordeCosmetics.new();fitting.ensure_data()
	baseline = load("res://tests/v120_original_cosmetics.gd").new();baseline.ensure_data()
	baseline.graphics = JSON.parse_string(FileAccess.get_file_as_string("res://tests/v120_before_graphics.json"))
	untouched = load("res://tests/v120_untouched.gd").new();untouched.ensure_data()
	lab = load("res://scripts/item_lab.gd").new()
	check(str(ProjectSettings.get_setting("application/config/version")) == "0.10.20", "Compiled version 0.10.20")
	var unchanged = 0
	for id in fitting.graphics:
		if id in CHANGED: continue
		check(fitting.graphics[id] == baseline.graphics[id], "Graphic unchanged: " + id);unchanged += 1
	check(unchanged == 32, "Other 32 accessories unchanged")
	var packed = FileAccess.get_file_as_bytes("res://tests/v120_before_fitting.bin")
	var old_frames: Dictionary = JSON.parse_string(packed.slice(4).decompress(packed.decode_u32(0), FileAccess.COMPRESSION_ZSTD).get_string_from_utf8())
	for key in fitting.frames:
		var f: Dictionary = fitting.frames[key]
		var copy: Dictionary = f.duplicate(true);copy.erase("original_outline")
		copy.meshes.erase("hood_base");copy.meshes.erase("hood_base_cape")
		check(copy == old_frames[key], "Existing landmarks and masks unchanged: " + key)
		if int(f.kind) != 0: continue
		check(f.meshes.has("hood_base") and f.meshes.has("hood_base_cape"), "Complete hood body and cape layer: " + key)
		for id in ["z_nightmare", "z_sorcerer"]:
			var transform = fitting.fit_transform(id, f)
			check(transform.is_finite() and transform.determinant() > .000001, "Valid hat fit: " + key + id)
			check(absf(transform.x.length()-transform.y.length()) < .00001 and absf(transform.x.dot(transform.y)) < .00001, "Uniform scale without shearing: " + key + id)
			var image: Image = fitting.texture(fitting.graphics[id].file).get_image()
			for eye in ["near", "far"]:
				var point = Vector2i((transform.affine_inverse() * HordeCosmetics.vector(f.landmarks[eye])).round())
				check(not Rect2i(Vector2i.ZERO, image.get_size()).has_point(point) or image.get_pixelv(point).a < 8.0/255.0, "Eye center visible: " + key + id + eye)
	viewport = SubViewport.new();viewport.size = Vector2i(1920,1440);viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	canvas = Node2D.new();viewport.add_child(canvas);canvas.draw.connect(draw_board)
	for entry in HordeCosmeticCatalog.ITEMS:
		if entry.id in CHANGED: continue
		for state in range(lab.STATES.size()):
			for index in range(int(lab.spec(entry.kind,state).x)):
				for reverse in [false,true]: jobs.append({"kind":entry.kind,"state":state,"index":index,"reverse":reverse,"wear":[entry.id]})
	var protected_renders = jobs.size()
	for offset in range(0,jobs.size(),48):
		page = jobs.slice(offset,mini(offset+48,jobs.size()))
		renderer_index = 1;var before: Image = await render_image()
		renderer_index = 0;var after: Image = await render_image()
		check(before.get_data() == after.get_data(), "Other items pixel-identical: " + str(offset))
	jobs.clear()
	for id in CHANGED:
		for state in range(lab.STATES.size()):
			for index in range(int(lab.spec(0,state).x)):
				for reverse in [false,true]: jobs.append({"kind":0,"state":state,"index":index,"reverse":reverse,"wear":[id]})
	var new_renders = jobs.size()
	for offset in range(0,jobs.size(),48):
		page = jobs.slice(offset,mini(offset+48,jobs.size()));var image: Image = await render_image()
		image.save_png(output.path_join("new_items_%03d.png" % offset))
	jobs.clear()
	for entry in HordeCosmeticCatalog.ITEMS:
		if entry.kind != 0 or entry.slot == "head": continue
		for state in range(lab.STATES.size()):
			for reverse in [false,true]: jobs.append({"kind":0,"state":state,"index":0,"reverse":reverse,"wear":["z_electric",entry.id]})
	for offset in range(0,jobs.size(),48):
		page = jobs.slice(offset,mini(offset+48,jobs.size()));var image: Image = await render_image()
		image.save_png(output.path_join("hood_combinations_%03d.png" % offset))
	var combinations = jobs.size()
	face_mode = true;viewport.size = Vector2i(1024,600)
	for state in range(lab.STATES.size()):
		for index in range(int(lab.spec(0,state).x)):
			face_pose = lab.sample(0,state,index)
			renderer_index = 2;var original: Image = await render_image()
			renderer_index = 1;var old: Image = await render_image()
			renderer_index = 0;var actual: Image = await render_image()
			compare_original_pixels(original,actual,old)
	check(face_samples > 50000 and body_samples > 100000, "Dense comparison against original character pixels")
	check(repaired_face_samples > 1000, "Original facial pixel loss reproduced on v0.10.19")
	check(new_face_mismatches == 0, "No original face pixels lost")
	check(new_body_mismatches == 0, "No original body pixels lost")
	var result = {"version":"0.10.20","checks":checks,"failures":failures,"unchanged_graphics":unchanged,"unchanged_item_renders":protected_renders,"new_item_renders":new_renders,"hood_combination_renders":combinations,"original_face_samples":face_samples,"original_body_samples":body_samples,"old_face_mismatches":repaired_face_samples,"new_face_mismatches":new_face_mismatches,"new_body_mismatches":new_body_mismatches,"face_raster_tolerance_8bit":8,"max_face_channel_difference_8bit":roundi(max_face_channel_difference*255),"mismatch_examples":mismatch_examples}
	var file = FileAccess.open(output.path_join("items_validation.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("V120_ITEMS_", "OK" if failures.is_empty() else "FAILED", " ",JSON.stringify(result))
	viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

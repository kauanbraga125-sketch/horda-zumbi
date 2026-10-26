extends SceneTree

const CHANGED = ["z_pirate", "z_cyber", "z_goggles"]
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
var alpha_samples = 0
var lost_alpha_samples = 0
var old_lost_alpha_samples = 0
var active_id = "z_pirate"
var lens_center_checks = 0
var lens_center_failures = 0
var ear_samples = 0
var new_ear_mismatches = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message);push_error("V122_ITEMS_FAIL: " + message)

func draw_board() -> void:
	if not face_mode: canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(viewport.size)), Color("2b2237"))
	var actor = fitting if renderer_index == 0 else baseline if renderer_index == 1 else untouched
	if face_mode:
		for reverse in [false, true]:
			actor.paint(canvas, 0, Vector2(256 + 512 * int(reverse), 565), 350, face_pose.phase, face_pose.state, face_pose.time, face_pose.landing, Color.WHITE, reverse, face_pose.air_age, face_pose.vertical_speed, [active_id])
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
				if active_id != "z_pirate": face = face and y>=f.landmarks.chin[1]-.10*w
				var ear = active_id != "z_pirate" and x>=box[0]-.10*w and x<=box[0]+.23*w and y>=box[1]+.30*w and y<=box[1]+.85*w
				if ear:
					var sample_color = source.get_pixel(int(f.rect[0])+x,int(f.rect[1])+y)
					ear = sample_color.g>sample_color.r*1.02 and sample_color.g>sample_color.b*1.2
				var body = y >= f.landmarks.neck[1]+.12*w
				var test_point = Vector2i((transform * Vector2(x+.5, y+.5)).floor())
				if Rect2i(Vector2i.ZERO, original.get_size()).has_point(test_point):
					var alpha = original.get_pixelv(test_point).a
					if alpha > .05:
						alpha_samples += 1
						if actual.get_pixelv(test_point).a < alpha-3.1/255.0: lost_alpha_samples += 1
						if old.get_pixelv(test_point).a < alpha-3.1/255.0: old_lost_alpha_samples += 1
				if not face and not body and not ear: continue
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
				if ear:
					ear_samples += 1
					if different(expected,actual.get_pixelv(point),8.1/255.0):
						new_ear_mismatches += 1
						if mismatch_examples.size()<30:
							var value = actual.get_pixelv(point)
							mismatch_examples.append({"frame":face_pose.key,"item":active_id,"reverse":reverse,"source":[x,y],"expected":[expected.r8,expected.g8,expected.b8,expected.a8],"actual":[value.r8,value.g8,value.b8,value.a8],"error":"ear"})
				if body:
					body_samples += 1
					if different(expected, actual.get_pixelv(point)): new_body_mismatches += 1


func check_rendered_lenses(actual: Image, original: Image) -> void:
	var f: Dictionary = fitting.frames[face_pose.key]
	for reverse in [false,true]:
		var transform = face_transform(f,reverse)
		for lens in ["near","far"]:
			var center = Vector2i((transform*HordeCosmetics.vector(f.landmarks[lens])).floor())
			var found = false
			for y in range(center.y-2,center.y+3):
				for x in range(center.x-2,center.x+3):
					var color = actual.get_pixel(x,y)
					var changed = difference(color,original.get_pixel(x,y))>.12
					var optic = color.b>color.g*1.25 and color.b>.30 if active_id=="z_cyber" else color.r>.45 and color.g>.35 and color.r>color.g*1.12 and color.b<color.g*.8
					if color.a>.95 and changed and optic: found = true
			lens_center_checks += 1
			if not found:
				lens_center_failures += 1
				if mismatch_examples.size()<20:mismatch_examples.append({"frame":face_pose.key,"item":active_id,"lens":lens,"reverse":reverse,"error":"Rendered lens center"})

func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	fitting = HordeCosmetics.new();fitting.ensure_data()
	baseline = load("res://tests/v122_original_cosmetics.gd").new();baseline.ensure_data()
	baseline.graphics = JSON.parse_string(FileAccess.get_file_as_string("res://tests/v122_before_graphics.json"))
	untouched = load("res://tests/v122_untouched.gd").new();untouched.ensure_data()
	lab = load("res://scripts/item_lab.gd").new()
	check(str(ProjectSettings.get_setting("application/config/version")) == "0.10.22", "Compiled version 0.10.22")
	var unchanged = 0
	for id in fitting.graphics:
		if id in CHANGED: continue
		check(fitting.graphics[id] == baseline.graphics[id], "Graphic unchanged: " + id);unchanged += 1
	check(unchanged == 32, "Other 32 accessories unchanged")
	check(FileAccess.get_sha256("res://assets/art/cosmetics_v113/fitting.bin") == "5a7fdb5ebdb86a0c92f97813559272b778d3ec65987f458127f9d66d76ee8940", "All 263 existing frame measurements and meshes byte-identical to 0.10.20")
	for key in fitting.frames:
		var f: Dictionary = fitting.frames[key]
		if int(f.kind) != 0: continue
		check(f.meshes.has("hood_base") and f.meshes.has("hood_base_cape"), "Complete hood body and cape layer: " + key)
		for id in ["z_cyber","z_goggles"]:
			var rig: Dictionary = fitting.graphics[id].eye_rig
			for lens in ["near","far"]:
				var contact = HordeCosmetics.vector(rig[lens])
				check(fitting.eye_point(id,f,contact).distance_to(HordeCosmetics.vector(f.landmarks[lens]))<.001,"Lens centered on measured eye: "+key+id+lens)
				var radius = 22.0 if lens=="near" else 10.0
				var horizontal = fitting.eye_point(id,f,contact+Vector2(radius,0))-fitting.eye_point(id,f,contact-Vector2(radius,0))
				var vertical = fitting.eye_point(id,f,contact+Vector2(0,radius))-fitting.eye_point(id,f,contact-Vector2(0,radius))
				check(absf(horizontal.length()-vertical.length())<.001 and absf(horizontal.dot(vertical))<.001,"Rigid lens without squash or shear: "+key+id+lens)
		for id in ["z_pirate"]:
			var transform = fitting.fit_transform(id, f)
			check(transform.is_finite() and transform.determinant() > .000001, "Valid hat fit: " + key + id)
			check(absf(transform.x.length()-transform.y.length()) < .00001 and absf(transform.x.dot(transform.y)) < .00001, "Uniform scale without shearing: " + key + id)
			var image: Image = fitting.texture(fitting.graphics[id].file).get_image()
			for eye in ["near", "far"]:
				var point = Vector2i((transform.affine_inverse() * HordeCosmetics.vector(f.landmarks[eye])).round())
				check(not Rect2i(Vector2i.ZERO, image.get_size()).has_point(point) or image.get_pixelv(point).a < 8.0/255.0, "Eye center visible: " + key + id + eye)
	viewport = SubViewport.new();viewport.transparent_bg = true;viewport.size = Vector2i(1920,1440);viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
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
	for glasses in ["z_cyber","z_goggles"]:
		for entry in HordeCosmeticCatalog.ITEMS:
			if entry.kind != 0 or entry.slot == "face": continue
			for state in range(lab.STATES.size()):
				for reverse in [false,true]: jobs.append({"kind":0,"state":state,"index":0,"reverse":reverse,"wear":[entry.id,glasses]})
	for offset in range(0,jobs.size(),48):
		page = jobs.slice(offset,mini(offset+48,jobs.size()));var image: Image = await render_image()
		image.save_png(output.path_join("eyewear_combinations_%03d.png" % offset))
	var combinations = jobs.size()
	face_mode = true;viewport.size = Vector2i(1024,600)
	for id in CHANGED:
		active_id = id
		for state in range(lab.STATES.size()):
			for index in range(int(lab.spec(0,state).x)):
				face_pose = lab.sample(0,state,index)
				renderer_index = 2;var original: Image = await render_image()
				renderer_index = 1;var old: Image = await render_image()
				renderer_index = 0;var actual: Image = await render_image()
				compare_original_pixels(original,actual,old)
				if active_id != "z_pirate": check_rendered_lenses(actual,original)
	check(face_samples > 50000 and body_samples > 100000, "Dense comparison against original character pixels")
	check(alpha_samples > 400000, "Dense full-character alpha comparison including hair and outlines")
	check(lost_alpha_samples == 0, "No original sprite pixels cut away by the hood, including hair and silhouette")
	check(new_face_mismatches == 0, "No original face pixels lost")
	check(new_body_mismatches == 0, "No original body pixels lost")
	check(new_ear_mismatches == 0 and ear_samples>1000,"Eyewear temples do not overwrite the visible ears")
	check(lens_center_checks>700 and lens_center_failures==0,"Both rendered lenses cover their measured eye centers in every pose and direction")
	var result = {"version":"0.10.22","checks":checks,"failures":failures,"unchanged_graphics":unchanged,"unchanged_item_renders":protected_renders,"new_item_renders":new_renders,"eyewear_combination_renders":combinations,"original_face_samples":face_samples,"original_body_samples":body_samples,"old_face_mismatches":repaired_face_samples,"new_face_mismatches":new_face_mismatches,"new_body_mismatches":new_body_mismatches,"face_raster_tolerance_8bit":8,"max_face_channel_difference_8bit":roundi(max_face_channel_difference*255),"mismatch_examples":mismatch_examples,"alpha_samples":alpha_samples,"lost_alpha_samples":lost_alpha_samples,"old_lost_alpha_samples":old_lost_alpha_samples,"ear_samples":ear_samples,"new_ear_mismatches":new_ear_mismatches,"lens_center_checks":lens_center_checks,"lens_center_failures":lens_center_failures}
	var file = FileAccess.open(output.path_join("items_validation.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("V122_ITEMS_", "OK" if failures.is_empty() else "FAILED", " ",JSON.stringify(result))
	viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

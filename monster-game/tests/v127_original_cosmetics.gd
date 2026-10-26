extends RefCounted

const ROOT = "res://assets/art/cosmetics_v113/"
const WEAR_CHANCE = 0.58
var frames: Dictionary = {}
var graphics: Dictionary = {}
var textures: Dictionary = {}
var meshes: Dictionary = {}
var item_meshes: Dictionary = {}
var preview_cache: Dictionary = {}

func ensure_data() -> void:
	if not frames.is_empty(): return
	var packed = FileAccess.get_file_as_bytes(ROOT + "fitting.bin")
	assert(packed.size() > 4, "Missing attachment measurements")
	frames = JSON.parse_string(packed.slice(4).decompress(packed.decode_u32(0), FileAccess.COMPRESSION_ZSTD).get_string_from_utf8())
	graphics = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "graphics.json"))
	var original = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/zombie-fluid-v73.json"))
	for i in range(original.frames.size()): frames["z_other_" + str(i)].original_outline = original.frames[i].outline
	var wigs = FileAccess.get_file_as_bytes("res://assets/art/cosmetics_v123/clown_sources.bin")
	var sources: Dictionary = JSON.parse_string(wigs.slice(4).decompress(wigs.decode_u32(0), FileAccess.COMPRESSION_ZSTD).get_string_from_utf8())
	for key in sources:
		frames[key].meshes.clown_base = sources[key].base
		frames[key].meshes.clown_details = sources[key].details
	var extra = FileAccess.get_file_as_bytes("res://assets/art/cosmetics_v124/source_layers.bin")
	var layers: Dictionary = JSON.parse_string(extra.slice(4).decompress(extra.decode_u32(0), FileAccess.COMPRESSION_ZSTD).get_string_from_utf8())
	for key in layers:
		for layer in layers[key]: frames[key].meshes[layer] = layers[key][layer]
	var hair = FileAccess.get_file_as_bytes("res://assets/art/cosmetics_v125/hair_layers.bin")
	var clean: Dictionary = JSON.parse_string(hair.slice(4).decompress(hair.decode_u32(0), FileAccess.COMPRESSION_ZSTD).get_string_from_utf8())
	for key in clean:
		for layer in clean[key]: frames[key].meshes[layer] = clean[key][layer]
	var collars = FileAccess.get_file_as_bytes("res://assets/art/cosmetics_v126/layers.bin")
	var foreground: Dictionary = JSON.parse_string(collars.slice(4).decompress(collars.decode_u32(0), FileAccess.COMPRESSION_ZSTD).get_string_from_utf8())
	for key in foreground:
		for layer in foreground[key]: frames[key].meshes[layer] = foreground[key][layer]

static func item(id: String) -> Dictionary:
	for entry in HordeCosmeticCatalog.ITEMS:
		if entry.id == id: return entry
	return {}

static func choose(seed_value: int, member_id: int, kind: int, active: Array) -> Array:
	if kind not in [0, 1] or active.is_empty(): return []
	var random = RandomNumberGenerator.new()
	random.seed = (seed_value ^ (member_id * 2654435761) ^ (kind * 9767) ^ 0x43afe) & 0x7fffffffffffffff
	if random.randf() >= WEAR_CHANCE: return []
	var pool: Array = []
	for id in active:
		var entry = item(str(id))
		if not entry.is_empty() and int(entry.kind) == kind: pool.append(entry)
	var selected: Array = [];var slots: Array = []
	var amount = 2 if random.randf() < 0.35 else 1
	for _i in range(amount):
		var eligible = pool.filter(func(entry): return entry.slot not in slots)
		if eligible.is_empty(): break
		var total = 0
		for entry in eligible: total += [6, 5, 3, 2, 1][int(entry.rarity) - 1]
		var roll = random.randi_range(0, total - 1)
		for entry in eligible:
			roll -= [6, 5, 3, 2, 1][int(entry.rarity) - 1]
			if roll < 0:
				selected.append(entry.id);slots.append(entry.slot);break
	return selected

func texture(file: String) -> Texture2D:
	if not textures.has(file): textures[file] = load("res://assets/art/" + file)
	return textures[file]

func read_mesh(data: Dictionary, region: Array, size: Vector2) -> ArrayMesh:
	if data.points.is_empty(): return null
	var vertices = PackedVector3Array();var uv = PackedVector2Array()
	var source_points: Array = data.get("uv_points",data.points)
	for i in range(data.points.size()):
		var p: Array = data.points[i];var sample: Array = source_points[i]
		vertices.append(Vector3(p[0], p[1], 0))
		uv.append((Vector2(region[0], region[1]) + Vector2(sample[0], sample[1])) / size)
	var arrays = [];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices;arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(data.indices)
	var result = ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func source_mesh(key: String, cut: String) -> ArrayMesh:
	var cache = key + ":" + cut
	if not meshes.has(cache):
		var f: Dictionary = frames[key]
		meshes[cache] = read_mesh(f.meshes[cut], f.rect, texture(f.file).get_size())
	return meshes[cache]

func draw_source(canvas: Node2D, key: String, cut: String, transform: Transform2D, tint: Color) -> void:
	var value = source_mesh(key, cut)
	if value == null: return
	canvas.draw_set_transform_matrix(transform)
	canvas.draw_mesh(value, texture(frames[key].file), Transform2D.IDENTITY, tint)

static func vector(value: Array) -> Vector2:
	return Vector2(value[0], value[1])

func fit_transform(id: String, f: Dictionary) -> Transform2D:
	var entry = item(id);var graphic: Dictionary = graphics[id]
	var points: Array = graphic.contacts
	var size = Vector2(graphic.rect[2], graphic.rect[3])
	var a = vector(points[0]) * size;var b = vector(points[1]) * size
	var landmarks: Dictionary = f.landmarks
	var target_a: Vector2;var target_b: Vector2;var target_c: Vector2
	var right = vector(f.right);var down = vector(f.down);var w = float(f.head_width)
	if graphic.has("body_rig"):
		var rig: Dictionary = graphic.body_rig
		var body_down = (vector(landmarks.hip)-vector(landmarks.neck)).normalized()
		var body_right = Vector2(body_down.y,-body_down.x)
		var fitted = Transform2D(body_right.angle(),Vector2.ZERO)
		fitted.x *= w*float(rig.scale);fitted.y *= w*float(rig.scale)
		var offset = vector(rig.offset)
		fitted.origin = vector(landmarks.neck)+(right*offset.x+down*offset.y)*w-fitted.basis_xform(vector(rig.anchor))
		return fitted
	if graphic.has("neck_rig"):
		var rig: Dictionary = graphic.neck_rig
		var rear = vector(rig.rear_offset);var front = vector(rig.front_offset)
		var target_rear = vector(landmarks.neck)+(right*rear.x+down*rear.y)*w
		var target_front = vector(landmarks.neck)+(right*front.x+down*front.y)*w
		var from = vector(rig.front)-vector(rig.rear);var to = target_front-target_rear
		var fitted = Transform2D(to.angle()-from.angle(),Vector2.ZERO)
		fitted.x *= to.length()/from.length();fitted.y *= to.length()/from.length()
		fitted.origin = target_rear-fitted.basis_xform(vector(rig.rear))
		return fitted
	if graphic.has("mask_surface"):
		# The redrawn shell follows both eye apertures and the lower jaw.
		var surface: Dictionary = graphic.mask_surface
		var from = vector(surface.near)
		var source = Transform2D(vector(surface.far)-from,vector(surface.chin)-from,from)
		var near_eye = vector(landmarks.near)
		var chin = vector(landmarks.chin)+down*float(surface.chin_offset)*w
		var target = Transform2D(vector(landmarks.far)-near_eye,chin-near_eye,near_eye)
		return target*source.affine_inverse()
	if graphic.has("rigid_eyes"):
		# Keep the bridge, frame and both lenses in one rigid piece.
		var rig: Dictionary = graphic.rigid_eyes
		var from = vector(rig.far) - vector(rig.near)
		var to = vector(landmarks.far) - vector(landmarks.near)
		var fitted = Transform2D(to.angle() - from.angle(), Vector2.ZERO)
		fitted.x *= to.length()/from.length();fitted.y *= to.length()/from.length()
		fitted.origin = vector(landmarks.near) - fitted.basis_xform(vector(rig.near))
		return fitted
	if graphic.has("mask_fit"):
		# Least-squares similarity fit follows eyes and chin without flattening.
		var rig: Dictionary = graphic.mask_fit
		var source_center = (vector(rig.near)+vector(rig.far)+vector(rig.chin))/3.0
		var target_center = (vector(landmarks.near)+vector(landmarks.far)+vector(landmarks.chin))/3.0
		var dot = 0.0;var cross = 0.0;var squared = 0.0
		for name in ["near","far","chin"]:
			var source_point = vector(rig[name])-source_center
			var target_point = vector(landmarks[name])-target_center
			dot += source_point.dot(target_point);cross += source_point.cross(target_point);squared += source_point.length_squared()
		var fitted = Transform2D(atan2(cross,dot),Vector2.ZERO)
		var scale = sqrt(dot*dot+cross*cross)/maxf(squared,.001)
		fitted.x *= scale;fitted.y *= scale;fitted.origin = target_center-fitted.basis_xform(source_center)
		return fitted
	if graphic.has("hair_fit"):
		var rig: Dictionary = graphic.hair_fit
		var fitted = Transform2D(right.angle()+float(rig.angle),Vector2.ZERO)
		var scale = w*float(rig.scale)
		fitted.x *= scale;fitted.y *= scale
		var offset = vector(rig.offset)
		fitted.origin = vector(landmarks.scalp)+(right*offset.x+down*offset.y)*w-fitted.basis_xform(vector(rig.anchor))
		return fitted
	if graphic.has("eye_rig"):
		# Bounds use the near-lens transform. Drawing fits each lens separately.
		var rig: Dictionary = graphic.eye_rig
		var fitted = Transform2D(right.angle(),Vector2.ZERO)
		fitted.x *= w*float(rig.scale);fitted.y *= w*float(rig.scale)
		fitted.origin = vector(landmarks.near)-fitted.basis_xform(vector(rig.near))
		return fitted
	if graphic.has("skull_fit"):
		# Two measured contact points follow the skull with a uniform scale.
		# The complete original sprite stays underneath these fitted pieces.
		var rear = vector(graphic.skull_fit[0]);var brow = vector(graphic.skull_fit[1])
		var back = vector(landmarks.scalp) + (right * rear.x + down * rear.y) * w
		var front = vector(landmarks.scalp) + (right * brow.x + down * brow.y) * w
		var from = b - a;var to = front - back
		var fitted = Transform2D(to.angle() - from.angle(), Vector2.ZERO)
		var scale = to.length() / from.length()
		fitted.x *= scale;fitted.y *= scale
		fitted.origin = back - fitted.basis_xform(a)
		return fitted
	if id in ["z_straw", "z_adventure", "z_nightmare", "z_sorcerer"] and bool(graphic.get("worn_brim", false)):
		# Fit the crown to the skull, leaving the wide brim outside its contact
		# points. Uniform scaling preserves the woven straw and curved edge.
		var back = vector(landmarks.scalp) - right * .57 * w
		var front = vector(landmarks.scalp) + right * .52 * w - down * .24 * w
		var from = b - a
		var to = front - back
		var fitted = Transform2D(to.angle() - from.angle(), Vector2.ZERO)
		var scale = to.length() / from.length()
		fitted.x *= scale;fitted.y *= scale
		fitted.origin = back - fitted.basis_xform(a)
		var wear_scale = float(graphic.get("wear_scale", 1.0))
		if wear_scale != 1.0:
			# Resize around the band, so the hat stays seated as it gets smaller.
			var center = (back + front) * .5
			fitted.x *= wear_scale;fitted.y *= wear_scale
			fitted.origin = center + (fitted.origin - center) * wear_scale
		if graphic.has("wear_center"):
			# Center the crown on the skull; the ribbon is outside the contact band.
			var offset = vector(graphic.wear_center)
			var center = vector(landmarks.scalp) + (right * offset.x + down * offset.y) * w
			fitted.origin += center - (back + front) * .5
		return fitted
	if id == "z_plumber" and bool(graphic.get("closed_band", false)):
		# The closed cloth band sits around the skull. Keep the redrawn cap's
		# proportions with a similarity fit, instead of shearing its opening.
		var back = vector(landmarks.scalp) - right * .57 * w + down * .05 * w
		var front = vector(landmarks.scalp) + right * .52 * w - down * .08 * w
		var from = b - a
		var to = front - back
		var fitted = Transform2D(to.angle() - from.angle(), Vector2.ZERO)
		var scale = to.length() / from.length()
		fitted.x *= scale;fitted.y *= scale
		fitted.origin = back - fitted.basis_xform(a)
		return fitted
	if id == "z_electric":
		# Fit the aperture from scalp to chin using a uniform scale. A three
		# point shear flattened the ears when the opening was shortened.
		var opening_top = Vector2(.73,.40)*size
		var opening_bottom = Vector2(.71,.96)*size
		var upper_offset = -.18
		if bool(graphic.get("behind_body", false)):
			# Follow the centre of the aperture, rather than its front edge.
			# The old pair rotated the hood backward and left the brow uncovered.
			opening_top = Vector2(.60,.40)*size
			opening_bottom = Vector2(.72,.96)*size
			upper_offset = -.12
		var top = vector(landmarks.scalp)+down*upper_offset*w
		var bottom = vector(landmarks.chin)+down*.06*w
		var from = opening_bottom-opening_top;var to = bottom-top
		var fitted = Transform2D(to.angle()-from.angle(),Vector2.ZERO)
		var scale = to.length()/from.length()
		fitted.x *= scale;fitted.y *= scale;fitted.origin = top-fitted.basis_xform(opening_top)
		return fitted
	match str(entry.fit):
		"eyes", "mask":
			target_a = vector(landmarks.near);target_b = vector(landmarks.far);target_c = vector(landmarks.chin)
		"chain":
			target_a = vector(landmarks.neck_back);target_b = vector(landmarks.throat);target_c = vector(landmarks.pendant)
		"vest":
			target_a = vector(landmarks.shoulder_back);target_b = vector(landmarks.shoulder_front);target_c = vector(landmarks.hip)
		"cape":
			target_a = vector(landmarks.neck)
			target_b = target_a + down * 1.35 * w - right * .15 * w
			target_c = target_a - right * 1.80 * w + down * .70 * w
		"scarf":
			target_a = vector(landmarks.neck_back);target_b = vector(landmarks.throat);target_c = vector(landmarks.cape_tail)
		"hair":
			target_a = vector(landmarks.scalp) - right * .34 * w;target_b = vector(landmarks.scalp) + right * .34 * w
		"helmet":
			target_a = vector(landmarks.scalp) - right * .38 * w + down * .10 * w;target_b = vector(landmarks.scalp) + right * .40 * w + down * .10 * w;target_c = vector(landmarks.chin) + down * .08 * w
		_:
			target_a = vector(landmarks.rim_l);target_b = vector(landmarks.rim_r)
	var source_delta = b - a;var delta = target_b - target_a
	if str(entry.fit) == "eyes":
		# Similarity fit preserves the shapes of round lenses.
		var result = Transform2D(delta.angle() - source_delta.angle(), Vector2.ZERO)
		var factor = delta.length() / source_delta.length()
		result.x *= factor;result.y *= factor;result.origin = target_a - result.basis_xform(a)
		return result
	var c: Vector2
	if points.size() >= 3:
		c = vector(points[2]) * size
	else:
		c = (a + b) * .5 - Vector2(0, size.y)
		var lift = delta.length() / maxf(1, absf(source_delta.x)) * size.y * (.87 if str(entry.fit) == "hair" else .78)
		target_c = (target_a + target_b) * .5 - down * lift
	var source = Transform2D(b - a, c - a, a)
	var target = Transform2D(target_b - target_a, target_c - target_a, target_a)
	var result = target * source.affine_inverse()
	var adjustments = {"z_clown":.88,"z_scientist":.80,"s_silver":.85,"s_punk":.82,"z_electric":.90}
	var factor = float(adjustments.get(id,1.0))
	if factor != 1.0:
		var pivot = (target_a+target_b)*.5
		result.x *= factor;result.y *= factor;result.origin = pivot+(result.origin-pivot)*factor
	return result

func eye_point(id: String, f: Dictionary, point: Vector2) -> Vector2:
	var rig: Dictionary = graphics[id].eye_rig
	var near_source = vector(rig.near);var far_source = vector(rig.far)
	var near_target = vector(f.landmarks.near);var far_target = vector(f.landmarks.far)
	var right = vector(f.right);var down = vector(f.down);var w = float(f.head_width)
	var scale = w*float(rig.scale)
	var near_delta = point-near_source;var far_delta = point-far_source
	var near_point = near_target+(right*near_delta.x+down*near_delta.y)*scale
	var far_point = far_target+(right*far_delta.x+down*far_delta.y)*scale
	var amount = smoothstep(float(rig.bridge[0]),float(rig.bridge[1]),point.x)
	var result = near_point.lerp(far_point,amount)
	if point.x<110:
		var anchor = vector(rig.temple);var delta = anchor-near_source;var offset = vector(rig.temple_target)
		var actual = near_target+(right*delta.x+down*delta.y)*scale
		var target = vector(f.landmarks.scalp)+(right*offset.x+down*offset.y)*w
		result += (target-actual)*(1.0-smoothstep(float(rig.temple[0]),110.0,point.x))
	return result

func draw_eye_item(canvas: Node2D, id: String, f: Dictionary, root: Transform2D, tint: Color, front: bool) -> void:
	var graphic: Dictionary = graphics[id]
	var cache = id+":eyes:"+str(f.file)+str(f.rect)+(":front" if front else "")
	if not item_meshes.has(cache):
		var data: Dictionary = graphic.front_mesh if front else graphic.mesh
		var vertices = PackedVector3Array();var uv = PackedVector2Array();var tex = texture(graphic.file)
		for value in data.points:
			var source = vector(value);var point = eye_point(id,f,source)
			vertices.append(Vector3(point.x,point.y,0))
			uv.append((Vector2(graphic.rect[0],graphic.rect[1])+source)/tex.get_size())
		var indices = PackedInt32Array()
		for i in range(0,data.indices.size(),3):
			var a = int(data.indices[i]);var b = int(data.indices[i+1]);var c = int(data.indices[i+2])
			var center = (vertices[a]+vertices[b]+vertices[c])/3.0
			# The original ear occludes the temple, also in the capture pose
			# where the ear sits unusually close to the near lens.
			if front and center.x<float(f.box[0])+.32*float(f.head_width) and center.y>float(f.box[1])+.25*float(f.head_width) and center.y<float(f.box[1])+.90*float(f.head_width): continue
			indices.append_array(PackedInt32Array([a,b,c]))
		var arrays = [];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
		var result = ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);item_meshes[cache]=result
	canvas.draw_set_transform_matrix(root)
	canvas.draw_mesh(item_meshes[cache],texture(graphic.file),Transform2D.IDENTITY,tint)

func draw_item(canvas: Node2D, id: String, f: Dictionary, root: Transform2D, tint: Color, front: bool = false) -> void:
	if graphics[id].has("eye_rig"):
		draw_eye_item(canvas,id,f,root,tint,front);return
	var cache = id+(":front" if front else "")
	if not item_meshes.has(cache):
		var graphic: Dictionary = graphics[id]
		item_meshes[cache] = read_mesh(graphic.get("front_mesh",graphic.mesh) if front else graphic.mesh,graphic.rect,texture(graphic.file).get_size())
	var value: ArrayMesh = item_meshes[cache]
	if value == null: return
	canvas.draw_set_transform_matrix(root * fit_transform(id, f))
	canvas.draw_mesh(value, texture(graphics[id].file), Transform2D.IDENTITY, tint)

func preview_bounds(id: String) -> Rect2:
	ensure_data()
	if preview_cache.has(id): return preview_cache[id]
	var entry = item(id);var graphic: Dictionary = graphics[id]
	var gb: Array = graphic.bounds
	var accessory = Rect2(gb[0],gb[1],gb[2],gb[3])
	var result = Rect2();var first = true
	for key in frames:
		if not str(key).begins_with("z_run_" if entry.kind == 0 else "s_run_"): continue
		var f: Dictionary = frames[key];var values: Array = f.bounds
		var bounds = Rect2(values[0],values[1],values[2],values[3])
		var transform = fit_transform(id,f)
		for point in [accessory.position,Vector2(accessory.end.x,accessory.position.y),accessory.end,Vector2(accessory.position.x,accessory.end.y)]:
			bounds = bounds.expand(transform*point)
		bounds = Rect2((bounds.position-vector(f.anchor))/float(f.height),bounds.size/float(f.height))
		result = bounds if first else result.merge(bounds);first = false
	preview_cache[id] = result.grow(.045)
	return preview_cache[id]

func draw_expressions(canvas: Node2D, f: Dictionary, root: Transform2D, phase: float, time: float, tint: Color) -> void:
	if not f.has("expression"): return
	var index = HordeZombieStride.FRAME_COUNT * fposmod(phase, 1.0)
	var blinking = int(index) % 8 < 4 and fposmod(time, 5.4) >= .65 and fposmod(time, 5.4) < .99
	var glancing = int(index) % 8 >= 4 and fposmod(time, 7.2) >= 1.8 and fposmod(time, 7.2) < 2.19
	for type in ["eye", "mouth"]:
		var field = type + "_patch"
		if not f.expression.has(field) or (type == "eye" and not blinking and not glancing) or (type == "mouth" and not glancing): continue
		var sheet = "expression" if type == "eye" else "mouth"
		var path: String = f.expression.sheets[sheet]
		var cache = str(f.file) + str(f.rect) + type
		if not meshes.has(cache): meshes[cache] = HordeZombieStride.patch_mesh(f.expression[field], texture(path).get_size())
		canvas.draw_set_transform_matrix(root * Transform2D(0, vector(f.anchor)))
		canvas.draw_mesh(meshes[cache], texture(path), Transform2D.IDENTITY, tint)

func paint(canvas: Node2D, kind: int, foot: Vector2, height: float, phase: float, state: String, time: float, landing: float, tint: Color, reverse: bool, air_age: float, vertical_speed: float, wear: Array) -> bool:
	if kind not in [0, 1] or wear.is_empty(): return false
	ensure_data()
	var key = "";var anchor = Vector2.ZERO;var angle = 0.0;var stretch = Vector2.ONE;var origin = foot
	if kind == 0:
		if state == "run" and landing <= 0:
			key = "z_run_" + str(posmod(int(fposmod(phase, 1.0) * 16), 16))
			var step = fposmod(phase * 2.0, 1.0)
			var lift = 2.6 * pow(sin((step - .76) / .24 * PI), 2) if step > .76 else 0.0
			origin.y -= lift * height / 112.0
			angle = .006 * sin((phase * 2.0 - .1) * TAU)
		else:
			key = "z_other_" + str(HordeZombieSprite.frame_index(state, phase, time, landing, air_age, vertical_speed))
			if state in ["idle", "aim"]:
				var breath = sin(time * TAU / 2.4)
				stretch = Vector2(1.0 - breath * .004, 1.0 + breath * .009);angle = sin(time * TAU / 4.8) * .004
	else:
		var clip = HordeSkeletonApprovedSprite.clip_for(state, landing)
		if clip.is_empty(): return false
		var index = HordeSkeletonApprovedSprite.frame_for(state, phase, time, landing, air_age, vertical_speed)
		key = "s_" + clip + "_" + str(index)
		anchor = Vector2(frames[key].anchor[0], HordeSkeletonApprovedSprite.foot_anchor_for(clip, index, clip == "jump" and state == "run" and landing > 0))
	if not frames.has(key): return false
	var f: Dictionary = frames[key]
	if kind == 0: anchor = vector(f.anchor)
	var root = Transform2D(angle * (-1 if reverse else 1), origin)
	root.x *= (-1 if reverse else 1) * stretch.x * height / float(f.height)
	root.y *= stretch.y * height / float(f.height)
	root.origin -= root.basis_xform(anchor)
	var head: Array = [];var face: Array = [];var clothes: Array = []
	var cape = false
	for value in wear:
		var entry = item(str(value))
		if entry.is_empty() or int(entry.kind) != kind: continue
		if entry.slot == "head": head.append(entry.id)
		elif entry.slot == "face": face.append(entry.id)
		else: clothes.append(entry.id)
		if entry.fit in ["cape", "scarf"]: draw_item(canvas, entry.id, f, root, tint)
		if bool(graphics[entry.id].get("behind_body", false)): draw_item(canvas, entry.id, f, root, tint)
		if entry.fit == "cape": cape = true
	var preserve_source = not head.is_empty() and bool(graphics[head[0]].get("preserve_source", false))
	if (not head.is_empty() or (cape and kind == 1)) and not preserve_source:
		var cut = "cape_only"
		if not head.is_empty():
			cut = str(graphics[head[0]].get("source_mesh", "hat" if item(head[0]).fit == "hat" else "bare"))
			if cape and kind == 1: cut += "_cape"
		draw_source(canvas,key,cut,root,tint)
	else:
		# Full original source, same rectangle and same transform.
		canvas.draw_set_transform_matrix(root)
		if f.has("original_outline"):
			var outline = PackedVector2Array();var uvs = PackedVector2Array()
			for point in f.original_outline:
				var local = vector(point);outline.append(local)
				uvs.append((Vector2(f.rect[0],f.rect[1]) + local) / texture(f.file).get_size())
			canvas.draw_polygon(outline, PackedColorArray([tint]), uvs, texture(f.file))
		else:
			canvas.draw_texture_rect_region(texture(f.file), Rect2(Vector2.ZERO, Vector2(f.rect[2], f.rect[3])), Rect2(f.rect[0], f.rect[1], f.rect[2], f.rect[3]), tint)
	for id in head:
		# A hood's lining and hanging cloth sit behind the intact face and arms.
		if bool(graphics[id].get("behind_body", false)):
			if graphics[id].has("front_mesh"): draw_item(canvas,id,f,root,tint,true)
			if id == "z_clown": draw_source(canvas,key,"clown_details",root,tint)
			continue
		draw_item(canvas, id, f, root, tint)
		if graphics[id].has("reveal_source"): draw_source(canvas,key,str(graphics[id].reveal_source),root,tint)
		elif item(id).fit != "hat" and not bool(graphics[id].get("preserve_source", false)): draw_source(canvas,key,"face",root,tint)
	draw_expressions(canvas, f, root, phase, time, tint)
	for id in clothes:
		draw_item(canvas,id,f,root,tint,item(id).fit == "cape" or bool(graphics[id].get("layered_neck",false)))
		if graphics[id].has("clothes_reveal"): draw_source(canvas,key,str(graphics[id].clothes_reveal),root,tint)
	if not clothes.is_empty(): draw_source(canvas,key,"arms",root,tint)
	for id in face:
		draw_item(canvas, id, f, root, tint,bool(graphics[id].get("layered_eyes",false)))
		if graphics[id].has("reveal_source"): draw_source(canvas,key,str(graphics[id].reveal_source),root,tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	return true

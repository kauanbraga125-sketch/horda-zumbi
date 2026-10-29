extends RefCounted
## Seated bodies and original opaque heads are independent render layers.
const Art = preload("res://scripts/sewer_art.gd")
var poses: Dictionary = {}
var body_meshes: Dictionary = {}
var heads: Dictionary = {}

func map_mesh(data: Dictionary,t: Transform2D) -> Dictionary:
	var result = data.duplicate(true);result.uv_points = data.get("uv_points",data.points).duplicate(true)
	for i in range(result.points.size()):
		var p = t*Vector2(result.points[i][0],result.points[i][1]);result.points[i] = [p.x,p.y]
	return result

func pose(cosmetics,kind: int,index: int) -> Dictionary:
	var key = "%d:%d" % [kind,index]
	if poses.has(key): return poses[key]
	cosmetics.ensure_data()
	var id = "zombie_riders" if kind==0 else "skeleton_riders"
	var measured: Dictionary = Art.data()[id].poses[index]
	var source_key = "z_other_24" if kind==0 else "s_run_0"
	var old: Dictionary = cosmetics.frames[source_key];var f = old.duplicate(true)
	var near = Vector2(measured.near[0],measured.near[1]);var far = Vector2(measured.far[0],measured.far[1])
	var old_near = Vector2(old.landmarks.near[0],old.landmarks.near[1]);var old_far = Vector2(old.landmarks.far[0],old.landmarks.far[1])
	var from = old_far-old_near;var to = far-near
	var head = Transform2D(to.angle()-from.angle(),Vector2.ZERO)
	var head_scale = float(measured.head_width)/float(old.head_width)
	head.x *= head_scale;head.y *= head_scale
	head.origin = near-head.basis_xform(old_near)
	for name in f.landmarks:
		var p = head*Vector2(old.landmarks[name][0],old.landmarks[name][1]);f.landmarks[name] = [p.x,p.y]
	f.landmarks.neck = measured.neck;f.landmarks.hip = measured.hip
	var old_neck = Vector2(old.landmarks.neck[0],old.landmarks.neck[1]);var old_hip = Vector2(old.landmarks.hip[0],old.landmarks.hip[1])
	var new_neck = Vector2(measured.neck[0],measured.neck[1]);var new_hip = Vector2(measured.hip[0],measured.hip[1])
	var a = old_hip-old_neck;var b = new_hip-new_neck
	var fitted = Transform2D(Vector2(b.y,-b.x),b,new_neck)*Transform2D(Vector2(a.y,-a.x),a,old_neck).affine_inverse()
	if f.has("items_v129"):
		for item in f.items_v129: f.items_v129[item] = map_mesh(old.items_v129[item],fitted if cosmetics.item(item).slot not in ["head","face"] else head)
	if f.has("front_v127"):
		for item in f.front_v127: f.front_v127[item] = map_mesh(old.front_v127[item],head if cosmetics.item(item).slot in ["head","face"] else fitted)
	if f.has("body_v129"):
		for name in f.body_v129:
			var value = f.body_v129[name]
			if value is Array and value.size()==2:
				var point = fitted*Vector2(value[0],value[1]);f.body_v129[name] = [point.x,point.y]
	var right = to.normalized();f.right = [right.x,right.y];f.down = [-right.y,right.x]
	f.head_width = measured.head_width
	f.anchor = measured.hip;f.height = measured.height;f.rect = [(index%4)*448,int(index/4)*448,448,448]
	f.file = "v140/"+id+".webp";f.key = "rider_"+key;f.source_key = source_key;f.head_transform = head
	poses[key] = f;return f

func head_mesh(cosmetics,key: String,cut: String) -> ArrayMesh:
	var cache = key+":"+cut
	if heads.has(cache): return heads[cache]
	var f: Dictionary = cosmetics.frames[key]
	var w = float(f.head_width)
	var hull = PackedVector2Array([Vector2(128,0),Vector2(386,0),Vector2(386,192),Vector2(322,199),Vector2(246,207),Vector2(193,181),Vector2(128,153)]) if key.begins_with("z_") else PackedVector2Array([Vector2(185,0),Vector2(384,0),Vector2(384,147),Vector2(265,155),Vector2(223,147),Vector2(195,127),Vector2(185,112)])
	var mesh: ArrayMesh
	if cut=="whole":
		mesh = cosmetics.read_mesh({"points":[[0,0],[f.rect[2],0],[f.rect[2],f.rect[3]],[0,f.rect[3]]],"indices":[0,1,2,0,2,3]},f.rect,cosmetics.texture(f.file).get_size())
	else: mesh = cosmetics.source_mesh(key,cut)
	if mesh==null: heads[cache] = null;return null
	var original = mesh.surface_get_arrays(0);var vertices: PackedVector3Array = original[Mesh.ARRAY_VERTEX];var uv: PackedVector2Array = original[Mesh.ARRAY_TEX_UV];var indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
	var points = PackedVector3Array();var samples = PackedVector2Array();var triangles = PackedInt32Array()
	for i in range(0,indices.size(),3):
		var poly: Array = []
		for j in range(3):
			var n = indices[i+j];poly.append({"p":vertices[n],"uv":uv[n]})
		for side in range(hull.size()):
			var clipped: Array = [];var aa = hull[side];var bb = hull[(side+1)%hull.size()]
			for j in range(poly.size()):
				var a: Dictionary = poly[j];var b: Dictionary = poly[(j+1)%poly.size()]
				var da = (bb-aa).cross(Vector2(a.p.x,a.p.y)-aa);var db = (bb-aa).cross(Vector2(b.p.x,b.p.y)-aa)
				if da>=-.0001: clipped.append(a)
				if (da>=-.0001)!=(db>=-.0001):
					var t = da/(da-db);clipped.append({"p":Vector3(a.p).lerp(b.p,t),"uv":Vector2(a.uv).lerp(b.uv,t)})
			poly = clipped
			if poly.is_empty(): break
		if poly.size()<3: continue
		var first = points.size()
		for p in poly: points.append(p.p);samples.append(p.uv)
		for j in range(1,poly.size()-1): triangles.append_array(PackedInt32Array([first,first+j,first+j+1]))
	var result = ArrayMesh.new();var arrays = [];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points;arrays[Mesh.ARRAY_TEX_UV] = samples;arrays[Mesh.ARRAY_INDEX] = triangles
	if not triangles.is_empty(): result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	heads[cache] = result;return result

func original_head(c,cosmetics,key: String,cut: String,t: Transform2D,tint: Color) -> void:
	var mesh = head_mesh(cosmetics,key,cut)
	if mesh==null or mesh.get_surface_count()==0: return
	c.draw_set_transform_matrix(t);c.draw_mesh(mesh,cosmetics.texture(cosmetics.frames[key].file),Transform2D.IDENTITY,tint)

func paint(c,cosmetics,kind: int,foot: Vector2,height: float,time: float,angle: float,wear: Array,tint: Color,seat: int,state: String,motion: float) -> void:
	kind = 1 if kind==1 else 0
	var id = "zombie_riders" if kind==0 else "skeleton_riders"
	var index = (0 if seat==0 else 4)+posmod(int(time*8),4)
	if state=="duck": index = 8 if motion>1.12 else 11 if motion<.28 else 9+posmod(int(time*7),2)
	var f = pose(cosmetics,kind,index);var source: Dictionary = cosmetics.frames[f.source_key]
	var root = Transform2D(angle,foot-Vector2(0,36).rotated(angle));root.x *= height/360;root.y *= height/360
	root.origin -= root.basis_xform(Vector2(f.anchor[0],f.anchor[1]))
	var head_root: Transform2D = root*f.head_transform
	var hats: Array = [];var faces: Array = [];var clothes: Array = []
	for value in wear:
		var entry = cosmetics.item(str(value))
		if entry.is_empty() or int(entry.kind)!=kind: continue
		if entry.slot=="head": hats.append(entry.id)
		elif entry.slot=="face": faces.append(entry.id)
		else: clothes.append(entry.id)
	for item in clothes:
		if cosmetics.item(item).fit in ["cape","scarf"]: cosmetics.draw_item(c,item,f,root,tint)
	c.draw_set_transform_matrix(root)
	# One complete drawn anatomy. No head, shoulder, or arm from a running pose.
	c.draw_texture_rect(Art.cell_texture(id if hats.is_empty() else id+"_body",index),Rect2(0,0,448,448),false,tint)
	if not hats.is_empty():
		var cut = str(cosmetics.graphics[hats[0]].get("source_mesh","hat" if cosmetics.item(hats[0]).fit=="hat" else "bare"))
		original_head(c,cosmetics,f.source_key,cut,head_root,tint)
	for item in clothes:
		if bool(cosmetics.graphics[item].get("native_cape",false)):
			c.draw_set_transform_matrix(root)
			var region = Rect2(0,f.landmarks.neck[1],maxf(1,f.landmarks.neck[0]-35),448-f.landmarks.neck[1])
			c.draw_texture_rect_region(Art.cell_texture(id,index),region,region,tint*Color(.32,.65,.60))
		else: cosmetics.draw_item(c,item,f,root,tint,cosmetics.item(item).fit=="cape" or bool(cosmetics.graphics[item].get("layered_neck",false)))
	for item in hats:
		var graphic: Dictionary = cosmetics.graphics[item]
		if not bool(graphic.get("behind_body",false)): cosmetics.draw_item(c,item,source,head_root,tint)
		if graphic.has("front_mesh") and bool(graphic.get("behind_body",false)): cosmetics.draw_item(c,item,source,head_root,tint,true)
	if not hats.is_empty() and index>=8:
		c.draw_set_transform_matrix(root);c.draw_texture_rect(Art.cell_texture(id+"_arms",index),Rect2(0,0,448,448),false,tint)
	for item in faces: cosmetics.draw_item(c,item,source,head_root,tint,bool(cosmetics.graphics[item].get("layered_eyes",false)))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

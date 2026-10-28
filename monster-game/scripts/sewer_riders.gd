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
	var head_scale = (144.0 if kind==0 else 126.0)/float(old.head_width)
	head.x *= head_scale;head.y *= head_scale
	head.origin = Vector2(measured.neck[0],measured.neck[1])-head.basis_xform(Vector2(old.landmarks.neck[0],old.landmarks.neck[1]))
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
	f.head_width = 144.0 if kind==0 else 126.0
	f.anchor = measured.hip;f.height = measured.height;f.rect = [(index%4)*384,int(index/4)*384,384,384]
	f.file = "v139/"+id+".webp";f.key = "rider_"+key;f.source_key = source_key;f.head_transform = head
	poses[key] = f;return f

func head_mesh(cosmetics,key: String,cut: String) -> ArrayMesh:
	var cache = key+":"+cut
	if heads.has(cache): return heads[cache]
	var f: Dictionary = cosmetics.frames[key]
	var w = float(f.head_width)
	var bounds = Rect2(float(f.box[0])-w*.48,0,float(f.box[2])-float(f.box[0])+w*.70,float(f.landmarks.neck[1])+w*.08)
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
		for side in range(4):
			var clipped: Array = []
			for j in range(poly.size()):
				var a: Dictionary = poly[j];var b: Dictionary = poly[(j+1)%poly.size()]
				var axis = 0 if side<2 else 1;var edge = bounds.position[axis] if side%2==0 else bounds.end[axis]
				var inside = float(a.p[axis])>=edge if side%2==0 else float(a.p[axis])<=edge
				var next_inside = float(b.p[axis])>=edge if side%2==0 else float(b.p[axis])<=edge
				if inside: clipped.append(a)
				if inside!=next_inside:
					var t = (edge-float(a.p[axis]))/(float(b.p[axis])-float(a.p[axis]))
					clipped.append({"p":Vector3(a.p).lerp(b.p,t),"uv":Vector2(a.uv).lerp(b.uv,t)})
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
	if not body_meshes.has(f.key): body_meshes[f.key] = cosmetics.read_mesh(Art.data()[id].poses[index].body_mesh,f.rect,Art.fresh(id).get_size())
	c.draw_mesh(body_meshes[f.key],Art.fresh(id),Transform2D.IDENTITY,tint)
	for item in clothes:
		if bool(cosmetics.graphics[item].get("native_cape",false)):
			c.draw_set_transform_matrix(root)
			c.draw_texture_rect_region(Art.fresh(id),Rect2(0,f.landmarks.neck[1],f.anchor[0]-25,384-f.landmarks.neck[1]),Rect2(f.rect[0],f.rect[1]+f.landmarks.neck[1],f.anchor[0]-25,384-f.landmarks.neck[1]),tint*Color(.32,.65,.60))
		else: cosmetics.draw_item(c,item,f,root,tint,cosmetics.item(item).fit=="cape" or bool(cosmetics.graphics[item].get("layered_neck",false)))
	for item in hats:
		if bool(cosmetics.graphics[item].get("behind_body",false)): cosmetics.draw_item(c,item,source,head_root,tint)
	var bare_face = hats.is_empty() and faces.any(func(item):return bool(cosmetics.graphics[item].get("expose_cranium",false)))
	var cut = "skull_base_v127" if bare_face else "whole"
	if not hats.is_empty() and not bool(cosmetics.graphics[hats[0]].get("preserve_source",false)):
		cut = str(cosmetics.graphics[hats[0]].get("source_mesh","hat" if cosmetics.item(hats[0]).fit=="hat" else "bare"))
	original_head(c,cosmetics,f.source_key,cut,head_root,tint)
	if bare_face: cosmetics.draw_skull(c,source,head_root,tint)
	for item in hats:
		var graphic: Dictionary = cosmetics.graphics[item]
		if bool(graphic.get("behind_body",false)):
			if graphic.has("front_mesh"): cosmetics.draw_item(c,item,source,head_root,tint,true)
			if item=="z_clown": original_head(c,cosmetics,f.source_key,"clown_details",head_root,tint)
			continue
		if bool(graphic.get("skull_underlay",false)): cosmetics.draw_skull(c,source,head_root,tint)
		cosmetics.draw_item(c,item,source,head_root,tint)
		if graphic.has("reveal_source"): original_head(c,cosmetics,f.source_key,str(graphic.reveal_source),head_root,tint)
		elif cosmetics.item(item).fit!="hat" and not bool(graphic.get("preserve_source",false)) and not graphic.has("registered_head"): original_head(c,cosmetics,f.source_key,"face",head_root,tint)
	cosmetics.draw_expressions(c,source,head_root,fposmod(time,1),time,tint)
	for item in faces:
		cosmetics.draw_item(c,item,source,head_root,tint,bool(cosmetics.graphics[item].get("layered_eyes",false)))
		if cosmetics.graphics[item].has("reveal_source"): original_head(c,cosmetics,f.source_key,str(cosmetics.graphics[item].reveal_source),head_root,tint)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

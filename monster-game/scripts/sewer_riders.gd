extends RefCounted
## Dedicated drawn sitting, passenger, duck and boarding animation cels.
const Art = preload("res://scripts/sewer_art.gd")
var poses: Dictionary = {}
var body_meshes: Dictionary = {}
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
	var old: Dictionary = cosmetics.frames["z_other_24" if kind==0 else "s_run_0"]
	var f = old.duplicate(true);var near = Vector2(measured.near[0],measured.near[1]);var far = Vector2(measured.far[0],measured.far[1])
	var old_near = Vector2(old.landmarks.near[0],old.landmarks.near[1]);var old_far = Vector2(old.landmarks.far[0],old.landmarks.far[1])
	var from = old_far-old_near;var to = far-near
	var head = Transform2D(to.angle()-from.angle(),Vector2.ZERO);head.x *= to.length()/from.length();head.y *= to.length()/from.length();head.origin = near-head.basis_xform(old_near)
	for name in f.landmarks:
		var p = head*Vector2(old.landmarks[name][0],old.landmarks[name][1]);f.landmarks[name] = [p.x,p.y]
	f.landmarks.neck = measured.neck;f.landmarks.hip = measured.hip
	var old_neck = Vector2(old.landmarks.neck[0],old.landmarks.neck[1]);var old_hip = Vector2(old.landmarks.hip[0],old.landmarks.hip[1])
	var new_neck = Vector2(measured.neck[0],measured.neck[1]);var new_hip = Vector2(measured.hip[0],measured.hip[1])
	var old_down = old_hip-old_neck;var new_down = new_hip-new_neck
	var body = Transform2D(Vector2(old_down.y,-old_down.x),old_down,old_neck)
	var target = Transform2D(Vector2(new_down.y,-new_down.x),new_down,new_neck)
	var fitted = target*body.affine_inverse()
	if f.has("items_v129"):
		for item in f.items_v129: f.items_v129[item] = map_mesh(old.items_v129[item],fitted if cosmetics.item(item).slot not in ["head","face"] else head)
	if f.has("body_v129"):
		for name in f.body_v129:
			var value = f.body_v129[name]
			if value is Array and value.size()==2:
				var point = fitted*Vector2(value[0],value[1]);f.body_v129[name] = [point.x,point.y]
	if f.has("front_v127"):
		for item in f.front_v127: f.front_v127[item] = map_mesh(old.front_v127[item],head if cosmetics.item(item).slot in ["head","face"] else fitted)
	var right = to.normalized();f.right = [right.x,right.y];f.down = [-right.y,right.x]
	f.head_width = float(old.head_width)*to.length()/from.length()
	var a = head*Vector2(old.box[0],old.box[1]);var b = head*Vector2(old.box[2],old.box[3]);f.box = [a.x,a.y,b.x,b.y]
	f.anchor = measured.hip;f.height = measured.height;f.rect = [(index%4)*384,int(index/4)*384,384,384];f.file = "v138/"+id+".webp";f.key = "rider_"+key
	f.source_key = "z_other_24" if kind==0 else "s_run_0";f.head_transform = head
	poses[key] = f;return f
func paint(c,cosmetics,kind: int,foot: Vector2,height: float,time: float,angle: float,wear: Array,tint: Color,seat: int,state: String,motion: float) -> void:
	kind = 1 if kind==1 else 0
	var id = "zombie_riders" if kind==0 else "skeleton_riders"
	var index = (0 if seat==0 else 4)+posmod(int(time*9),4)
	if state=="board": index = 12+clampi(int(motion*4),0,3)
	elif state=="duck": index = 8 if motion>1.12 else 11 if motion<.30 else 9+posmod(int(time*8),2)
	var f = pose(cosmetics,kind,index)
	var hip = foot-Vector2(0,36).rotated(angle)
	var root = Transform2D(angle,hip+Vector2(0,sin(time*14+seat)*.4));root.x *= height/360;root.y *= height/360
	root.origin -= root.basis_xform(Vector2(f.anchor[0],f.anchor[1]))
	var heads: Array = [];var faces: Array = [];var clothes: Array = []
	for value in wear:
		var entry = cosmetics.item(str(value))
		if entry.is_empty() or int(entry.kind)!=kind: continue
		if entry.slot=="head": heads.append(entry.id)
		elif entry.slot=="face": faces.append(entry.id)
		else: clothes.append(entry.id)
	for item in heads+clothes:
		var entry = cosmetics.item(item)
		if entry.fit in ["cape","scarf"] or bool(cosmetics.graphics[item].get("behind_body",false)): cosmetics.draw_item(c,item,f,root,tint)
	c.draw_set_transform_matrix(root)
	var bare = heads.any(func(item):return not bool(cosmetics.graphics[item].get("preserve_source",false))) or faces.any(func(item):return bool(cosmetics.graphics[item].get("expose_cranium",false)))
	if bare:
		var key = str(f.key)
		if not body_meshes.has(key): body_meshes[key] = cosmetics.read_mesh(Art.data()[id].poses[index].bare_mesh,f.rect,Art.fresh(id).get_size())
		c.draw_mesh(body_meshes[key],Art.fresh(id),Transform2D.IDENTITY,tint)
	else: c.draw_texture_rect_region(Art.fresh(id),Rect2(0,0,384,384),Rect2(f.rect[0],f.rect[1],384,384),tint)
	for item in clothes:
		if bool(cosmetics.graphics[item].get("native_cape",false)):
			var top = maxf(0,float(f.landmarks.near[1])-12);var width = maxf(10,float(f.anchor[0])-28)
			c.draw_set_transform_matrix(root)
			c.draw_texture_rect_region(Art.fresh(id),Rect2(0,top,width,maxf(10,float(f.anchor[1])+22-top)),Rect2(f.rect[0],f.rect[1]+top,width,maxf(10,float(f.anchor[1])+22-top)),tint*Color(.24,.32,.46))
		else: cosmetics.draw_item(c,item,f,root,tint,cosmetics.item(item).fit=="cape" or bool(cosmetics.graphics[item].get("layered_neck",false)))
	for item in heads:
		var graphic: Dictionary = cosmetics.graphics[item]
		if bool(graphic.get("behind_body",false)):
			if graphic.has("front_mesh"): cosmetics.draw_item(c,item,f,root,tint,true)
			if item=="z_clown": cosmetics.draw_source(c,f.source_key,"clown_details",root*f.head_transform,tint)
			continue
		if bool(cosmetics.graphics[item].get("skull_underlay",false)): cosmetics.draw_skull(c,f,root,tint)
		cosmetics.draw_item(c,item,f,root,tint)
		if graphic.has("reveal_source"): cosmetics.draw_source(c,f.source_key,str(graphic.reveal_source),root*f.head_transform,tint)
		elif cosmetics.item(item).fit!="hat" and not bool(graphic.get("preserve_source",false)) and not graphic.has("registered_head"): cosmetics.draw_source(c,f.source_key,"face",root*f.head_transform,tint)
	for item in faces:
		if bool(cosmetics.graphics[item].get("expose_cranium",false)) and heads.is_empty(): cosmetics.draw_skull(c,f,root,tint)
		cosmetics.draw_item(c,item,f,root,tint,bool(cosmetics.graphics[item].get("layered_eyes",false)))
		if cosmetics.graphics[item].has("reveal_source"): cosmetics.draw_source(c,f.source_key,str(cosmetics.graphics[item].reveal_source),root*f.head_transform,tint)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

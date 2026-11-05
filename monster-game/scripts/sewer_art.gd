extends RefCounted
## Shared native texture cache; new civilians have actual drawn animation cels.
static var textures: Dictionary = {}
static var images: Dictionary = {}
static var layout: Dictionary = {}
static var newer: Dictionary = {}
static var latest: Dictionary = {}

static func data() -> Dictionary:
	if layout.is_empty():
		layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/v138/layout.json"))
		newer = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/v139/layout.json"))
		layout.merge(newer,true)
		latest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/v140/layout.json"))
		layout.merge(latest,true)
	return layout

static func image_for(id: String) -> Image:
	data()
	if not images.has(id):
		var base_id = id.trim_suffix("_body").trim_suffix("_arms")
		var family = "v140" if latest.has(base_id) else "v139" if newer.has(id) else "v138"
		var im = Image.new()
		assert(im.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/"+family+"/"+id+".webp"))==OK)
		images[id] = im
	return images[id]

static func fresh(id: String) -> Texture2D:
	var key = "atlas:"+id
	if not textures.has(key): textures[key] = ImageTexture.create_from_image(image_for(id))
	return textures[key]

static func cell_texture(id: String,index: int) -> Texture2D:
	var key = "cel:"+id+":"+str(index)
	if not textures.has(key):
		var base_id = id.trim_suffix("_body").trim_suffix("_arms")
		var spec: Dictionary = data()[base_id];var cell = Vector2i(spec.cell[0],spec.cell[1]);var columns = int(spec.columns)
		var source = image_for(id).get_region(Rect2i(Vector2i(index%columns,int(index/columns))*cell,cell))
		if base_id=="flood": source = source.get_region(Rect2i(0,0,320,432))
		textures[key] = ImageTexture.create_from_image(source)
	return textures[key]

static func cel(c,id: String,index: int,rect: Rect2,tint: Color = Color.WHITE) -> void:
	c.draw_texture_rect(cell_texture(id,index),rect,false,tint)

static func new_prop(c,id: String,at: Vector2,width: float,angle: float = 0.0,tint: Color = Color.WHITE) -> void:
	var tex = fresh(id);var size = tex.get_size()*width/tex.get_width()
	c.draw_set_transform(at,angle);c.draw_texture_rect(tex,Rect2(-size*.5,size),false,tint);c.draw_set_transform(Vector2.ZERO)

static func boat(c,p: Vector2,height: float,angle: float = 0,tint: Color = Color.WHITE,front: bool = false) -> void:
	var key = "solo_jetski_v149"
	if not textures.has(key):
		var image = Image.new()
		assert(image.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/v149/jetski_solo.webp"))==OK)
		textures[key] = ImageTexture.create_from_image(image)
	var tex: Texture2D = textures[key];var size = tex.get_size()*height/tex.get_height()
	c.draw_set_transform(p,angle)
	if front:
		var v = .68
		c.draw_texture_rect_region(tex,Rect2(Vector2(-size.x*.5,-size.y*.5+size.y*v),Vector2(size.x,size.y*(1-v))),Rect2(0,tex.get_height()*v,tex.get_width(),tex.get_height()*(1-v)),tint)
	else: c.draw_texture_rect(tex,Rect2(-size*.5,size),false,tint)
	c.draw_set_transform(Vector2.ZERO)

static func immersed(c, tex: Texture2D, surface: Vector2, size: Vector2, region: Rect2, immersion: float, angle: float = 0.0, tint: Color = Color.WHITE, dry: float = 0.0) -> void:
	# Rotate about the contact line. Underwater pixels soften into the painted surface.
	var above = 1.0 - immersion
	var left = -size.x * 0.5
	var submerged = size.y * immersion
	var cut = region.position.y + region.size.y * above
	c.draw_set_transform(surface, angle)
	c.draw_texture_rect_region(tex, Rect2(left, -size.y*above, size.x, size.y*above),
		Rect2(region.position, Vector2(region.size.x, region.size.y*above)), tint)
	var corners = PackedVector2Array([Vector2(left,0), Vector2(-left,0), Vector2(-left,submerged), Vector2(left,submerged)])
	var tex_size = tex.get_size()
	var uv = PackedVector2Array([Vector2(region.position.x,cut)/tex_size, Vector2(region.end.x,cut)/tex_size,
		region.end/tex_size, Vector2(region.position.x,region.end.y)/tex_size])
	var near = tint * Color(0.53,0.76,0.74,0.76).lerp(Color.WHITE,dry)
	var deep = tint * Color(0.20,0.48,0.51,0.12).lerp(Color.WHITE,dry)
	c.draw_polygon(corners, PackedColorArray([near,near,deep,deep]), uv, tex)
	c.draw_set_transform(Vector2.ZERO)

static func survivor_new(c,variant: int,p: Vector2,height: float,time: float,tint: Color = Color.WHITE,dry: float = 0.0) -> void:
	var index = posmod(int(time*7),4)+posmod(variant,3)*4
	var tex = cell_texture("survivors",index)
	var line = (float(data().survivor_anchors[index].waterline) - 26.0 + sin(time*4.1+variant)*8.0) / 320.0
	immersed(c,tex,p,Vector2.ONE*height,Rect2(Vector2.ZERO,tex.get_size()),1.0-line,sin(time*2.9+variant)*0.052,tint,dry)

static func fugitive(c,variant: int,p: Vector2,height: float,time: float,tint: Color = Color.WHITE) -> void:
	var index = posmod(variant,3)*4+posmod(int(time*8),4)
	var spec: Dictionary = data().fugitives
	var box: Array = spec.bounds[index];var scale = height*2.05/512.0
	var tex = cell_texture("fugitives",index)
	var size = Vector2(512,384)*scale
	immersed(c,tex,p,size,Rect2(Vector2.ZERO,tex.get_size()),1.0-(float(box[3])-18.0)/384.0,sin(time*4)*.018,tint)

static func captive(c,variant: int,p: Vector2,height: float,progress: float,tint: Color = Color.WHITE) -> void:
	var index = posmod(variant,2)*4+clampi(int(progress*4),0,3)
	var tex = cell_texture("captives",index)
	c.draw_set_transform(p,sin(progress*TAU)*.24)
	c.draw_texture_rect(tex,Rect2(-height*.5,-height*.5,height,height),false,tint)
	c.draw_set_transform(Vector2.ZERO)

static func flipping_boat(c,p: Vector2,progress: float) -> void:
	var tex = fresh("civil_boat");var size = tex.get_size()*225/tex.get_width()
	c.draw_set_transform(p,-progress*PI*1.6)
	c.draw_texture_rect(tex,Rect2(-size*.5,size),false,Color(1,1,1,1-smoothstep(.65,1,progress)))
	c.draw_set_transform(Vector2.ZERO)

static func runner_new(c,variant: int,foot: Vector2,height: float,time: float,tint: Color = Color.WHITE,angle: float = 0) -> void:
	var id = "runner_woman" if variant==0 else "runner_worker"
	var spec: Dictionary = data()[id];var index = posmod(int(time*13),8)
	var size = Vector2(256.0/342*height,height);var anchor_y = float(spec.feet[index])/342*height
	c.draw_set_transform(foot,angle)
	cel(c,id,index,Rect2(-size.x*.5,-anchor_y,size.x,size.y),tint)
	c.draw_set_transform(Vector2.ZERO)

static func flood_new(c,point: Vector2,height: float,time: float,opacity: float = 1.0) -> void:
	# Each frame is a standalone GPU texture: no atlas neighbor can leak or repeat.
	var index = posmod(int(time*9),16)
	var width = height*.65;var base = point-Vector2(width,height)
	var tex = cell_texture("flood",index)
	var uv = PackedVector2Array([Vector2(0,1),Vector2(0,0)])
	var points = PackedVector2Array([base+Vector2(0,height),base])
	for row in range(33):
		var v = float(row)/32;var flow = (sin(v*15+time*5)*4+sin(v*27-time*7)*2)*sin(v*PI)*minf(1,height/120.0)
		points.append(base+Vector2(width+flow,v*height));uv.append(Vector2(.999,v))
	c.draw_polygon(points,PackedColorArray([Color(1,1,1,opacity)]),uv,tex)

static func texture(id: String) -> Texture2D:
	if not textures.has(id):
		var image = Image.new()
		assert(image.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/v137/"+id+".webp"))==OK)
		textures[id] = ImageTexture.create_from_image(image)
	return textures[id]

static func prop(c,id: String,p: Vector2,height: float,angle: float = 0,tint: Color = Color.WHITE) -> void:
	var tex = texture(id);var size = tex.get_size()*height/tex.get_height()
	c.draw_set_transform(p,angle)
	c.draw_texture_rect(tex,Rect2(-size*.5,size),false,tint)
	c.draw_set_transform(Vector2.ZERO)

static func survivor(c,variant: int,p: Vector2,height: float,time: float,tint: Color = Color.WHITE) -> void:
	var index = [0,1,2,1][posmod(int(time*4.5),4)]
	var cell = Vector2(320,320);var source = Rect2(Vector2(index,posmod(variant,3))*cell,cell)
	var bob = sin(time*4.4+variant)*height*.025
	c.draw_set_transform(p+Vector2(0,bob),sin(time*2.3+variant)*.025)
	c.draw_texture_rect_region(texture("survivors"),Rect2(Vector2(-height*.5,-height*.65),Vector2.ONE*height),source,tint)
	c.draw_set_transform(Vector2.ZERO)

static func runner(c,variant: int,foot: Vector2,height: float,time: float,tint: Color = Color.WHITE) -> void:
	var cell = Vector2(256,342);var index = posmod(int(time*10),4)
	var source = Rect2(Vector2(index,posmod(variant,3))*cell,cell)
	var size = Vector2(cell.x/cell.y*height,height)
	c.draw_texture_rect_region(texture("runners"),Rect2(foot-Vector2(size.x*.5,height*.96),size),source,tint)

static func crest(c,point: Vector2,height: float,time: float,tint: Color = Color.WHITE) -> void:
	var frame = fposmod(time*7.5,8);var first = floori(frame);var blend = smoothstep(0,1,frame-first)
	var cell = Vector2(320,426);var size = Vector2(cell.x/cell.y*height,height)
	for i in range(2):
		var index = posmod(first+i,8);var source = Rect2(Vector2(index%4,int(index/4))*cell,cell)
		var alpha = 1-blend if i==0 else blend
		c.draw_texture_rect_region(texture("wave"),Rect2(point-Vector2(size.x*.90,height*.86),size),source,Color(tint,tint.a*alpha))

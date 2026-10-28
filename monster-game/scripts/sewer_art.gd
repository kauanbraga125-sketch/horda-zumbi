extends RefCounted
## Shared native texture cache; new civilians have actual drawn animation cels.
static var textures: Dictionary = {}
static var layout: Dictionary = {}
static var newer: Dictionary = {}

static func data() -> Dictionary:
	if layout.is_empty():
		layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/v138/layout.json"))
		newer = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/v139/layout.json"))
		layout.merge(newer,true)
	return layout

static func fresh(id: String) -> Texture2D:
	data()
	var family = "v139" if newer.has(id) else "v138"
	var key = family+"/"+id
	if not textures.has(key):
		var im = Image.new()
		assert(im.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/"+family+"/"+id+".webp"))==OK)
		textures[key] = ImageTexture.create_from_image(im)
	return textures[key]

static func cel(c,id: String,index: int,rect: Rect2,tint: Color = Color.WHITE) -> void:
	var spec: Dictionary = data()[id];var cell = Vector2(spec.cell[0],spec.cell[1]);var col = int(spec.columns)
	c.draw_texture_rect_region(fresh(id),rect,Rect2(Vector2(index%col,int(index/col))*cell,cell),tint)

static func boat(c,p: Vector2,height: float,angle: float = 0,tint: Color = Color.WHITE,front: bool = false) -> void:
	var tex = fresh("jetski");var size = tex.get_size()*height/tex.get_height()
	c.draw_set_transform(p,angle)
	if front:
		var v = .78
		c.draw_texture_rect_region(tex,Rect2(Vector2(-size.x*.5,-size.y*.5+size.y*v),Vector2(size.x,size.y*(1-v))),Rect2(0,tex.get_height()*v,tex.get_width(),tex.get_height()*(1-v)),tint)
	else: c.draw_texture_rect(tex,Rect2(-size*.5,size),false,tint)
	c.draw_set_transform(Vector2.ZERO)

static func survivor_new(c,variant: int,p: Vector2,height: float,time: float,tint: Color = Color.WHITE) -> void:
	var index = posmod(int(time*7),4)+posmod(variant,3)*4
	var line = float(data().survivor_anchors[index].waterline)/320*height
	c.draw_set_transform(p+Vector2(0,sin(time*5.3+variant)*.7),sin(time*2.9+variant)*.015)
	cel(c,"survivors",index,Rect2(-height*.5,-line,height,height),tint)
	c.draw_set_transform(Vector2.ZERO)

static func fugitive(c,variant: int,p: Vector2,height: float,time: float,tint: Color = Color.WHITE) -> void:
	var index = posmod(variant,3)*4+posmod(int(time*8),4)
	var spec: Dictionary = data().fugitives
	var box: Array = spec.bounds[index];var scale = height*2.05/512.0
	var size = Vector2(512,384)*scale;var waterline = (float(box[3])-10)*scale
	c.draw_set_transform(p,sin(time*4)*.018)
	cel(c,"fugitives",index,Rect2(-size.x*.5,-waterline,size.x,size.y),tint)
	c.draw_set_transform(Vector2.ZERO)

static func runner_new(c,variant: int,foot: Vector2,height: float,time: float,tint: Color = Color.WHITE,angle: float = 0) -> void:
	var id = "runner_woman" if variant==0 else "runner_worker"
	var spec: Dictionary = data()[id];var index = posmod(int(time*13),8)
	var size = Vector2(256.0/342*height,height);var anchor_y = float(spec.feet[index])/342*height
	c.draw_set_transform(foot,angle)
	cel(c,id,index,Rect2(-size.x*.5,-anchor_y,size.x,size.y),tint)
	c.draw_set_transform(Vector2.ZERO)

static func flood_new(c,point: Vector2,height: float,time: float) -> void:
	var frame = fposmod(time*7.5,16);var index = floori(frame);var blend = frame-index
	var width = height*.57;var origin = point-Vector2(width,height)
	for i in range(2):
		var which = posmod(index+i,16);var uv_origin = Vector2(which%4,int(which/4))*.25
		var points = PackedVector2Array([origin+Vector2(0,height),origin]);var uv = PackedVector2Array([uv_origin+Vector2(0,.25),uv_origin])
		for row in range(33):
			var v = float(row)/32;var flow = sin(v*15+time*5)*5+sin(v*27-time*7)*3
			points.append(origin+Vector2(width+flow,v*height));uv.append(uv_origin+Vector2(.25,v*.25))
		c.draw_polygon(points,PackedColorArray([Color(1,1,1,1 if i==0 else blend)]),uv,fresh("flood"))

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

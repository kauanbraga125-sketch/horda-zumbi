extends RefCounted
## Shared native texture cache; new civilians have actual drawn animation cels.
static var textures: Dictionary = {}

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

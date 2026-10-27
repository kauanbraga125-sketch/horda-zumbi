extends RefCounted
const Catalog = preload("res://scripts/bird_catalog.gd")
static var textures: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if not textures.has(id):
		var im = Image.new()
		assert(im.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/v136/"+id+".webp"))==OK)
		textures[id] = ImageTexture.create_from_image(im)
	return textures[id]

static func prop(c,id: String,point: Vector2,height: float,angle: float = 0,tint: Color = Color.WHITE) -> void:
	var tex = texture(id);var size = tex.get_size()*height/tex.get_height()
	c.draw_set_transform(point,angle)
	c.draw_texture_rect(tex,Rect2(-size*.5,size),false,tint)
	c.draw_set_transform(Vector2.ZERO)

static func frame(index: int,time: float,emotion: String = "") -> int:
	if emotion=="ability": return 5
	if emotion=="hurt": return 4
	if fposmod(time+index*.73,6.5)>.6 and fposmod(time+index*.73,6.5)<.82: return 3
	return [0,1,2,1][posmod(int(time*([7.5,6.0,9.0,5.5,9.5][clampi(index,0,4)])),4)]

static func paint(c,id: String,point: Vector2,height: float,time: float,emotion: String = "",tint: Color = Color.WHITE) -> void:
	var index = Catalog.tier(id)
	if index<0: return
	var f = frame(index,time,emotion)
	var source = Rect2((f%3)*384,int(f/3)*384,384,384)
	var bob = sin(time*(3.3 if index==4 else 4.7)+index)*height*.024
	var angle = sin(time*2.1+index)*.035
	var stretch = Vector2.ONE
	if index==4: stretch = Vector2(1+sin(time*5)*.014,1-sin(time*5)*.014)
	if emotion=="ability": stretch *= 1+sin(clampf(time,0,1)*PI)*.06
	c.draw_set_transform(point+Vector2(0,bob),angle,stretch)
	c.draw_texture_rect_region(texture(id),Rect2(Vector2.ONE*-height*.5,Vector2.ONE*height),source,tint)
	c.draw_set_transform(Vector2.ZERO)

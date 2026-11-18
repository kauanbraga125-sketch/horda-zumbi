extends RefCounted

const IDLE_ATLAS = "res://assets/art/v180/barao_idle.webp"
const ACTION_ATLAS = "res://assets/art/v180/barao_spells.webp"
const MAGIC_ATLAS = "res://assets/art/v180/barao_gold_burst.webp"
const CELL = 384.0
const PADDED_SCALE = 544.0/384.0
static var textures: Dictionary = {}

static func texture(path: String) -> Texture2D:
	if not textures.has(path):
		var image = Image.new()
		var error = image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path))
		assert(error==OK,"Could not load Barão's full sprite atlas")
		textures[path] = ImageTexture.create_from_image(image)
	return textures[path]

static func warm() -> void:
	for atlas in [IDLE_ATLAS,ACTION_ATLAS,MAGIC_ATLAS]:
		texture(atlas)

static func medallion(height: float) -> Vector2:
	return Vector2(.22,-.025)*height

static func paint_idle(c,point: Vector2,height: float,time: float,emotion: String = "",tint: Color = Color.WHITE) -> void:
	var frame = [0,1,2,1][posmod(int(time*9.5),4)]
	var blink = fposmod(time+4*.73,6.5)
	if blink>.6 and blink<.82:frame = 3
	if emotion=="ability":frame = 5
	elif emotion=="hurt":frame = 4
	var bob = sin(time*3.3+4)*height*.024
	var angle = sin(time*2.1+4)*.035
	var size = Vector2.ONE*height*PADDED_SCALE
	c.draw_set_transform(point+Vector2(0,bob),angle)
	c.draw_texture_rect_region(texture(IDLE_ATLAS),Rect2(-size*.5,size),
		Rect2((frame%3)*CELL,floori(frame/3.0)*CELL,CELL,CELL),tint)
	c.draw_set_transform(Vector2.ZERO)

static func paint_action(c,point: Vector2,height: float,frame: int,tint: Color = Color.WHITE) -> void:
	var size = Vector2.ONE*height*PADDED_SCALE
	c.draw_texture_rect_region(texture(ACTION_ATLAS),Rect2(point-size*.5,size),
		Rect2((frame%4)*CELL,floori(frame/4.0)*CELL,CELL,CELL),tint)

static func paint_magic(c,point: Vector2,size: float,progress: float,tint: Color = Color.WHITE) -> void:
	if progress<0 or progress>=1:
		return
	var frame = mini(7,int(progress*8))
	var height = Vector2.ONE*size
	c.draw_texture_rect_region(texture(MAGIC_ATLAS),Rect2(point-height*.5,height),
		Rect2((frame%4)*CELL,floori(frame/4.0)*CELL,CELL,CELL),tint)

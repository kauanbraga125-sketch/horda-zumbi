extends RefCounted

const ATLAS = "res://assets/art/v180/barao_rig.webp"
const TILE = Vector2(256,256)
const BODY = Rect2(Vector2.ZERO,TILE)
const WING = Rect2(Vector2(256,0),TILE)
const WING_PIVOT = Vector2(.80,.69)
static var rig: Texture2D

static func texture() -> Texture2D:
	if rig==null:
		var image = Image.new()
		var error = image.load_webp_from_buffer(FileAccess.get_file_as_bytes(ATLAS))
		assert(error==OK,"Could not load Barão's sprite atlas")
		rig = ImageTexture.create_from_image(image)
	return rig

static func medallion(height: float) -> Vector2:
	return Vector2(.215,-.055)*height

static func paint(c,point: Vector2,height: float,time: float,roll: float = 0.0,wing_lift: float = 0.0,squash: float = 0.0,tint: Color = Color.WHITE) -> void:
	var center = point+Vector2(0,sin(time*3.6)*height*.024)
	var stretch = Vector2(1-squash*.66,1+squash*.61)
	var flap = sin(time*TAU*2.25)
	var pitch = clampf(.34+flap*.68+wing_lift,-.57,1.19)
	var span = (1-.20*absf(flap))*(1.0-.22*maxf(0,-wing_lift))
	var far_pivot = center+(Vector2(.22,-.10)*height*stretch).rotated(roll)
	var near_pivot = center+(Vector2(-.15,-.045)*height*stretch).rotated(roll)
	paint_wing(c,far_pivot,height*.65,roll-pitch*.87,Vector2(-span,1)*stretch,tint*Color(.78,.72,.87))
	c.draw_set_transform(center,roll,stretch)
	var body_size = Vector2.ONE*height
	c.draw_texture_rect_region(texture(),Rect2(-body_size*.5,body_size),BODY,tint)
	paint_wing(c,near_pivot,height*.86,roll+pitch,Vector2(span,1)*stretch,tint)
	c.draw_set_transform(Vector2.ZERO)

static func paint_wing(c,point: Vector2,height: float,angle: float,stretch: Vector2,tint: Color) -> void:
	var size = Vector2.ONE*height
	c.draw_set_transform(point,angle,stretch)
	c.draw_texture_rect_region(texture(),Rect2(-size*WING_PIVOT,size),WING,tint)

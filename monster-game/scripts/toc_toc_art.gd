extends RefCounted

const FLIGHT = "res://assets/art/toc_toc/flight.webp"
const PECK = "res://assets/art/toc_toc/peck.webp"
const REACTION = "res://assets/art/toc_toc/reaction.webp"
const CELL = 192
const FPS = 24.0
const FLIGHT_FRAMES = 12
const BLINK = [0,1,2,3,12,13,14,15,8,9,10,11]
const MISS = [0,1,2,3,4,3,4,3,5,6,7]
const TIP_AT_CONTACT = Vector2(478,232.33)
const SIZE = 134.0
static var textures: Dictionary = {}

static func texture(path: String) -> Texture2D:
	if not textures.has(path):
		var image = Image.new()
		var error = image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path))
		assert(error==OK,"Could not load Toc-Toc's sprite atlas: "+path)
		textures[path] = ImageTexture.create_from_image(image)
	return textures[path]

static func warm() -> void:
	for path in [FLIGHT,PECK,REACTION]:
		texture(path)

static func flight_frame(time: float) -> int:
	var flap = floori(time*FPS)
	var cycle = flap/FLIGHT_FRAMES
	var frame = posmod(flap,FLIGHT_FRAMES)
	# Swap one full wingbeat for the drawn blink, keeping the wing phase.
	if posmod(cycle,12) in [5,11]:return BLINK[frame]
	return frame

static func flight_bob(time: float) -> float:
	return sin(time*5.6)*3.5

static func flight_bank(time: float) -> float:
	return sin(time*3.1)*.04

static func peck_tip(bank: float) -> Vector2:
	return ((TIP_AT_CONTACT-Vector2(256,256))*(SIZE/512.0)).rotated(bank)

static func flinch(entity: Dictionary,elapsed: float) -> float:
	var seconds = elapsed-float(entity.get("toc_toc_hit_at",-1.0))
	return sin(seconds*72)*.13*(1-smoothstep(0,.24,seconds)) if seconds<.24 else 0.0

static func paint(c,atlas: String,frame: int,point: Vector2,size: float,bank: float = 0,tint: Color = Color.WHITE) -> void:
	var source = Rect2((frame%4)*CELL,floori(frame/4.0)*CELL,CELL,CELL)
	c.draw_set_transform(point,bank)
	c.draw_texture_rect_region(texture(atlas),Rect2(Vector2.ONE*-size*.5,Vector2.ONE*size),source,tint)
	c.draw_set_transform(Vector2.ZERO)

static func paint_flight(c,point: Vector2,size: float,time: float,tint: Color = Color.WHITE) -> void:
	paint(c,FLIGHT,flight_frame(time),point+Vector2(0,flight_bob(time)),size,flight_bank(time),tint)

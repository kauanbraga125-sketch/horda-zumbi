extends RefCounted

const FLIGHT = "res://assets/art/fuba/flight.webp"
const POWER = "res://assets/art/fuba/power.webp"
const SHELL = "res://assets/art/fuba/shell.webp"
const MOTION = "res://assets/art/fuba/flight_motion.json"
const CELL = 192
const REFERENCE_SIZE = 512.0
const SIZE = 70.0
const PIVOT = Vector2(272,192)
const CAP = Vector2(-26,-82)
const CAP_WIDTH = 246.0
const GAG_SECONDS = 2.7
const FLAP_SECONDS = .46
const POWER_CAP = [
	Vector3(-25,-98,0), Vector3(-34,-75,0), Vector3(-27,-83,0),
	Vector3(-30,-100,.09), Vector3(-61,-96,.31), Vector3(-34,-78,0),
	Vector3(-26,-77,0), Vector3(-31,-78,0), Vector3(-28,-91,0),
]
static var atlases: Dictionary = {}
static var motion: Array = []

static func texture(path: String) -> Texture2D:
	if not atlases.has(path):
		var image = Image.new()
		var error = image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path))
		assert(error==OK,"Could not load Fubá's sprite: "+path)
		atlases[path] = ImageTexture.create_from_image(image)
	return atlases[path]

static func warm() -> void:
	for path in [FLIGHT,POWER,SHELL]:
		texture(path)
	if motion.is_empty():
		motion = JSON.parse_string(FileAccess.get_file_as_string(MOTION))

static func eye(point: Vector2,time: float) -> Vector2:
	return point+Vector2(sin(time*2.9)*3,-6+sin(time*TAU/FLAP_SECONDS)*2.1)

static func lean(time: float) -> float:
	return sin(time*5.8)*.095

static func flight_frame(time: float) -> int:
	var beat = floori(time/FLAP_SECONDS)
	var phase = floori(fposmod(time,FLAP_SECONDS)*4/FLAP_SECONDS)
	if phase==1 and beat%6==1:return 4
	if phase==0 and beat%3==2:return 5
	return mini(phase,3)

static func paint_pose(c,atlas: String,frame: int,head: Vector2,size: float,bank: float,face: float,tint: Color) -> void:
	var source = Rect2((frame%3)*CELL,floori(frame/3.0)*CELL,CELL,CELL)
	c.draw_set_transform(head,bank,Vector2(face,1))
	c.draw_texture_rect_region(texture(atlas),Rect2(-PIVOT*(size/REFERENCE_SIZE),Vector2.ONE*size),source,tint)
	c.draw_set_transform(Vector2.ZERO)

static func paint_shell(c,center: Vector2,size: float,bank: float,face: float,tint: Color) -> void:
	var tex = texture(SHELL)
	var extent = tex.get_size()*(CAP_WIDTH*size/REFERENCE_SIZE/tex.get_width())
	c.draw_set_transform(center,bank,Vector2(face,1))
	c.draw_texture_rect(tex,Rect2(-extent*.5,extent),false,tint)
	c.draw_set_transform(Vector2.ZERO)

static func paint_power(c,frame: int,head: Vector2,bank: float = 0,face: float = 1) -> void:
	var socket: Vector3 = POWER_CAP[frame]
	var shell_pos = head+(Vector2(socket.x*face,socket.y)*(SIZE/REFERENCE_SIZE)).rotated(bank)
	paint_pose(c,POWER,frame,head,SIZE,bank,face,Color.WHITE)
	paint_shell(c,shell_pos,SIZE,bank+socket.z*face,face,Color.WHITE)

static func paint_flight(c,point: Vector2,size: float,time: float,tint: Color = Color.WHITE) -> void:
	var head = eye(point,time)
	var bank = lean(time)
	paint_pose(c,FLIGHT,flight_frame(time),head,size,bank,1,tint)
	paint_shell(c,head+(CAP*(size/REFERENCE_SIZE)).rotated(bank),size,bank+sin(time*18)*.03,1,tint)

static func paint_gag(c,point: Vector2,time: float,age: float) -> void:
	if motion.is_empty():warm()
	var f: Array = motion[clampi(floori(age*60),0,motion.size()-1)]
	var blend = smoothstep(0,.14,age)*(1-smoothstep(GAG_SECONDS-.2,GAG_SECONDS,age))
	var head = eye(point,time)
	var bank = lean(time)
	var ratio = SIZE/REFERENCE_SIZE
	var shell_pos = head+(CAP*ratio).rotated(bank)
	var base = point-Vector2(0,6)
	paint_pose(c,FLIGHT,int(f[0]),head.lerp(base+Vector2(f[1],f[2])*ratio,blend),SIZE,
		lerpf(bank,deg_to_rad(f[3]),blend),1,Color.WHITE)
	paint_shell(c,shell_pos.lerp(base+Vector2(f[4],f[5])*ratio,blend),SIZE,lerpf(bank,deg_to_rad(f[6]),blend),1,Color.WHITE)

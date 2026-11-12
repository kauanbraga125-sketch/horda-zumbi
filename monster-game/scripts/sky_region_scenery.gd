extends RefCounted

const ROOT = "res://assets/art/v165/"
const Deep = preload("res://scripts/sky_deep_landscape.gd")
const ELDER = Vector2(1260,-2740)
const DRAGON = Vector2(1260,-3700)
const WITCH = Vector2(1260,-4350)
const FIREFLIES = Vector2(1160,-3450)
const ELDER_SCALE = 420.0
const PLATES = {
	"sanctuary":Rect2(-620,-3970,2550,1700),
	"storm":Rect2(-600,-5500,2700,1800),
	"graveyard":Rect2(-600,-7350,3450,2300),
	"graveyard_high":Rect2(-650,-9350,3600,2400)
}
static var textures: Dictionary = {}

static func texture(name: String) -> Texture2D:
	var key = "graveyard" if name=="graveyard_high" else name
	if not textures.has(key):
		var image = Image.load_from_file(ROOT+key+".webp")
		assert(image!=null and not image.is_empty())
		textures[key] = ImageTexture.create_from_image(image)
	return textures[key]

static func position(kind: String, view: Rect2, camera: Vector2, time: float) -> Vector2:
	match kind:
		"elder": return Deep.project(ELDER,view,camera,.016)
		"dragon": return Deep.project(DRAGON-Vector2(time*8.0,0),view,camera,.020)+Vector2(0,sin(time*1.6)*10.0)
		"witch": return Deep.project(WITCH-Vector2(time*9.0,0),view,camera,.023)+Vector2(0,sin(time*2.1)*8.0)
		"fireflies": return Deep.project(FIREFLIES-Vector2(time*4.0,0),view,camera,.024)
	return Vector2.ZERO

static func paint_plate(canvas: Node2D, name: String, view: Rect2, camera: Vector2, depth: float, tint: Color) -> void:
	var plane: Rect2 = PLATES[name]
	var rect = Rect2(Deep.project(plane.position,view,camera,depth),plane.size)
	if rect.intersects(view): Deep.faded_plate(canvas,texture(name),rect,tint)

static func paint_air(canvas: Node2D, motion, view: Rect2, camera: Vector2, time: float, alpha: float) -> void:
	paint_plate(canvas,"sanctuary",view,camera,.008,Color(.57,.58,.78,alpha*.70))
	paint_plate(canvas,"storm",view,camera,.011,Color(.53,.57,.75,alpha*.77))
	# Remote altar lights are fixed in the valley, behind the interactive actors.
	for i in range(7):
		var anchor = Vector2(750+i*67,-2660+sin(i*2.3)*98)
		var point = Deep.project(anchor,view,camera,.016)
		if view.has_point(point):
			motion.halo(canvas,point,4.0,Color("a5d5e2"),alpha*(.11+.07*sin(time*.7+i)))

static func paint_elder_front(canvas: Node2D, motion, point: Vector2, time: float, alpha: float) -> void:
	motion.sprite(canvas,"mist_far",point+Vector2(-30+sin(time*.12)*12,140),520.0,Color(.56,.61,.81,alpha*.37))
	motion.sprite(canvas,"mist_front",point+Vector2(45,174),360.0,Color(.55,.60,.79,alpha*.24))
	for i in range(5):
		var mote = point+Vector2(cos(time*.19+i*1.7)*190,110+sin(time*.23+i)*36)
		canvas.draw_circle(mote,1.3,Color(.65,.81,.91,alpha*.32),true,-1,true)

static func paint_flight_wake(canvas: Node2D, motion, point: Vector2, time: float, witch: bool, alpha: float) -> void:
	var colour = Color(.59,.62,.84,alpha*.17)
	for i in range(3):
		var start = point+Vector2(23.0+i*11.0,4.0+i*6.0)
		var curve = PackedVector2Array()
		for j in range(6):curve.append(start+Vector2(j*18.0,sin(time*.7+j*.6+i)*4.0))
		canvas.draw_polyline(curve,colour,1.0,true)
	if witch:motion.sprite(canvas,"mist_far",point+Vector2(58,10),118.0,Color(.64,.55,.81,alpha*.16))

static func paint_orbit(canvas: Node2D, motion, view: Rect2, camera: Vector2, time: float, alpha: float) -> void:
	paint_plate(canvas,"graveyard",view,camera,.009,Color(.69,.52,.62,alpha*.77))
	paint_plate(canvas,"graveyard_high",view,camera,.006,Color(.62,.46,.59,alpha*.69))
	for i in range(18):
		var anchor = Vector2(620+(i%6)*164,-5370-(i/6)*1120-sin(i*4.0)*180)
		var point = Deep.project(anchor,view,camera,.014)
		if not view.grow(30).has_point(point):continue
		motion.sprite(canvas,"meteor_shards",point,7.0+float(i%4)*3.0,Color(.58,.44,.55,alpha*.30),i*.71+time*.015)

static func veil_orbit(canvas: Node2D, motion, point: Vector2, alpha: float, kind: String) -> void:
	var offset = Vector2(-40,52) if kind=="leviathan" else Vector2(50,49)
	var width = 560.0 if kind=="leviathan" else 390.0
	motion.sprite(canvas,"orbit_dust",point+offset,width,Color(.57,.34,.48,alpha*.29),-.08)

static func paint_watcher_back(canvas: Node2D, motion, point: Vector2, alpha: float) -> void:
	motion.sprite(canvas,"orbit_dust",point+Vector2(0,7),820.0,Color(.21,.16,.29,alpha*.67))

static func paint_watcher_front(canvas: Node2D, motion, point: Vector2, time: float, alpha: float) -> void:
	motion.sprite(canvas,"orbit_dust",point+Vector2(24+sin(time*.13)*9,53),650.0,Color(.48,.30,.47,alpha*.26))
	for i in range(3):
		var mote = point+Vector2(-258+i*247,81+i*9)
		motion.sprite(canvas,"derelict",mote,14.0+float(i)*3,Color(.48,.43,.57,alpha*.29),-.05)

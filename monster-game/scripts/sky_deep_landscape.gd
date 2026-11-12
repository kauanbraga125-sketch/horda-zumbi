extends RefCounted

const BACKDROP = "res://assets/art/v164/abyss.webp"
const DUST = "res://assets/art/v164/dust.webp"
const PLANET = Vector2(840.0,-11260.0)
const DEVOURER = Vector2(1160.0,-10800.0)
const DUEL = Vector2(1130.0,-10450.0)
const PLANET_WIDTH = 1100.0
const DEVOURER_SCALE = 500.0
static var backdrop: Texture2D
static var dust: Texture2D

static func warm() -> void:
	if backdrop != null: return
	var image = Image.load_from_file(BACKDROP)
	assert(image != null and not image.is_empty())
	backdrop = ImageTexture.create_from_image(image)
	image = Image.load_from_file(DUST)
	assert(image != null and not image.is_empty())
	dust = ImageTexture.create_from_image(image)

static func project(anchor: Vector2, view: Rect2, camera: Vector2, horizontal_depth: float) -> Vector2:
	# Vertical landmarks are absolute world heights. The view is used only for
	# horizontal parallax; its top never gets added back into the altitude.
	return Vector2(view.position.x+anchor.x-camera.x*horizontal_depth,anchor.y)

static func planet_position(view: Rect2, camera: Vector2) -> Vector2:
	return project(PLANET,view,camera,.006)

static func devourer_position(view: Rect2, camera: Vector2) -> Vector2:
	return project(DEVOURER,view,camera,.012)

static func duel_position(view: Rect2, camera: Vector2) -> Vector2:
	return project(DUEL,view,camera,.018)

static func paint_background(canvas: Node2D, motion, view: Rect2, camera: Vector2, time: float, alpha: float) -> void:
	if alpha<=.001: return
	warm()
	# A finite region of the abyss. Its details pass the camera on ascent and
	# are seen at their original heights on the return.
	var far_origin = project(Vector2(-900,-11000),view,camera,.002)
	var far_region = Rect2(far_origin,Vector2(3400,2267))
	if far_region.intersects(view): faded_plate(canvas,backdrop,far_region,Color(.45,.50,.68,alpha*.45))
	var origin = project(Vector2(-550,-12100),view,camera,.004)
	var region = Rect2(origin,Vector2(2550,1700))
	if region.intersects(view): faded_plate(canvas,backdrop,region,Color(.68,.72,.89,alpha*.82))
	var planet = planet_position(view,camera)
	if view.grow(PLANET_WIDTH*.65).has_point(planet):
		var glow = planet+Vector2(0,PLANET_WIDTH*.064)
		motion.halo(canvas,glow,PLANET_WIDTH*.285,Color("7fc9e3"),alpha*.10)
		motion.sprite(canvas,"space_cathedral",planet,PLANET_WIDTH/motion.frames.space_cathedral.size.x,
			Color(.74,.85,.96,alpha*.94),-.07)
		canvas.draw_arc(glow,PLANET_WIDTH*.283,2.52,4.15,45,Color(.41,.72,.88,alpha*.14),2.0,true)
		# Very small orbiting debris and a remote vessel provide scale cues.
		for i in range(9):
			var angle = float(i)*2.39+time*.014
			var point = glow+Vector2(cos(angle)*PLANET_WIDTH*.43,sin(angle)*PLANET_WIDTH*.31)
			motion.sprite(canvas,"meteor_shards",point,10.0+float(i%3)*5.0,Color(.49,.62,.78,alpha*.40),angle)
		var vessel = planet+Vector2(-PLANET_WIDTH*.37,PLANET_WIDTH*.22)
		motion.sprite(canvas,"derelict",vessel,39.0,Color(.51,.64,.78,alpha*.45),-.10)

static func faded_plate(canvas: Node2D, texture: Texture2D, rect: Rect2, tint: Color) -> void:
	var bands = [0.0,.10,.84,1.0]
	var fade = [0.0,1.0,1.0,0.0]
	for i in range(bands.size()-1):
		var y0 = rect.position.y+rect.size.y*bands[i]
		var y1 = rect.position.y+rect.size.y*bands[i+1]
		var points = PackedVector2Array([Vector2(rect.position.x,y0),Vector2(rect.end.x,y0),Vector2(rect.end.x,y1),Vector2(rect.position.x,y1)])
		var uv = PackedVector2Array([Vector2(0,bands[i]),Vector2(1,bands[i]),Vector2(1,bands[i+1]),Vector2(0,bands[i+1])])
		var top = Color(tint,tint.a*fade[i])
		var bottom = Color(tint,tint.a*fade[i+1])
		canvas.draw_polygon(points,PackedColorArray([top,top,bottom,bottom]),uv,texture)

static func paint_veil(canvas: Node2D, centre: Vector2, alpha: float, width: float = 1120.0) -> void:
	warm()
	var size = Vector2(width,width/3.0)
	faded_plate(canvas,dust,Rect2(centre-size*.5,size),Color(.55,.58,.75,alpha))

static func paint_devourer_back(canvas: Node2D, motion, centre: Vector2, age: float, alpha: float) -> void:
	paint_veil(canvas,centre+Vector2(62,140),alpha*.27,1320.0)
	motion.halo(canvas,centre+Vector2(-141,19),154.0,Color("8bc9db"),alpha*.11)
	for i in range(11):
		var angle = float(i)*2.4+age*.018
		var point = centre+Vector2(-310+cos(angle)*160,-90+sin(angle)*190)
		motion.sprite(canvas,"meteor_shards",point,5.0+float(i%4)*3.0,Color(.60,.64,.79,alpha*.34),angle)

static func paint_devourer_front(canvas: Node2D, motion, centre: Vector2, age: float, alpha: float) -> void:
	# Dust crosses the shoulder and hides the bust's cut edge. This is behind
	# the interactive actors, so the scene never obscures gameplay or the HUD.
	paint_veil(canvas,centre+Vector2(44,160),alpha*.88)
	var ship = centre+Vector2(-380+sin(age*.13)*23,174)
	motion.sprite(canvas,"orbit_saucer_far",ship,22.0,Color(.58,.70,.84,alpha*.53),-.08)
	motion.halo(canvas,ship+Vector2(0,2),5.0,Color("b8dbea"),alpha*.20)

static func paint_bite_impact(canvas: Node2D, motion, mouth: Vector2, hit: float, alpha: float) -> void:
	if hit<=0.0 or hit>=1.45: return
	var strength = alpha*(1.0-hit/1.45)
	motion.burst_particles(canvas,mouth,hit,Color(.60,.77,.91,strength*.76),22,122.0,1.45)
	canvas.draw_set_transform(mouth,-.13,Vector2(1.0,.48))
	canvas.draw_arc(Vector2.ZERO,37.0+hit*93.0,.2,TAU-.2,48,Color(.51,.78,.90,strength*.30),1.5,true)
	canvas.draw_set_transform(Vector2.ZERO)

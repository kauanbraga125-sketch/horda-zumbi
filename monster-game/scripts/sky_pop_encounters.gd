extends RefCounted

const ROOT = "res://assets/art/v166/"
const Deep = preload("res://scripts/sky_deep_landscape.gd")
const SCENES = {
	"worm":{"anchor":Vector2(1070,-2020),"depth":.016},
	"kaiju":{"anchor":Vector2(1070,-4350),"depth":.019},
	"orbit":{"anchor":Vector2(1070,-7520),"depth":.015},
	"time_car":{"anchor":Vector2(1140,-9950),"depth":.008}
}
static var manifest: Dictionary = {}
static var atlases: Dictionary = {}
static var frames: Dictionary = {}

static func metadata() -> void:
	if manifest.is_empty():manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"encounters.json"))

static func warm(group: String) -> void:
	metadata()
	if atlases.has(group):return
	var image = Image.new()
	assert(image.load_webp_from_buffer(FileAccess.get_file_as_bytes(ROOT+manifest.atlases[group].file))==OK)
	var atlas = ImageTexture.create_from_image(image)
	atlases[group] = atlas
	for name in manifest.frames:
		var data: Dictionary = manifest.frames[name]
		if data.atlas!=group:continue
		var a: Array = data.rect
		var tile = AtlasTexture.new();tile.atlas = atlas;tile.region = Rect2(a[0],a[1],a[2],a[3]);tile.filter_clip = true
		frames[name] = {"texture":tile,"size":Vector2(data.size[0],data.size[1]),"pivot":Vector2(data.pivot[0],data.pivot[1])}

static func stamp(canvas: Node2D, name: String, point: Vector2, scale: float, tint: Color, angle: float = 0.0) -> void:
	metadata()
	if not frames.has(name):warm(str(manifest.frames[name].atlas))
	var frame: Dictionary = frames[name]
	var size: Vector2 = frame.size*scale
	canvas.draw_set_transform(point,angle)
	canvas.draw_texture_rect(frame.texture,Rect2(-size*frame.pivot,size),false,tint)
	canvas.draw_set_transform(Vector2.ZERO)

static func position(kind: String, view: Rect2, camera: Vector2) -> Vector2:
	var data: Dictionary = SCENES[kind]
	return Deep.project(data.anchor,view,camera,data.depth)

static func phase(kind: String, time: float) -> float:
	match kind:
		"worm":return fposmod(time-4.5,12.0)
		"kaiju":return fposmod(time-9.0,13.0)
		"orbit":return fposmod(time-20.0,11.5)
	return fposmod(time-27.0,17.0)

static func pulse(time: float, start: float, rise: float, fall: float, end: float) -> float:
	return smoothstep(start,rise,time)*(1.0-smoothstep(fall,end,time))

static func pose(kind: String, time: float) -> Array:
	if kind=="worm":
		return [2 if time>=3.4 and time<4.4 else (3 if time>=4.4 and time<6.4 else (1 if time>=1.8 and time<3.4 else 0))]
	if kind=="kaiju":
		var punch = pulse(time,.8,1.2,2.1,2.6)
		var breath = pulse(time,3.2,3.9,5.5,6.0)
		return [1 if punch>.18 else (2 if breath>.18 else 0),2 if punch>.36 else (1 if breath>.18 else 0)]
	return [1 if time>=1.6 and time<3.2 else (2 if time>=5.25 and time<6.6 else 0),1 if time>=4.0 and time<5.6 else (2 if time>=2.0 and time<3.5 else 0)]

static func ledge_top(root: Vector2, x: float, scale: float) -> Vector2:
	warm("kaiju")
	var frame: Dictionary = frames.ledge
	var size: Vector2 = frame.size*scale
	var origin = root-size*frame.pivot
	var u = clampf((root.x+x-origin.x)/size.x,0.0,1.0)
	var profile: Array = manifest.ledge_profile
	var sample = u*float(profile.size()-1)
	var i = floori(sample)
	var y = lerpf(float(profile[i]),float(profile[mini(i+1,profile.size()-1)]),sample-i)
	return Vector2(root.x+x,origin.y+size.y*y)

static func shadow(canvas: Node2D, point: Vector2, alpha: float) -> void:
	canvas.draw_set_transform(point+Vector2(0,2),0.0,Vector2(29,3.0))
	canvas.draw_circle(Vector2.ZERO,1,Color(.12,.10,.20,alpha*.30),true,-1,true)
	canvas.draw_set_transform(Vector2.ZERO)

static func paint_air(canvas: Node2D, motion, view: Rect2, camera: Vector2, time: float, alpha: float) -> void:
	if alpha<.01:return
	var worm = position("worm",view,camera)
	if Rect2(worm-Vector2(410,490),Vector2(820,650)).intersects(view):paint_worm(canvas,motion,worm,phase("worm",time),alpha)
	var kaiju = position("kaiju",view,camera)
	if Rect2(kaiju-Vector2(520,430),Vector2(1040,720)).intersects(view):paint_kaiju(canvas,motion,kaiju,phase("kaiju",time),alpha)

static func paint_orbit(canvas: Node2D, motion, view: Rect2, camera: Vector2, time: float, alpha: float) -> void:
	if alpha<.01:return
	var duel = position("orbit",view,camera)
	if Rect2(duel-Vector2(470,390),Vector2(940,630)).intersects(view):paint_hunt(canvas,motion,duel,phase("orbit",time),alpha)
	var car = position("time_car",view,camera)
	if view.grow(320).has_point(car):paint_car(canvas,motion,car,phase("time_car",time),alpha)

static func paint_worm(canvas: Node2D, motion, root: Vector2, time: float, alpha: float) -> void:
	warm("worm")
	var state = pose("worm",time)[0]
	var lunge = pulse(time,3.3,3.65,4.1,4.5)
	var body = root+Vector2(-17*lunge,0)
	motion.sprite(canvas,"mist_far",root+Vector2(0,-22),570.0,Color(.54,.52,.75,alpha*.36))
	stamp(canvas,"worm_"+str(state),body,440.0,Color(.62,.61,.77,alpha*.74),-.025*lunge)
	var mouth = root+Vector2(-105,-286).lerp(Vector2(-185,-210),lunge)
	if time>=.7 and time<4.45:
		var approach = smoothstep(.7,4.1,time)
		var capture = smoothstep(4.05,4.45,time)
		var traveler = mouth+Vector2(lerpf(-204,0,approach),-52.0*(1.0-approach)+sin(time*3.0)*3.0)
		stamp(canvas,"traveler",traveler,lerpf(48,13,capture),Color(.75,.70,.80,alpha*.77*(1.0-capture)),sin(time*3.3)*.10)
	if time>=6.4 and time<7.8:
		var burp = (time-6.4)/1.4
		stamp(canvas,"burp",mouth+Vector2(-32-burp*57,-burp*55),110+burp*42,Color(.69,.68,.86,alpha*.52*sin(burp*PI)))
	motion.sprite(canvas,"mist_front",root+Vector2(12,9),490.0,Color(.57,.53,.77,alpha*.47))

static func paint_kaiju(canvas: Node2D, motion, root: Vector2, time: float, alpha: float) -> void:
	warm("kaiju")
	stamp(canvas,"ledge",root,650.0,Color(.52,.48,.68,alpha*.80))
	var action = pose("kaiju",time)
	var punch = pulse(time,.8,1.2,2.1,2.6)
	var breath = pulse(time,3.2,3.9,5.5,6.0)
	var kong = ledge_top(root,-150+punch*26,650)
	var zilla = ledge_top(root,153-punch*16,650)
	shadow(canvas,kong,alpha);shadow(canvas,zilla,alpha)
	stamp(canvas,"zilla_"+str(action[1]),zilla,325.0,Color(.55,.61,.78,alpha*.77),punch*.025)
	stamp(canvas,"kong_"+str(action[0]),kong,310.0,Color(.66,.57,.67,alpha*.77),-punch*.025)
	var mouth = zilla+Vector2(-92,-239)
	if breath>.02:
		motion.halo(canvas,mouth,25,Color("9ccbf4"),alpha*breath*.23)
	if breath>.45:
		var hit = kong+Vector2(39,-195)
		canvas.draw_line(mouth,hit,Color(.38,.68,.92,alpha*breath*.24),7,true)
		canvas.draw_line(mouth,hit,Color(.66,.87,1,alpha*breath*.48),1.3,true)
		stamp(canvas,"atomic_puff",hit,115.0,Color(.65,.73,.91,alpha*breath*.43))
	if punch>.75:
		motion.burst_particles(canvas,zilla+Vector2(-60,-169),fposmod(time-.95,.65),Color(.70,.64,.79,alpha*.35),7,58,.65)
	motion.sprite(canvas,"mist_front",root+Vector2(0,76),620.0,Color(.50,.51,.71,alpha*.34))

static func paint_hunt(canvas: Node2D, motion, root: Vector2, time: float, alpha: float) -> void:
	warm("orbit");warm("kaiju")
	stamp(canvas,"ledge",root,555.0,Color(.45,.34,.48,alpha*.62))
	var action = pose("orbit",time)
	var advance = pulse(time,1.1,1.7,3.2,3.9)
	var alien = ledge_top(root,-132+advance*48,555)
	var hunter = ledge_top(root,139,555)
	if time>1.3 and time<3.8:alien.y -= sin((time-1.3)/2.5*PI)*64.0
	shadow(canvas,ledge_top(root,-132,555),alpha);shadow(canvas,hunter,alpha)
	var cloak = lerpf(.22,.76,smoothstep(.1,1.2,time))
	stamp(canvas,"hunter_"+str(action[1]),hunter,275.0,Color(.72,.61,.68,alpha*cloak))
	stamp(canvas,"alien_"+str(action[0]),alien,300.0,Color(.55,.59,.68,alpha*.78),-.03*advance)
	var cannon = hunter+Vector2(-88,-235)
	var target = alien+Vector2(43,-146)
	var aiming = pulse(time,4.0,4.5,5.4,5.8)
	if aiming>.01:motion.halo(canvas,cannon,17,Color("e6ae84"),alpha*aiming*.26)
	if time>=4.75 and time<5.4:
		var shot = (time-4.75)/.65
		var point = cannon.lerp(target,shot)
		canvas.draw_line(point+Vector2(22,-1),point,Color(.89,.61,.44,alpha*.30),2,true)
		motion.halo(canvas,point,11,Color("f6c496"),alpha*.34)
		canvas.draw_circle(point,2.2,Color(.94,.76,.59,alpha*.76),true,-1,true)
	if time>=5.35 and time<6.5:
		var impact = (time-5.35)/1.15
		stamp(canvas,"atomic_puff",target+Vector2(0,26),120+impact*38,Color(.46,.68,.58,alpha*.32*sin(impact*PI)))
	motion.sprite(canvas,"orbit_dust",root+Vector2(-15,57),630.0,Color(.58,.34,.46,alpha*.37),-.07)

static func paint_car(canvas: Node2D, motion, root: Vector2, time: float, alpha: float) -> void:
	warm("kaiju")
	if time>7.0:return
	var crossing = smoothstep(1.3,6.0,time)
	var point = root+Vector2(lerpf(176,-185,crossing),0)
	var visible = smoothstep(.8,1.5,time)*(1.0-smoothstep(6.0,6.7,time))
	if visible>.01:
		stamp(canvas,"time_car",point,165,Color(.68,.73,.84,alpha*visible*.64),-.025)
		canvas.draw_line(point+Vector2(36,10),point+Vector2(79,10),Color(.42,.70,.96,alpha*visible*.26),1.2,true)
	if time>=5.7:
		var glow = sin(clampf((time-5.7)/1.3,0,1)*PI)
		motion.halo(canvas,point,42,Color("96bfe8"),alpha*glow*.17)
		canvas.draw_set_transform(point,-.12,Vector2(.48,1))
		canvas.draw_arc(Vector2.ZERO,34+glow*13,.1,TAU-.1,40,Color(.54,.76,.98,alpha*glow*.31),1.5,true)
		canvas.draw_set_transform(Vector2.ZERO)

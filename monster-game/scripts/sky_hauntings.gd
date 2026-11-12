extends RefCounted

const WALK = ["giant_step_0", "giant_step_1", "giant_step_2", "giant_step_3"]
const MOTH = ["duel_moth_up", "duel_moth_down"]
const DRAKE = ["duel_drake_open", "duel_drake_shut"]
const ORBIT_MIN = 10030.0
const LENGTH = 6.4
const VIOLET = Color("a38dd7")
const CYAN = Color("86e8e2")
const Landscape = preload("res://scripts/sky_landscape.gd")
const Deep = preload("res://scripts/sky_deep_landscape.gd")
const WALKER_SCALE = 260.0

var random = RandomNumberGenerator.new()
var clock = 0.0
var scene_at = -LENGTH
var next_at = 0.0
var scene = 0
var devour_seen = false
var devour_clock = 0.0

func reset(seed_value: int) -> void:
	random.seed = seed_value ^ 0x1605c
	clock = 0.0
	scene_at = -LENGTH
	next_at = random.randf_range(.65, 1.8)
	scene = 0
	devour_seen = false
	devour_clock = 0.0

func advance(dt: float, height: float) -> void:
	if height>=10900.0: devour_seen = true
	if devour_seen: devour_clock += dt
	if height < ORBIT_MIN and clock - scene_at >= LENGTH: return
	clock += dt
	if height >= ORBIT_MIN and clock >= next_at:
		scene_at = clock
		scene = random.randi_range(0, 1)
		next_at = clock + random.randf_range(16.0, 24.0)

static func walker_position(view: Rect2, camera: Vector2, time: float) -> Vector2:
	return Landscape.walker_position(view,camera,time)

static func walker(canvas: Node2D, motion, view: Rect2, camera: Vector2, time: float, visibility: float) -> void:
	if visibility <= .01: return
	var foot = walker_position(view,camera,time)
	if not view.grow(320.0).has_point(foot): return
	var opacity = visibility * .32 * smoothstep(.7, 2.6, time)
	var stride = time * 1.25
	var frame = int(floor(stride)) % WALK.size()
	Landscape.contact_shadow(canvas,foot,visibility)
	# Low contrast and a small soft edge put the silhouette beyond the playfield.
	for offset in [Vector2(-1.1,0),Vector2(1.1,0),Vector2(0,-.8),Vector2(0,.8)]:
		motion.sprite(canvas,WALK[frame],foot+offset,WALKER_SCALE,Color(.61,.60,.76,opacity*.065))
	motion.sprite(canvas,WALK[frame],foot,WALKER_SCALE,Color(.61,.60,.76,opacity))
	var fog_drift = sin(time*.19)*19.0
	motion.sprite(canvas,"mist_far",foot+Vector2(-34+fog_drift,-22),285.0,Color(.64,.60,.79,opacity*.65))
	motion.sprite(canvas,"mist_front",foot+Vector2(52-fog_drift,-9),205.0,Color(.69,.63,.82,opacity*.48))
	var step = fposmod(stride, 2.0)
	var dust = smoothstep(0.0, .24, step) * (1.0 - smoothstep(.25, 1.3, step))
	if dust > .01:
		motion.sprite(canvas, "orbit_dust", foot + Vector2(-42 + step * 22, -9),
			107 + step * 25, Color(.67, .60, .80, dust * opacity * .20))

static func passers(canvas: Node2D, motion, view: Rect2, camera: Vector2, time: float, alpha: float) -> void:
	if alpha <= .012: return
	var position = Deep.project(Vector2(1280-time*12.0,-7600+sin(time*.78)*30.0),view,camera,.022)
	if not view.grow(85.0).has_point(position): return
	var frame = int(time * 5.0) % MOTH.size()
	motion.sprite(canvas, MOTH[frame], position, 81.0, Color(.68, .75, 1, alpha * .51), sin(time * 1.1) * .13)
	motion.sprite(canvas, MOTH[1 - frame], position + Vector2(-59, 24), 42.0,
		Color(.65, .70, .93, alpha * .34), -.08)

func paint_orbit(canvas: Node2D, motion, view: Rect2, camera: Vector2, alpha: float) -> void:
	if alpha<=.01: return
	var centre = Deep.devourer_position(view,camera)
	if devour_seen and view.grow(820.0).has_point(centre):
		var visible = alpha*smoothstep(0.0,.9,devour_clock)
		var phase = fposmod(devour_clock,12.0)
		Deep.paint_devourer_back(canvas,motion,centre,devour_clock,visible)
		paint_bite(canvas,motion,centre,phase,visible)
		Deep.paint_devourer_front(canvas,motion,centre,devour_clock,visible)
	var age = clock - scene_at
	if age >= LENGTH or scene!=1: return
	var opacity = alpha * smoothstep(0.0, .92, age) * (1.0 - smoothstep(5.24, LENGTH, age))
	paint_duel(canvas,motion,Deep.duel_position(view,camera),age,opacity)

static func paint_bite(canvas: Node2D, motion, centre: Vector2, age: float, alpha: float) -> void:
	var lean = smoothstep(.9, 2.48, age) * (1.0 - smoothstep(2.64, 3.4, age))
	var swallow = smoothstep(3.66, 4.45, age)
	var head = centre+Vector2(-18.0*lean+13.0*swallow,0.0)
	var approach = smoothstep(.16, 2.47, age)
	var rebound = smoothstep(2.5, 3.03, age)
	var mouth = head+Vector2(-165.0,38.0)
	var planet = mouth+Vector2(-173.0*(1.0-approach)-52.0*rebound+93.0*swallow,
		31.0*sin(approach*PI)+12.0*rebound)
	var biting = (age >= 2.49 and age < 3.55) or age >= 4.25
	var jaws = "devour_closed" if biting else "devour_open"
	if swallow < .995:
		var rock = "devour_planet" if age < 2.49 else "devour_bitten"
		var prey_alpha = alpha*(1.0-swallow)*smoothstep(.05,.7,age)
		motion.halo(canvas,planet,100.0,CYAN,prey_alpha*.18)
		motion.sprite(canvas,rock,planet,lerpf(185.0,18.0,swallow),Color(.83,.91,1,prey_alpha*.92),age*-.10)
	motion.sprite(canvas,jaws,head,Deep.DEVOURER_SCALE,Color(.67,.73,.84,alpha*.92),-.045*lean)
	var hit = age - 2.49
	Deep.paint_bite_impact(canvas,motion,mouth,hit,alpha)

static func paint_duel(canvas: Node2D, motion, centre: Vector2, age: float, alpha: float) -> void:
	Deep.paint_veil(canvas,centre+Vector2(0,145),alpha*.22,1040.0)
	var closing = smoothstep(.28, 2.35, age) - smoothstep(2.53, 3.22, age)
	var retort = smoothstep(3.05, 4.25, age) - smoothstep(4.38, 5.42, age)
	var reach = maxf(closing, retort)
	var width = lerpf(290.0, 105.0, reach) + 116.0 * smoothstep(4.95, 6.35, age)
	var moth = centre + Vector2(-width, -37.0 + 51.0 * closing + sin(age * 5.0) * 13.0)
	var drake = centre + Vector2(width, 19.0 - 24.0 * retort + sin(age * 3.3) * 12.0)
	motion.sprite(canvas, MOTH[int(age * (5.0 + 1.7 * reach)) % 2], moth, 190.0,
		Color(.75, .79, 1, alpha * .72), .10 * closing - .13 * retort)
	motion.sprite(canvas, DRAKE[0 if retort > .4 or closing > .54 else 1], drake, 155.0,
		Color(.94, .70, .72, alpha * .73), -.09 * retort + .075 * closing)
	var hit = age - (4.25 if age >= 4.25 else 2.35)
	if hit >= 0.0 and hit < .51:
		var impact = (moth + drake) * .5
		var light = Color("f7b385") if age >= 4.25 else CYAN
		motion.halo(canvas, impact, 31.0 + hit * 49.0, light, alpha * (1.0 - hit * 1.9) * .56)
		motion.burst_particles(canvas, impact, hit, Color(light, alpha * .82), 8, 110.0, .86)
		Deep.paint_bite_impact(canvas,motion,impact,hit,alpha*.40)

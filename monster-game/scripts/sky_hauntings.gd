extends RefCounted

const WALK = ["giant_step_0", "giant_step_1", "giant_step_2", "giant_step_3"]
const MOTH = ["duel_moth_up", "duel_moth_down"]
const DRAKE = ["duel_drake_open", "duel_drake_shut"]
const ORBIT_MIN = 10030.0
const LENGTH = 6.4
const VIOLET = Color("a38dd7")
const CYAN = Color("86e8e2")

var random = RandomNumberGenerator.new()
var clock = 0.0
var scene_at = -LENGTH
var next_at = 0.0
var scene = 0

func reset(seed_value: int) -> void:
	random.seed = seed_value ^ 0x1605c
	clock = 0.0
	scene_at = -LENGTH
	next_at = random.randf_range(.65, 1.8)
	scene = 0

func advance(dt: float, height: float) -> void:
	if height < ORBIT_MIN and clock - scene_at >= LENGTH: return
	clock += dt
	if height >= ORBIT_MIN and clock >= next_at:
		scene_at = clock
		scene = random.randi_range(0, 1)
		next_at = clock + random.randf_range(16.0, 24.0)

static func walker(canvas: Node2D, motion, view: Rect2, camera: Vector2, time: float, visibility: float) -> void:
	if visibility <= .01: return
	var distance = fposmod(time * 24.0 + camera.x * .036 + 180.0, view.size.x + 520.0)
	var foot = Vector2(view.end.x + 265.0 - distance, view.position.y + view.size.y * .91)
	foot.y += sin(camera.y * .0011) * 28.0
	if foot.x < view.position.x - 205.0 or foot.x > view.end.x + 205.0: return
	var opacity = visibility * .62 * smoothstep(.7, 2.6, time)
	var stride = time * 2.75
	var frame = int(floor(stride)) % WALK.size()
	motion.sprite(canvas, WALK[frame], foot, 333.0, Color(.69, .65, .85, opacity))
	var step = fposmod(stride, 2.0)
	var dust = smoothstep(0.0, .24, step) * (1.0 - smoothstep(.25, 1.3, step))
	if dust > .01:
		motion.sprite(canvas, "orbit_dust", foot + Vector2(-42 + step * 22, -9),
			133 + step * 35, Color(.73, .63, .88, dust * opacity * .34))

static func passers(canvas: Node2D, motion, view: Rect2, camera: Vector2, time: float, alpha: float) -> void:
	if alpha <= .012: return
	var travel = fposmod(time * 62.0 + camera.x * .065 + 605.0, view.size.x + 250.0)
	var position = view.position + Vector2(travel - 120.0, view.size.y * .24 - 37.0 * sin(time * .78))
	if not view.grow(85.0).has_point(position): return
	var frame = int(time * 5.0) % MOTH.size()
	motion.sprite(canvas, MOTH[frame], position, 81.0, Color(.68, .75, 1, alpha * .51), sin(time * 1.1) * .13)
	motion.sprite(canvas, MOTH[1 - frame], position + Vector2(-59, 24), 42.0,
		Color(.65, .70, .93, alpha * .34), -.08)

func paint_orbit(canvas: Node2D, motion, view: Rect2, camera: Vector2, alpha: float) -> void:
	var age = clock - scene_at
	if age >= LENGTH or alpha <= .01: return
	var opacity = alpha * smoothstep(0.0, .92, age) * (1.0 - smoothstep(5.24, LENGTH, age))
	var centre = view.position + view.size * Vector2(.62, .80 if scene == 0 else .69)
	centre += Vector2(sin(camera.x * .00062) * 48.0, sin(camera.y * .00051) * 27.0)
	if scene == 0:
		paint_bite(canvas, motion, centre, age, opacity)
	else:
		paint_duel(canvas, motion, centre, age, opacity)

static func paint_bite(canvas: Node2D, motion, centre: Vector2, age: float, alpha: float) -> void:
	var lean = smoothstep(.9, 2.48, age) * (1.0 - smoothstep(2.64, 3.4, age))
	var swallow = smoothstep(3.66, 4.45, age)
	var head = centre + Vector2(114.0 - 39.0 * lean + 29.0 * swallow, 9.0 + sin(age * 2.6) * 6.0)
	var approach = smoothstep(.16, 2.47, age)
	var rebound = smoothstep(2.5, 3.03, age)
	var mouth = head + Vector2(-100.0, 13.0)
	var planet = mouth + Vector2(-130.0 * (1.0 - approach) - 47.0 * rebound + 74.0 * swallow,
		24.0 * sin(approach * PI) + 9.0 * rebound)
	var biting = (age >= 2.49 and age < 3.55) or age >= 4.25
	var jaws = "devour_closed" if biting else "devour_open"
	if swallow < .995:
		var rock = "devour_planet" if age < 2.49 else "devour_bitten"
		motion.halo(canvas, planet, 60.0, CYAN, alpha * (1.0 - swallow) * .19)
		motion.sprite(canvas, rock, planet, lerpf(107.0, 14.0, swallow),
			Color(.89, .93, 1, alpha * (1.0 - swallow) * .85), age * -.19)
	motion.sprite(canvas, jaws, head, 288.0, Color(.78, .70, .90, alpha * .72), -.11 * lean + .045 * sin(age * 5.0))
	var hit = age - 2.49
	if hit > 0.0 and hit < .74:
		motion.burst_particles(canvas, mouth, hit, Color(VIOLET, alpha * .74), 8, 89.0, .67)

static func paint_duel(canvas: Node2D, motion, centre: Vector2, age: float, alpha: float) -> void:
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

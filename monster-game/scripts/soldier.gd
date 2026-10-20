class_name HordeSoldier
extends RefCounted
const ROOT = "res://assets/art/soldier_v100/"
const FOOT = Vector2(328, 352)
const SCALE = 108.0 / 304.0
const SHOULDER = Vector2(384.2149, 160.0939)
const SNIPER_MUZZLE = Vector2(11.0964, 129.0464)
var meta: Dictionary = {}
var textures: Array[Texture2D] = []
var sniper: Texture2D
var rocket: Texture2D
var explosion: Texture2D
var flash: Texture2D
var sniper_flash: Texture2D
var polish = HordePolish.new()

func _init() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "runtime.json"))

func load_art() -> void:
	if not textures.is_empty(): return
	for page in meta.pages: textures.append(load(ROOT + page))
	sniper = load(ROOT + "sniper.png");rocket = load(ROOT + "rocket.png")
	explosion = load(ROOT + "explosion.png");flash = load(ROOT + "flash.png");sniper_flash = load(ROOT + "sniper_flash.png")

func frame(e: Dictionary) -> int:
	var clip = str(e.get("weapon", "bazooka"))
	var t = float(e.get("weapon_t", 0.0))
	var rate = float(e.get("weapon_rate", 1.0))
	if clip == "transition": return clampi(int(t / 0.75 * 49), 0, 48)
	if str(e.get("soldier_phase", "wait")) == "wait": return int(t * 4) % 3
	return clampi(int(t * 30.0 * rate), 0, 48)

func muzzle(e: Dictionary) -> Vector2:
	var foot = Vector2(e.x, e.y)
	if str(e.get("weapon", "bazooka")) == "sniper":
		return foot + (SHOULDER - FOOT + (SNIPER_MUZZLE - SHOULDER).rotated(float(e.get("aim_angle", 0)))) * SCALE
	var clip = str(e.get("weapon", "bazooka"))
	if clip == "transition": clip = "revolver"
	var point: Array = meta.muzzles[clip][frame(e)]
	return foot + (Vector2(point[0], point[1]) - FOOT) * SCALE

func update(run, e: Dictionary, dt: float) -> void:
	if e.taken or e.state != "normal": return
	if not e.has("weapon"):
		e.weapon = "sniper" if run.tunnel_number() >= 7 and run.active_count() >= 24 else "bazooka"
		e.soldier_phase = "wait";e.weapon_t = 0.0;e.encounter_t = 0.0;e.loops = 0;e.aim_angle = 0.0
		e.weapon_rate = clampf(1.0 + run.tunnel_number() * 0.055, 1.0, 1.8);e.weapon_fired = false
	if e.x < HordeRun.ANCHOR + 220: e.vx = 0.0;return
	if e.x > minf(run.view_right + 80, HordeRun.ANCHOR + 1200): return
	e.encounter_t += dt;e.weapon_t += dt
	# Retreat slowly while changing weapons; the horde keeps gaining ground.
	e.vx = run.speed * (1.0 if e.x <= HordeRun.ANCHOR + 400 else 0.92) if float(e.encounter_t) < 8.5 else 0.0
	e.y = run.ground_y(e.x)
	if e.soldier_phase == "wait":
		if e.weapon_t >= 0.45:
			e.soldier_phase = "attack";e.weapon_t = 0.0
		return
	if e.weapon == "transition":
		if e.weapon_t >= 0.75: e.weapon = "revolver";e.weapon_t = 0.0;e.weapon_fired = false
		return
	if e.weapon in ["sniper_in", "bazooka_in"]:
		if e.weapon_t >= 0.32:
			e.weapon = "sniper" if e.weapon == "sniper_in" else "bazooka"
			e.weapon_t = 0.0;e.weapon_fired = false
		return
	if e.weapon == "sniper":
		var track = maxf(0.55, 0.85 / float(e.weapon_rate))
		if e.weapon_t < track:
			var lead = run.leader_index()
			if lead >= 0:
				var shoulder = Vector2(e.x, e.y) + (SHOULDER - FOOT) * SCALE
				var target = Vector2(run.members[lead].x, run.members[lead].y - 52)
				var delta = target - shoulder
				var angle = wrapf(delta.angle() + asin(clampf((SNIPER_MUZZLE.y - SHOULDER.y) * SCALE / maxf(1, delta.length()), -1, 1)) - PI, -PI, PI)
				e.aim_angle = clampf(angle, deg_to_rad(-10), deg_to_rad(16))
		elif not bool(e.weapon_fired) and e.weapon_t >= track + 0.35:
			fire(run, e, "tracking");e.weapon_fired = true
		if e.weapon_t > track + 0.35 + 0.55:
			e.weapon_t = 0.0;e.weapon_fired = false;e.loops += 1
			if run.tunnel_number() < 7 and int(e.loops) >= 1: e.weapon = "bazooka_in"
		return
	var shot_frame = 21 if e.weapon == "bazooka" else 19
	var shot_time = float(shot_frame) / (30.0 * float(e.weapon_rate))
	if not bool(e.weapon_fired) and e.weapon_t >= shot_time:
		fire(run, e, "rocket" if e.weapon == "bazooka" else "high");e.weapon_fired = true
	if e.weapon_t >= 49.0 / (30.0 * float(e.weapon_rate)) + 0.12:
		e.weapon = "transition" if e.weapon == "bazooka" else "sniper_in"
		e.weapon_t = 0.0;e.weapon_fired = false

func fire(run, e: Dictionary, mode: String) -> void:
	if e.state != "normal" or e.x < HordeRun.ANCHOR + 220 or run.dead: return
	var origin = muzzle(e)
	var velocity = clampf(run.speed * 0.95, 330, 620)
	var flight = maxf(0.35, (origin.x - HordeRun.ANCHOR) / (run.speed + velocity))
	var vy = 0.0
	if mode == "tracking": vy = -velocity * tan(float(e.aim_angle))
	else:
		var target = run.ground_y(HordeRun.ANCHOR) - (24 if mode == "rocket" else 148)
		vy = clampf((target - origin.y) / flight, -260, 260)
	var bullet = run.add_entity("bullet", origin.x, origin.y, 0, 18)
	bullet.vx = -velocity;bullet.vy = vy;bullet.shot_mode = mode;bullet.homing_left = 0.0
	bullet.previous_x = origin.x;bullet.previous_y = origin.y
	e.flash = 0.09;run.shots += 1
	run.events.append({"type": "shot", "x": origin.x, "y": origin.y});run.invalidate_coins()

func explode(run, e: Dictionary) -> void:
	if e.taken: return
	e.taken = true
	var blast = run.add_entity("soldier_blast", e.x, e.y, 0, 1)
	blast.age = 0.0
	run.events.append({"type": "explosion", "x": e.x, "y": e.y, "soldier": true})
	if run.hit_grace > 0 or run.boost_protected() or run.transform_left > 0 or (run.perk_kind == 2 and run.perk_left > 0): return
	# The radius is tested once on impact; lingering art never applies damage.
	var hits = 0
	for i in range(run.members.size() - 1, -1, -1):
		if Vector2(run.members[i].x, run.members[i].y - 45).distance_to(Vector2(e.x, e.y)) < 92:
			if run.damage(i, "rocket_explosion"): hits += 1
			if hits >= 1: break

func paint(canvas: Node2D, e: Dictionary, tint: Color = Color.WHITE) -> void:
	load_art()
	if e.state == "capture": polish.capture(canvas,e,tint);return
	if str(e.get("weapon","")) in ["sniper_in","bazooka_in"]: polish.weapon_switch(canvas,e,tint);return
	var foot = Vector2(e.x, e.y)
	var angle = 0.0
	var clip = str(e.get("weapon", "bazooka"))
	if e.state == "capture":
		var progress = HordeCaptureMotion.progress(e)
		foot += Vector2(-progress * 12, -sin(progress * PI) * 20)
		angle = -progress * 1.4;tint.a *= 1.0 - smoothstep(0.65, 1.0, progress)
	if clip == "sniper":
		var aim = float(e.get("aim_angle", 0))
		var kick = 0.0
		if bool(e.get("weapon_fired", false)):
			var track = maxf(0.55, 0.85 / float(e.get("weapon_rate", 1)))
			var phase = clampf((float(e.get("weapon_t", 0)) - track - 0.35) * 24.0, 0, 7)
			var samples = [0.0,0.15,1.0,0.65,0.35,0.15,0.04,0.0]
			kick = lerpf(samples[floori(phase)], samples[mini(7,floori(phase)+1)], phase-floorf(phase))
		aim += deg_to_rad(2.4) * kick
		var recoil_shift = Vector2(3.0 * kick, 0).rotated(aim) * SCALE
		var pieces = meta.sniper.atlas.placements
		for part in ["Cabeca", "Corpo", "Bracos_Sniper"]:
			var spec: Dictionary = pieces[part];var r: Array = spec.region;var m: Array = spec.margin
			var a = aim if part != "Corpo" else 0.0
			canvas.draw_set_transform(foot + (SHOULDER - FOOT) * SCALE + (recoil_shift if part != "Corpo" else Vector2.ZERO), a + angle)
			canvas.draw_texture_rect_region(sniper, Rect2((Vector2(m[0], m[1]) - SHOULDER) * SCALE, Vector2(r[2], r[3]) * SCALE), Rect2(r[0], r[1], r[2], r[3]), tint)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		var item: Dictionary = meta.clips[clip][frame(e)]
		var r: Array = item.region;var offset = Vector2(item.offset[0], item.offset[1])
		canvas.draw_set_transform(foot, angle)
		canvas.draw_texture_rect_region(textures[int(item.page)], Rect2((offset - FOOT) * SCALE, Vector2(r[2], r[3]) * SCALE / float(meta.scale)), Rect2(r[0], r[1], r[2], r[3]), tint)
		canvas.draw_set_transform(Vector2.ZERO)
	if e.state != "normal": return
	var origin = muzzle(e)
	if float(e.get("flash", 0)) > 0:
		if clip == "sniper":
			var flash_frame = clampi(int((0.09 - float(e.flash)) / 0.03), 0, 2)
			canvas.draw_set_transform(origin, float(e.get("aim_angle", 0)))
			canvas.draw_texture_rect_region(sniper_flash, Rect2(-Vector2(116,64)*0.3,Vector2(128,128)*0.3),Rect2(flash_frame*128,0,128,128))
			canvas.draw_set_transform(Vector2.ZERO)
		else: canvas.draw_texture_rect_region(flash, Rect2(origin - Vector2(17, 17), Vector2(34, 34)), Rect2(0, 0, 128, 128))
	if clip == "sniper":
		var t = float(e.get("weapon_t", 0));var track = maxf(0.55, 0.85 / float(e.get("weapon_rate", 1)))
		if t < track + 0.35:
			var direction = Vector2.LEFT.rotated(float(e.get("aim_angle", 0)))
			var locked = t >= track
			canvas.draw_line(origin, origin + direction * minf(1100, e.x + 100), Color(1, 0.25 if locked else 0.55, 0.3, 0.8 if locked else 0.30), 2.4 if locked else 1.2, true)
			canvas.draw_arc(origin + direction * (origin.x - HordeRun.ANCHOR), 16, 0, TAU, 18, Color(1, 0.4, 0.5, 0.7), 2, true)

func paint_projectile(canvas: Node2D, e: Dictionary) -> void:
	load_art()
	if e.kind == "soldier_blast":
		var index = clampi(int(float(e.age) * 18), 0, 7)
		canvas.draw_texture_rect_region(explosion, Rect2(Vector2(e.x, e.y) - Vector2(80, 80), Vector2(160, 160)), Rect2(index % 4 * 256, int(index / 4) * 256, 256, 256))
	elif str(e.get("shot_mode", "")) == "rocket":
		var index = int(float(e.age) * 18) % 6
		canvas.draw_set_transform(Vector2(e.x, e.y), atan2(-float(e.vy), -float(e.vx)))
		canvas.draw_texture_rect_region(rocket, Rect2(-Vector2(96, 64) * 0.28, Vector2(256, 128) * 0.28), Rect2(index % 3 * 256, int(index / 3) * 128, 256, 128))
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		var color = Color("dc9aff") if str(e.get("shot_mode", "")) == "tracking" else Color("8ff4ff")
		canvas.draw_line(Vector2(e.x + 24, e.y), Vector2(e.x, e.y), color, 3, true)
		canvas.draw_circle(Vector2(e.x, e.y), 3.5, Color("fff3d5"))

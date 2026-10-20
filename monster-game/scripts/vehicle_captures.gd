class_name HordeVehicleCaptures
extends RefCounted


const DURATION = 0.86
const STAGGER = 0.065
const LIMIT = 48
var active: Array[Dictionary] = []

func clear() -> void :
	active.clear()

func add(event: Dictionary) -> void :
	var variants: Array = event.get("passenger_variants", [])
	var ids: Array = event.get("join_ids", [])
	for i in range(variants.size()):
		if active.size() >= LIMIT: active.pop_front()
		var variant = int(variants[i])
		var person = {"kind": "civilian", "variant": variant, "state": "capture", "capture_duration": DURATION, "capture_left": DURATION, 
			"capture_kind": 0, "worker_time": 0.0, "civil_key": "civil_casaco_azul_nerd" if variant == 0 else "", 
			"civil_flip": true, "woman_clip": "capture", "woman_reverse": true, "vx": 0.0}
		active.append({"origin": Vector2(float(event.x) + (i - (variants.size() - 1) * 0.5) * 17.0, float(event.y) - 15.0), 
			"age": - float(i) * STAGGER, "member_id": int(ids[i]) if i < ids.size() else -1, "person": person, "index": i})

static func position_for(passenger: Dictionary, run: HordeRun) -> Vector2:
	var member = run.member_by_id(int(passenger.member_id))
	if member.is_empty():
		var lead = run.leader_index()
		if lead >= 0: member = run.members[lead]
	var target = Vector2(float(member.x) + 20.0, float(member.y) - 8.0) if not member.is_empty() else Vector2(HordeRun.ANCHOR, HordeRun.FLOOR)
	var u = clampf(float(passenger.age) / DURATION, 0.0, 1.0)
	var point: Vector2 = passenger.origin.lerp(target, smoothstep(0.0, 1.0, u))
	point.y -= sin(u * PI) * (82.0 + int(passenger.index) % 3 * 10.0)
	point.y += smoothstep(0.75, 1.0, u) * 12.0
	return point

func update(dt: float, run: HordeRun, effects: HordeEffects) -> void :
	if run.dead:
		clear()
		return
	for i in range(active.size() - 1, -1, -1):
		var passenger = active[i]
		passenger.age += dt
		passenger.origin.x -= run.speed * dt
		if float(passenger.age) >= DURATION:
			var point = position_for(passenger, run) - Vector2(0, 65)
			for j in range(3): effects.add("dust", point, Vector2((j - 1) * 15, -15), Color("eab6db"), 15, 0.24)
			active.remove_at(i)

func paint(canvas: Node2D, art: HordeArt, run: HordeRun, front: bool) -> void :
	for passenger in active:
		if float(passenger.age) < 0.0: continue
		var u = clampf(float(passenger.age) / DURATION, 0.0, 1.0)
		if front != (u < 0.64): continue
		var point = position_for(passenger, run)
		if point.x < run.view_left - 150 or point.x > run.view_right + 150: continue
		var person: Dictionary = passenger.person
		person.capture_left = (1.0 - u) * DURATION
		person.worker_time = float(passenger.age)
		var angle = sin(u * TAU) * 0.12
		var tint = Color(1, 1, 1, 1.0 - smoothstep(0.88, 1.0, u))
		match int(person.variant):
			0: art.civil.paint(canvas, person, point, 112.0, tint, angle)
			1: art.woman.paint(canvas, person, point, 104.0, tint, angle)
			2: art.worker.paint(canvas, person, point, 110.0, tint, angle)

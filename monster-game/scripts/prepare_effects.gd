extends RefCounted

# Cosmetic feedback only. These particles never enter the gameplay entity list.
const LIFE = 3.25
const COLORS = {"coin_magnet":Color("ffe17b"),"power_harvester":Color("c59cff"),"power_spectral":Color("8befff"),"civil_pack":Color("8be5ff"), "coin_bombs":Color("ffc650"), "coin_cars":Color("c58aff"),
	"double_coins":Color("ffe17b"), "double_horde":Color("8df1bd"), "bonus_time":Color("c5a0ff"),
	"power_fly":Color("ff888f"), "power_mask":Color("ee777f"), "power_shield":Color("8befff"), "power_boost":Color("ff9460")}
const LABELS = {"coin_magnet":"ÍMÃ NESTA PARTIDA","power_harvester":"CAÇADOR A CAMINHO","power_spectral":"MANTO ATIVADO","civil_pack":"ALMAS A CAMINHO", "coin_bombs":"BOMBAS DE OURO", "coin_cars":"SUCATA VALIOSA",
	"double_coins":"MOEDAS ×2", "double_horde":"HORDA DUPLICADA", "bonus_time":"+15 SEGUNDOS",
	"power_fly":"MOSCA ATIVADA", "power_mask":"MASCARADO ATIVADO", "power_shield":"PROTEÇÃO ATIVADA", "power_boost":"ARRANCADA ATIVADA"}
var events: Array[Dictionary] = []
var ritual = preload("res://scripts/prepare_ritual.gd").new()

static func duration(id: String) -> float:
	return LIFE if id == "double_horde" else 2.55

func dominant_event() -> Dictionary:
	var summon = event_for("double_horde")
	return summon if not summon.is_empty() else (events[-1] if not events.is_empty() else {})

func clear() -> void: events.clear()

func trigger(id: String, source: Vector2, old_count: int) -> void:
	events.append({"id":id, "age":0.0, "source":source, "old_count":old_count})

func advance(dt: float) -> void:
	for i in range(events.size() - 1, -1, -1):
		events[i].age += dt
		if events[i].age >= duration(events[i].id): events.remove_at(i)

func event_for(id: String) -> Dictionary:
	for e in events:
		if e.id == id: return e
	return {}

func appearance(id: String, index: int) -> float:
	var e = event_for(id)
	if e.is_empty(): return 1.0
	return smoothstep(0.45, 1.65, float(e.age) - index * 0.035)

func character_tint(index: int) -> Color:
	if events.is_empty(): return Color.WHITE
	var e: Dictionary = dominant_event()
	var age = float(e.age) - 0.22 - index * 0.035
	var pulse = sin(clampf(age / 1.65, 0, 1) * PI) * 0.38
	return Color.WHITE.lerp(COLORS[e.id], pulse)

func paint_world(g, stage, foreground: bool) -> void:
	var canvas: Node2D = g.paint_target
	var center = Vector2(HordeRun.ANCHOR - (mini(stage.preview.members.size(), 6) - 1) * 17.5, HordeRun.FLOOR - 57)
	if not events.is_empty(): ritual.paint(g, stage, dominant_event(), foreground)
	if not foreground:
		# Small, quiet sparks retain a hint of every armed bonus after the burst.
		for n in range(g.data.prepared_items.size()):
			var id: String = g.data.prepared_items[n]
			var color: Color = COLORS[id]
			var angle = stage.clock * (0.6 + n * 0.025) + n * 2.4
			var point = center + Vector2(cos(angle) * 42, sin(angle) * 24)
			canvas.draw_circle(point, 9, color * Color(1, 1, 1, 0.045))
			canvas.draw_circle(point, 1.7, color * Color(1, 1, 1, 0.55))
		if "power_boost" in g.data.prepared_items:
			for n in range(4):
				var point = center + Vector2(-40 - n * 9, 12 + n * 8)
				canvas.draw_line(point - Vector2(26 + sin(stage.clock * 12 + n) * 7, 0), point, Color(1, 0.37, 0.25, 0.28), 2.5, true)
	for e in events:
		if e.id == "double_horde": continue
		var age = float(e.age) - 0.22
		if age < 0: continue
		var t = clampf(age / (duration(e.id) - 0.25), 0, 1)
		var fade = sin(t * PI) * (1.0 - t * 0.65)
		var color: Color = COLORS[e.id]
		if not foreground:
			canvas.draw_circle(center, 28 + t * 30, color * Color(1, 1, 1, fade * 0.08))
			canvas.draw_arc(center, 10 + t * 64, 0, TAU, 48, color * Color(1, 1, 1, fade * 0.55), 2.2, true)
			continue
		match e.id:
			"civil_pack":
				for n in range(6):
					var angle = n * TAU / 6 + t * 4
					var point = center + Vector2(cos(angle) * (56 - t * 30), sin(angle) * 28 - t * 17)
					g.animated_soul(point, 15 + sin(t * PI) * 7, stage.clock + n, color * Color(1, 1, 1, fade))
			"coin_bombs", "coin_cars", "double_coins":
				for n in range(10):
					var angle = n * TAU / 10 - PI * 0.5
					var point = center + Vector2(cos(angle) * (15 + t * 70), sin(angle) * (15 + t * 48) - t * 15)
					if e.id == "coin_cars":
						point += Vector2(sin(n * 2.4 + t * 5) * 12, 0)
						canvas.draw_line(point - Vector2(5, -7), point + Vector2(2, 5), color * Color(1, 1, 1, fade), 2, true)
					if n % 2 == 0 or e.id == "double_coins":
						g.scenery.sprite(canvas, g.art.items[1], point, 13 + sin(t * PI) * 5, Color(1, 1, 1, fade), t * 2 + n)
					else: canvas.draw_circle(point, 2.2, color * Color(1, 1, 1, fade))
			"bonus_time":
				var radius = 28 + t * 18
				canvas.draw_arc(center, radius, 0, TAU, 48, color * Color(1, 1, 1, fade), 2, true)
				for n in range(12):
					var direction = Vector2.from_angle(n * TAU / 12)
					canvas.draw_line(center + direction * (radius - 4), center + direction * radius, color * Color(1, 1, 1, fade), 1.5, true)
				canvas.draw_line(center, center + Vector2.from_angle(t * 9 - PI / 2) * 22, color * Color(1, 1, 1, fade), 2, true)
				canvas.draw_line(center, center + Vector2.from_angle(t * 3 - PI / 2) * 13, color * Color(1, 1, 1, fade), 3, true)
			"power_mask":
				for n in range(3):
					var point = center + Vector2(-38 + n * 25, -24 + n * 10)
					canvas.draw_line(point + Vector2(-12, -22) * t, point + Vector2(17, 24) * t, color * Color(1, 1, 1, fade), 3.5, true)
			"power_fly":
				for n in range(8):
					var angle = n * TAU / 8 + t * 5
					var point = center + Vector2(cos(angle) * 50, sin(angle) * 32)
					canvas.draw_arc(point, 6 + t * 7, angle, angle + PI, 12, color * Color(1, 1, 1, fade), 2, true)
			"power_shield":
				for n in range(3):
					canvas.draw_arc(center, 36 + n * 6 + t * 15, t * 4 + n * TAU / 3, t * 4 + n * TAU / 3 + 1.8, 24, color * Color(1, 1, 1, fade), 2.8, true)
			"power_boost":
				for n in range(9):
					var point = center + Vector2(14 - t * 75 - n * 3, -40 + n * 10)
					canvas.draw_line(point - Vector2(24 + t * 40, 0), point, color * Color(1, 1, 1, fade), 2.5, true)

func paint_ui(g, stage) -> void:
	if events.is_empty(): return
	var last: Dictionary = dominant_event()
	var age: float = last.age
	var end = duration(last.id)
	if age < 0.3: return
	var alpha = smoothstep(0.3, 0.65, age) * (1.0 - smoothstep(end - 0.45, end, age))
	var point: Vector2 = g.world_to_ui(Vector2(HordeRun.ANCHOR + 100, HordeRun.FLOOR - 96))
	point.y -= sin(clampf(age / end, 0, 1) * PI) * 8
	var title: String = "DESPERTANDO A HORDA" if last.id == "double_horde" and age < 2.1 else LABELS[last.id]
	g.home_menu.label(g, title, point, 19, COLORS[last.id] * Color(1, 1, 1, alpha), false, 340, true, 3)

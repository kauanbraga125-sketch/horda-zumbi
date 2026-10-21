extends RefCounted

const MIST = preload("res://scripts/prepare_mist.gdshader")
var back: Node2D
var front: Node2D
var mist_rect = Rect2()

func attach(g) -> void:
	if is_instance_valid(back): return
	back = Node2D.new();back.name = "RitualMistBack";back.visible = false
	front = Node2D.new();front.name = "RitualMistFront";front.visible = false
	for node in [back, front]:
		var material = ShaderMaterial.new();material.shader = MIST;node.material = material
	back.draw.connect(draw_mist.bind(g, false));front.draw.connect(draw_mist.bind(g, true))
	g.world_canvas.add_child(back);g.world_canvas.move_child(back, 0)
	g.foreground_canvas.add_child(front)

func configure(g, stage) -> void:
	if not is_instance_valid(back): return
	var active = g.screen == "prepare" and not stage.feedback.events.is_empty()
	back.visible = active;front.visible = active
	if not active: return
	var event: Dictionary = stage.feedback.dominant_event()
	var age: float = event.age
	var duration: float = stage.feedback.duration(event.id)
	var strength = smoothstep(0.05, 0.65, age) * (1.0 - smoothstep(duration - 0.8, duration, age))
	var left: float = HordeRun.ANCHOR
	for i in range(stage.preview.members.size()): left = minf(left, stage.preview.slot_x(i))
	mist_rect = Rect2(left - 83, HordeRun.FLOOR - 190, HordeRun.ANCHOR - left + 175, 212)
	for node in [back, front]:
		node.material.set_shader_parameter("age", age)
		node.material.set_shader_parameter("strength", strength)
		node.material.set_shader_parameter("ritual_color", stage.feedback.COLORS[event.id])
		node.material.set_shader_parameter("front_layer", 1.0 if node == front else 0.0)
		node.queue_redraw()

func draw_mist(_g, foreground: bool) -> void:
	var node: Node2D = front if foreground else back
	node.draw_rect(mist_rect, Color.WHITE)

static func spawn_pose(event: Dictionary, index: int) -> Dictionary:
	var pose = {"alpha":1.0, "offset":Vector2.ZERO, "state":"run", "landing":0.0, "air_age":-1.0, "speed":0.0, "echo":0.0, "local":5.0}
	if event.is_empty() or index < int(event.old_count): return pose
	var local = float(event.age) - 0.43 - (index - int(event.old_count)) * 0.13
	var reveal = smoothstep(0.18, 1.21, local)
	var jump = clampf((local - 0.20) / 1.05, 0, 1)
	pose.alpha = reveal
	pose.offset = Vector2((1.0 - reveal) * 19, -sin(jump * PI) * 9)
	pose.echo = sin(clampf(local / 1.30, 0, 1) * PI) * 0.30
	pose.local = local
	if local < 0.80:
		pose.state = "rise";pose.air_age = maxf(0, local - 0.20);pose.speed = -80.0
	elif local < 1.20:
		pose.state = "fall";pose.air_age = local;pose.speed = 110.0
	elif local < 1.44:
		pose.landing = maxf(0, 1.40 - local)
	return pose

static func reaction_pose(event: Dictionary, index: int) -> Dictionary:
	var pose = spawn_pose({}, index)
	if event.is_empty(): return pose
	var local = float(event.age) - 0.12 - index * 0.035
	if local >= 0 and local < 0.42:
		pose.state = "push"
	elif local >= 0.42 and local < 1.05:
		var hop = (local - 0.42) / 0.63
		pose.offset.y = -sin(hop * PI) * 4
		if local > 0.88: pose.landing = maxf(0, 1.05 - local)
	return pose

static func ellipse(canvas: Node2D, center: Vector2, radius: float, angle: float, color: Color, width: float = 1.5, arc: float = TAU) -> void:
	var points = PackedVector2Array()
	for n in range(49):
		var a = angle + arc * n / 48.0
		points.append(center + Vector2(cos(a) * radius, sin(a) * radius * 0.27))
	canvas.draw_polyline(points, color, width, true)

func paint(g, stage, event: Dictionary, foreground: bool) -> void:
	var age: float = event.age
	var duration: float = stage.feedback.duration(event.id)
	var envelope = smoothstep(0.03, 0.50, age) * (1.0 - smoothstep(duration - 0.65, duration, age))
	if envelope <= 0: return
	var color: Color = stage.feedback.COLORS[event.id]
	var count: int = stage.preview.members.size()
	var center = Vector2(HordeRun.ANCHOR - (mini(count, 6) - 1) * 17.5, HordeRun.FLOOR - 2)
	var canvas: Node2D = g.paint_target
	# Two ribbons wrap each body in depth, then unwind as the creature settles.
	for i in range(count):
		var rise = age - 0.13 - i * 0.045
		var shine = smoothstep(0.10, 0.65, rise) * (1.0 - smoothstep(1.80, 2.55, rise))
		var height = 112.0 * (1.4 if stage.selected(g, "power_mask") and int(g.data.power_levels.get("mask_size", 0)) > 0 else 1.0)
		var top = smoothstep(0.12, 1.25, rise)
		var x: float = stage.preview.slot_x(i)
		for ribbon in range(2):
			for n in range(15):
				var y1 = n / 15.0 * top
				var y2 = (n + 1) / 15.0 * top
				var angle = age * 4.2 + y1 * TAU * 1.15 + ribbon * PI + i * 0.4
				if (sin(angle) > 0) != foreground: continue
				var a = Vector2(x + cos(angle) * (24 - y1 * 8), HordeRun.FLOOR - y1 * height)
				var b = Vector2(x + cos(angle + (y2 - y1) * TAU * 1.15) * (24 - y2 * 8), HordeRun.FLOOR - y2 * height)
				var hue: Color = color.lerp(Color("d8afff"), 0.50 if ribbon else 0.0)
				canvas.draw_line(a, b, hue * Color(1, 1, 1, shine * (0.58 if foreground else 0.25)), 2.2 - y1 * 0.8, true)
	if not foreground:
		var spread = 42.0 + minf(count - 1, 7) * 13.0
		for n in range(3):
			var radius = (spread + n * 11) * (0.55 + smoothstep(0.02, 0.50, age) * 0.45)
			ellipse(canvas, center, radius, age * (0.65 if n % 2 == 0 else -0.8), color * Color(1, 1, 1, envelope * (0.50 - n * 0.11)), 2.1 if n == 0 else 1.1)
		for n in range(9):
			var angle = n * TAU / 9 + age * 0.35
			var p = center + Vector2(cos(angle) * (spread + 8), sin(angle) * (spread + 8) * 0.27)
			var direction = Vector2(cos(angle), sin(angle) * 0.27)
			canvas.draw_polyline(PackedVector2Array([p - direction * 4 + Vector2(0, -3), p + direction * 4, p - direction * 4 + Vector2(0, 3)]), color * Color(1, 1, 1, envelope * 0.7), 1.4, true)
		# Light climbs each body, including members at the back of an upgraded horde.
		for i in range(count):
			var x: float = stage.preview.slot_x(i)
			var delay = 0.10 + i * 0.035
			var pulse = sin(clampf((age - delay) / 1.65, 0, 1) * PI)
			var base = Vector2(x, HordeRun.FLOOR)
			canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-19, 0), base + Vector2(-8, -126), base + Vector2(9, -126), base + Vector2(23, 0)]), color * Color(1, 1, 1, pulse * 0.085))
			if event.id == "double_horde" and i >= int(event.old_count):
				var pose = spawn_pose(event, i)
				var local: float = pose.local
				var open = smoothstep(-0.12, 0.40, local) * (1.0 - smoothstep(1.55, 2.10, local))
				ellipse(canvas, base, 25 + sin(maxf(0, local) * 3.0) * 4, -age * 1.5, color * Color(1, 1, 1, open * 0.85), 2.5)
		return
	for i in range(count):
		var x: float = stage.preview.slot_x(i)
		var sweep = clampf((age - 0.15 - i * 0.04) / 1.45, 0, 1)
		var pulse = sin(sweep * PI) * envelope
		var point = Vector2(x + sin(age * 5 + i) * 17, HordeRun.FLOOR - sweep * 110)
		canvas.draw_line(point - Vector2(5, 0), point + Vector2(5, 0), color * Color(1, 1, 1, pulse * 0.9), 1.8, true)
		canvas.draw_line(point - Vector2(0, 5), point + Vector2(0, 5), Color(0.92, 1, 0.94, pulse), 1.4, true)
		if event.id != "double_horde" or i < int(event.old_count): continue
		var pose = spawn_pose(event, i)
		var local: float = pose.local
		var flare = sin(clampf((local - 1.15) / 0.65, 0, 1) * PI)
		if flare > 0:
			var base = Vector2(x, HordeRun.FLOOR)
			ellipse(canvas, base, 18 + maxf(0, local - 1.15) * 55, 0, color * Color(1, 1, 1, flare * 0.7), 1.8)
		for n in range(5):
			var q = clampf((local - 0.18 - n * 0.07) / 1.25, 0, 1)
			var alpha = sin(q * PI) * envelope
			var angle = age * 4 + n * TAU / 5 + i
			var p = Vector2(x + cos(angle) * (22 - q * 8), HordeRun.FLOOR - q * 117)
			g.animated_soul(p, 12 + sin(q * PI) * 5, stage.clock + n * 0.2, color * Color(1, 1, 1, alpha * 0.9))

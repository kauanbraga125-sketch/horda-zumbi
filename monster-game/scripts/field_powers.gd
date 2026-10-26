extends RefCounted
## One flying helper at a time. Civilians become normal captureable entities.
var kind = -1
var left = 0.0
var duration = 0.0
var interval = 6.0
var next_pass = .5
var pass_age = -1.0
var delivered = false
var deliveries = 0
var charges = 0
var art = preload("res://scripts/adventure_art.gd").new()

func active() -> bool: return left > 0 or pass_age >= 0

func reset() -> void:
	kind = -1;left = 0;pass_age = -1;deliveries = 0;charges = 0;delivered = false

func begin(r, value: int) -> void:
	reset();kind = value
	duration = 16.0 + 4.0 * int(r.power_levels.get("creeper_time",0)) if kind == 5 else 8.0 + 2.0 * int(r.power_levels.get("spectral_time",0))
	left = duration;interval = 6.0 - .75 * clampi(int(r.power_levels.get("creeper_rate",0)),0,3);next_pass = .45;charges = 2 if kind == 6 else 0
	r.events.append({"type":"field_power","kind":kind,"title":"CAÇADOR NOTURNO" if kind == 5 else "MANTO ESPECTRAL"})

func guard(r, point: Vector2) -> bool:
	if kind != 6 or left <= 0 or charges <= 0: return false
	charges -= 1
	if charges == 0: left = 0
	r.events.append({"type":"spectral_guard","x":point.x,"y":point.y});return true

func advance(r, dt: float) -> void:
	if not active() or r.space.active: return
	left = maxf(0,left-dt)
	if kind != 5: return
	if pass_age < 0:
		next_pass -= dt
		if next_pass <= 0 and left > 0 and not r.inside_tunnel(): pass_age = 0;delivered = false
		return
	pass_age += dt
	if pass_age >= 1.25 and not delivered:
		delivered = true;drop_civilian(r)
	if pass_age >= 2.6:
		pass_age = -1;next_pass = maxf(.3,interval-2.6)

func drop_civilian(r) -> void:
	var lead = r.leader_index()
	if lead < 0: return
	var x = float(r.members[lead].x) + r.speed * .65
	for step in range(12):
		var candidate = x + step * 45
		if not r.has_floor(candidate): continue
		var blocked = false
		for e in r.entities:
			if not e.taken and (MonsterCatalog.VEHICLES.has(e.kind) or e.kind in ["bomb","spikes","collapse"]) and absf(candidate-float(e.x)) < float(e.width)*.5+75: blocked = true;break
		if blocked: continue
		var e = r.add_entity("civilian",candidate,r.ground_y(candidate)-220,0)
		e.airdrop = true;e.rescued_civil = true;e.drop_at = r.elapsed;e.drop_vy = -55.0;e.vx = 40.0;e.pose = "panic";e.speaker = false;e.speech_left = 0
		deliveries += 1;r.events.append({"type":"civil_drop","x":candidate,"y":e.y});return

func paint(g, front: bool = true) -> void:
	if not active(): return
	if (kind==5 and front) or (kind==6 and not front): return
	var r = g.runner;var c = g.paint_target
	if kind == 5 and pass_age >= 0:
		var lead = r.leader_index()
		if lead < 0: return
		var target = float(r.members[lead].x)+120
		var x = lerpf(r.view_left-210,target,smoothstep(0,1.25,pass_age)) if pass_age < 1.25 else lerpf(target,r.view_right+230,smoothstep(1.25,2.6,pass_age))
		var y = r.ground_y(x)-235 + sin(pass_age*PI/2.6)*-42
		var frame = [0,1,2,1][posmod(int(pass_age*7),4)] if pass_age < 1.16 else (4 if pass_age < 1.25 else 6)
		art.sprite(c,"helpers",frame,Vector2(x,y),225,sin(pass_age*3)*.04)
	elif kind == 6:
		var lead = r.leader_index()
		if lead < 0: return
		var point = Vector2(r.members[lead].x-90,r.members[lead].y-90)
		art.sprite(c,"helpers",8+posmod(int(r.elapsed*6),4),point,112,sin(r.elapsed*2)*.07)
		for m in r.members:
			if not m.falling: c.draw_arc(Vector2(m.x,m.y-53),59,-2.5,1.2,24,Color(.4,1,1,.22),2,true)

func paint_hud(g, rect: Rect2) -> void:
	g.home_menu.slab(g,rect,Color("273044"),g.MINT,12,3)
	art.power(g.paint_target,kind,rect.position+Vector2(37,39),62,g.ui_time)
	g.home_menu.label(g,"CAÇADOR NOTURNO" if kind == 5 else "MANTO ESPECTRAL",rect.position+Vector2(75,27),18,g.MINT,false,rect.size.x-84)
	var note = "%d s • PASSAGENS %.2f s" % [ceili(left),interval] if kind == 5 else "%d s • %d PROTEÇÕES" % [ceili(left),charges]
	g.home_menu.label(g,note,rect.position+Vector2(75,54),17,g.CREAM,false,rect.size.x-84)

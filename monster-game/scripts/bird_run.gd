extends RefCounted
const Catalog = preload("res://scripts/bird_catalog.gd")
const Art = preload("res://scripts/bird_art.gd")
var id = ""
var level = 0
var clock = 0.0
var cooldown = 0.0
var emotion_left = 0.0
var rescued = false
var perfects = 0
var attacks = 0
var point = Vector2(300,350)
var target = Vector2.ZERO
var beam_left = 0.0
var warned = Vector2.ZERO
var watched: Dictionary = {}
var chirp_at = 8.0

func configure(data: Dictionary) -> void:
	id = str(data.get("bird_equipped",""));level = Catalog.level(data,id)
	if level<=0: id = ""
	watched.clear();chirp_at = 8.0
	clock = 0;cooldown = 8 if id=="ferrugem" else 2;emotion_left = 0;rescued = false;perfects = 0;attacks = 0;beam_left = 0;warned = Vector2.ZERO

func advance(r,dt: float) -> void:
	if id.is_empty(): return
	clock += dt;cooldown = maxf(0,cooldown-dt);emotion_left = maxf(0,emotion_left-dt);beam_left = maxf(0,beam_left-dt)
	var lead = r.leader_index()
	if lead>=0:
		var m = r.members[lead];var desired = Vector2(m.x-55,m.y-155)
		if r.sewer.active: desired.y -= 30
		point = desired if clock<=dt*1.5 else point.lerp(desired,1-exp(-dt*6))
	if emotion_left>0 and not watched.is_empty(): warned = Vector2(watched.x,watched.y)
	if (r.space.active and r.space.phase!="flight") or (r.sewer.active and r.sewer.phase!="ride"): return
	if clock>=chirp_at:
		chirp_at = clock+10+Catalog.tier(id)*1.3;r.events.append({"type":"bird_chirp"})
	if id=="fiapo" and cooldown<=0:
		var e = find_target(r)
		if not e.is_empty():
			watched = e;warned = Vector2(e.x,e.y);emotion_left = 1.4;cooldown = 22-(level-1)*4
			r.events.append({"type":"bird_warn","x":e.x,"y":e.y})
	elif id=="ferrugem" and cooldown<=0:
		if attack(r): cooldown = 30-(level-1)*4
	elif id=="barao" and perfects>=6-level and attacks<3 and cooldown<=0:
		if attack(r): perfects = 0;attacks += 1;cooldown = 12

func find_target(r) -> Dictionary:
	var candidates = r.space.objects if r.space.active else r.sewer.objects if r.sewer.active else r.entities
	var from = r.space.x if r.space.active else r.ANCHOR
	var result: Dictionary = {};var best = 850.0
	for e in candidates:
		if e.taken or e.get("bird_weakened",false) or e.get("state","") not in ["normal",""]: continue
		if e.kind not in ["bomb","air_bomb","crate","spikes","bullet","car","bus","truck","tank","plane","moto","meteor","rock","satellite","parasite","shot","fighter","cargo","saucer","tour_bus","ghost_frigate","rubble","barrel","pipe","gate"]: continue
		var delta = float(e.x)-from
		if delta>100 and delta<best and e.x<r.view_right-40: best = delta;result = e
	return result

func attack(r) -> bool:
	var e = find_target(r)
	if e.is_empty() or e.kind in ["pipe","gate"]: return false
	target = Vector2(e.x,e.y);emotion_left = 1.0;beam_left = .38
	if r.space.active and r.space.battle.SHIPS.has(e.kind): r.space.battle.hit_ship(r.space,r,e,1)
	elif not r.sewer.active and MonsterCatalog.VEHICLES.has(e.kind):
		e.required_count = maxi(1,int(e.required_count)-2);e.bird_weakened = true
	else: e.taken = true
	r.events.append({"type":"bird_attack","x":target.x,"y":target.y})
	return true

func on_perfect(r) -> void:
	if id.is_empty(): return
	perfects += 1;emotion_left = .9
	if id=="pipoco":
		r.coins += level
		r.events.append({"type":"coin","amount":level,"x":point.x,"y":point.y,"bird_bonus":true})

func prevent_loss(r,m: Dictionary,_cause: String) -> bool:
	if id!="agourinho" or rescued: return false
	rescued = true;emotion_left = 1.6;target = Vector2(m.x,m.y);beam_left = .7
	m.falling = false;m.vy = 0;m.hurt_left = 0;m.glide_left = 1.0
	if not r.space.active and not r.sewer.active:
		var safe_x = r.ANCHOR
		for offset in range(0,700,35):
			if r.has_floor(r.ANCHOR+offset): safe_x = r.ANCHOR+offset;break
		m.x = safe_x;m.y = r.ground_y(safe_x)
	r.hit_grace = maxf(r.hit_grace,1.0+(level-1)*.5);r.cached_active = -1
	r.events.append({"type":"bird_rescue","x":m.x,"y":m.y-50})
	return true

func paint(g) -> void:
	if id.is_empty(): return
	var c = g.paint_target
	if beam_left>0:
		var color = Catalog.COLORS[Catalog.tier(id)]
		c.draw_line(point,target,Color(color,beam_left*1.2),2.5,true)
		c.draw_arc(target,14+(1-beam_left)*15,0,TAU,18,Color(color,beam_left),2,true)
	if id=="fiapo" and emotion_left>0 and warned!=Vector2.ZERO:
		c.draw_arc(warned,42,-PI*.9,-PI*.1,14,Color(1,.77,.36,emotion_left*.5),2,true)
	Art.paint(c,id,point,82 if id=="barao" else 68,clock,"ability" if emotion_left>0 else "")

extends RefCounted
const Catalog = preload("res://scripts/bird_catalog.gd")
const Art = preload("res://scripts/bird_art.gd")
var pipoco = preload("res://scripts/pipoco_power.gd").new()
var fiapo = preload("res://scripts/fiapo_power.gd").new()
var ferrugem = preload("res://scripts/ferrugem_power.gd").new()
var agourinho = preload("res://scripts/agourinho_power.gd").new()
var companion
var slot_index = 0
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
	var slots: Array = Catalog.equipped_slots(data)
	id = str(slots[0]);level = Catalog.level(data,id) if Catalog.available(data,id) else 0
	companion = null
	if slots.size()>1 and not str(slots[1]).is_empty() and slots[0]!=slots[1]:
		companion = load("res://scripts/bird_run.gd").new();companion.slot_index = 1
		var other = data.duplicate(true);other.bird_equipped_slots = [slots[1],""];other.bird_equipped = slots[1]
		companion.configure(other)
	if level<=0: id = ""
	pipoco.reset(level)
	fiapo.reset(level)
	ferrugem.reset(level)
	agourinho.reset()
	# Warm the action texture during the intro, not on the first spit.
	if id=="pipoco":Art.spit_texture()
	if id=="ferrugem":Art.laser_texture()
	if id=="agourinho":Art.texture("agourinho");Art.ritual_texture();Art.portal_texture()
	watched.clear();chirp_at = 8.0
	clock = 0;cooldown = 2;emotion_left = 0;rescued = false;perfects = 0;attacks = 0;beam_left = 0;warned = Vector2.ZERO

func advance(r,dt: float) -> void:
	if companion!=null: companion.advance(r,dt)
	if id.is_empty(): return
	clock += dt;cooldown = maxf(0,cooldown-dt);emotion_left = maxf(0,emotion_left-dt);beam_left = maxf(0,beam_left-dt)
	var lead = r.leader_index()
	if lead>=0:
		var m = r.members[lead];var desired = Vector2(m.x-55-slot_index*80,m.y-155-slot_index*34)
		if r.sewer.active: desired.y -= 30
		point = desired if clock<=dt*1.5 else point.lerp(desired,1-exp(-dt*6))
	if emotion_left>0 and not watched.is_empty(): warned = Vector2(watched.x,watched.y)
	if id=="pipoco":pipoco.advance(self,r,dt)
	if id=="fiapo":fiapo.advance(self,r,dt)
	if id=="ferrugem":ferrugem.advance(self,r,dt)
	if id=="agourinho":agourinho.advance(r,dt)
	if r.sky.active or (r.space.active and r.space.phase!="flight") or (r.sewer.active and r.sewer.phase!="ride"): return
	if clock>=chirp_at:
		chirp_at = clock+10+Catalog.tier(id)*1.3;r.events.append({"type":"bird_chirp","bird":id})
	if id=="barao" and perfects>=6-level and attacks<3 and cooldown<=0:
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
	if companion!=null: companion.on_perfect(r)
	if id.is_empty(): return
	perfects += 1;emotion_left = .9

func prepare_last_chance(r,m: Dictionary) -> bool:
	if companion!=null and companion.prepare_last_chance(r,m): return true
	if id!="agourinho" or rescued or not agourinho.last_member(r,m): return false
	rescued = true;emotion_left = 0;beam_left = 0;agourinho.begin(self,r,m)
	return true

func rescue_pending() -> bool:
	return (id=="agourinho" and agourinho.phase=="ritual") or (companion!=null and companion.rescue_pending())

func advance_ritual(r,dt: float) -> bool:
	if not rescue_pending():return false
	clock += dt
	if companion!=null and companion.rescue_pending():companion.advance_ritual(r,dt)
	elif id=="agourinho":agourinho.advance(r,dt)
	return true

func cancel_ritual(r) -> void:
	if companion!=null:companion.cancel_ritual(r)
	if agourinho.phase=="ritual":
		agourinho.phase = "spent";agourinho.saved = {}
		var m = r.member_by_id(agourinho.member_id)
		if not m.is_empty():m.agourinho_hidden = false

func paint(g) -> void:
	if companion!=null: companion.paint(g)
	if id.is_empty(): return
	if id=="pipoco":pipoco.paint(g,self);return
	if id=="fiapo":fiapo.paint(g,self);return
	if id=="ferrugem":ferrugem.paint(g,self);return
	if id=="agourinho":agourinho.paint(g,self);return
	var c = g.paint_target
	if beam_left>0:
		var color = Catalog.COLORS[Catalog.tier(id)]
		c.draw_line(point,target,Color(color,beam_left*1.2),2.5,true)
		c.draw_arc(target,14+(1-beam_left)*15,0,TAU,18,Color(color,beam_left),2,true)
	if id=="fiapo" and emotion_left>0 and warned!=Vector2.ZERO:
		c.draw_arc(warned,42,-PI*.9,-PI*.1,14,Color(1,.77,.36,emotion_left*.5),2,true)
	Art.paint(c,id,point,82 if id=="barao" else 68,clock,"ability" if emotion_left>0 else "")

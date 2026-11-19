extends RefCounted
const Catalog = preload("res://scripts/bird_catalog.gd")
const Art = preload("res://scripts/bird_art.gd")
const BaraoArt = preload("res://scripts/barao_art.gd")
const TocTocArt = preload("res://scripts/toc_toc_art.gd")
var pipoco = preload("res://scripts/pipoco_power.gd").new()
var fiapo = preload("res://scripts/fiapo_power.gd").new()
var ferrugem = preload("res://scripts/ferrugem_power.gd").new()
var agourinho = preload("res://scripts/agourinho_power.gd").new()
var barao = preload("res://scripts/barao_power.gd").new()
var toc_toc = preload("res://scripts/toc_toc_power.gd").new()
var companion
var slot_index = 0
var id = ""
var level = 0
var clock = 0.0
var emotion_left = 0.0
var rescued = false
var attacks = 0
var point = Vector2(300,350)
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
	barao.reset()
	toc_toc.reset()
	# Load action textures before the first cast.
	if id=="pipoco":Art.spit_texture()
	if id=="ferrugem":Art.laser_texture()
	if id=="agourinho":Art.texture("agourinho");Art.ritual_texture();Art.portal_texture()
	if id=="barao":BaraoArt.warm()
	if id=="toc_toc":TocTocArt.warm()
	chirp_at = 8.0
	clock = 0;emotion_left = 0;rescued = false;attacks = 0

func advance(r,dt: float) -> void:
	# Apply the multiplier before either bird checks its coin contacts.
	if companion!=null and id!="barao":companion.advance(r,dt)
	if id.is_empty(): return
	clock += dt;emotion_left = maxf(0,emotion_left-dt)
	var lead = r.leader_index()
	if lead>=0:
		var m = r.members[lead];var desired = Vector2(m.x-55-slot_index*80,m.y-155-slot_index*34)
		if r.sewer.active: desired.y -= 30
		point = desired if clock<=dt*1.5 else point.lerp(desired,1-exp(-dt*6))
	if id=="pipoco":pipoco.advance(self,r,dt)
	if id=="fiapo":fiapo.advance(self,r,dt)
	if id=="ferrugem":ferrugem.advance(self,r,dt)
	if id=="agourinho":agourinho.advance(r,dt)
	if id=="toc_toc":toc_toc.advance(self,r,dt)
	if id=="barao":
		barao.advance(self,r,dt)
		if companion!=null:companion.advance(r,dt)
	if r.sky.active or (r.space.active and r.space.phase!="flight") or (r.sewer.active and r.sewer.phase!="ride"): return
	if id!="toc_toc" and clock>=chirp_at:
		chirp_at = clock+10+Catalog.tier(id)*1.3;r.events.append({"type":"bird_chirp","bird":id})

func coin_multiplier() -> int:
	if id=="barao" and barao.doubles_coins():return 2
	return companion.coin_multiplier() if companion!=null else 1

func coin_scale() -> float:
	if id=="barao":return barao.coin_scale()
	return companion.coin_scale() if companion!=null else 1.0

func on_perfect(r) -> void:
	if companion!=null: companion.on_perfect(r)
	if id=="barao":emotion_left = .9

func prepare_last_chance(r,m: Dictionary) -> bool:
	if companion!=null and companion.prepare_last_chance(r,m): return true
	if id!="agourinho" or rescued or not agourinho.last_member(r,m): return false
	rescued = true;agourinho.begin(self,r,m)
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
	if id=="toc_toc":toc_toc.paint(g,self);return
	if id=="barao":barao.paint(g,self)

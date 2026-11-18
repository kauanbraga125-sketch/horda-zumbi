extends "res://scripts/bird_coin_flight.gd"
## Bounded collectible coins; never enter course/Perfect rows or consume run RNG.
const Art = preload("res://scripts/bird_art.gd")
const RELEASES = [.50,.69]
const DURATION = 1.32
const MAX_SPARKS = 16
var until_spit = 24.0
var action_age = -1.0
var released = 0
var cycles = 0
var sparks: Array[Dictionary] = []

func reset(level: int) -> void:
	until_spit = interval(level);action_age = -1;released = 0;cycles = 0;mode = ""
	coins.clear();sparks.clear()

static func interval(level: int) -> float:return 24.0-(clampi(level,1,3)-1)*4.0

func advance(bird,r,dt: float) -> void:
	if dt<=0 or r.dead or r.leader_index()<0:return
	var current = mode_of(r)
	if current!=mode:
		# No offscreen reward teleport or hidden payout on scene transitions.
		coins.clear();sparks.clear()
		if action_age>=0:action_age = -1;until_spit = maxf(until_spit,2.0)
		mode = current
	if current not in ["street","sewer","space"] or r.transform_left>0:return
	until_spit = maxf(0,until_spit-dt)
	advance_coins(r,dt)
	for i in range(sparks.size()-1,-1,-1):
		var s = sparks[i];s.age += dt;s.point += s.velocity*dt;s.velocity.y += 180*dt
		if s.age>=s.life:sparks.remove_at(i)
	if action_age<0:
		if until_spit<=0 and coins.size()<=MAX_COINS-RELEASES.size():
			action_age = 0;released = 0;cycles += 1;until_spit = interval(bird.level)
		return
	action_age += dt
	while released<RELEASES.size() and action_age>=RELEASES[released]:
		emit_coin(bird,r,released);released += 1
	if action_age>=DURATION:action_age = -1

func emit_coin(bird,r,index: int) -> void:
	if coins.size()>=MAX_COINS:return
	var nozzle = Art.spit_mouth(bird.point,action_age,68)
	var velocity = Vector2(270+index*72+bird.slot_index*90,-188-index*52)
	velocity.x = minf(velocity.x,maxf(90,(r.view_right-54-nozzle.x)/1.2))
	launch_coin(nozzle,velocity,index*1.7)
	for i in range(4):
		if sparks.size()>=MAX_SPARKS:break
		sparks.append({"point":nozzle,"velocity":Vector2(55+i*26,-60+i*25),"age":0.0,"life":.23+i*.035})
	if index==0:r.events.append({"type":"bird_spit","bird":"pipoco","x":nozzle.x,"y":nozzle.y})

func paint(g,bird) -> void:
	var c = g.paint_target
	paint_coins(g)
	for s in sparks:c.draw_circle(s.point,2.5*(1-s.age/s.life),Color(1,.83,.43,1-s.age/s.life))
	if action_age>=0:Art.paint_spit(c,bird.point,68,action_age)
	else:Art.paint(c,"pipoco",bird.point,68,bird.clock)

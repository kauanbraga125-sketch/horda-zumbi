extends RefCounted
## Bounded collectible coins; never enter course/Perfect rows or consume run RNG.
const Art = preload("res://scripts/bird_art.gd")
const RELEASES = [.50,.69]
const DURATION = 1.32
const MAX_COINS = 12
const MAX_SPARKS = 16
var until_spit = 24.0
var action_age = -1.0
var released = 0
var cycles = 0
var mode = ""
var coins: Array[Dictionary] = []
var sparks: Array[Dictionary] = []

func reset(level: int) -> void:
	until_spit = interval(level);action_age = -1;released = 0;cycles = 0;mode = ""
	coins.clear();sparks.clear()

static func interval(level: int) -> float:return 24.0-(clampi(level,1,3)-1)*4.0

func mode_of(r) -> String:
	if r.sky.active:return "sky"
	if r.space.active:return "space" if r.space.phase=="flight" else "space_transition"
	if r.sewer.active:return "sewer" if r.sewer.phase=="ride" else "sewer_transition"
	return "street"

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
	coins.append({"point":nozzle,"previous":nozzle,"velocity":velocity,"age":0.0,"bounces":0,"spin":index*1.7,"landed":false})
	for i in range(4):
		if sparks.size()>=MAX_SPARKS:break
		sparks.append({"point":nozzle,"velocity":Vector2(55+i*26,-60+i*25),"age":0.0,"life":.23+i*.035})
	if index==0:r.events.append({"type":"bird_spit","bird":"pipoco","x":nozzle.x,"y":nozzle.y})

func advance_coins(r,dt: float) -> void:
	# Swept contact plus bounded substeps handles slower devices without tunnelling.
	var steps = clampi(ceili(dt/(1.0/60)),1,12)
	var step = dt/steps
	for i in range(coins.size()-1,-1,-1):
		var coin = coins[i];var collected = false
		for unused in range(steps):
			coin.previous = coin.point;coin.age += step
			var v: Vector2 = coin.velocity
			v.y += (280.0 if mode=="space" else 720.0)*step
			if mode=="space" and coin.age>.40:v.x = move_toward(v.x,-210,step*650)
			if mode=="sewer" and coin.age>.42:v.x = move_toward(v.x,-r.sewer.scroll_speed(r)*.62,step*1400)
			var pos: Vector2 = coin.point+v*step
			if mode=="street" and r.has_floor(pos.x):
				var floor_y = r.ground_y(pos.x)-13
				if v.y>0 and coin.point.y<=floor_y+3 and pos.y>=floor_y:
					pos.y = floor_y
					if int(coin.bounces)<1:
						v.y = -minf(138,absf(v.y)*.29);coin.bounces += 1
					else:v.y = 0;coin.landed = true
					v.x = -r.speed
			if mode=="street" and coin.landed:
				v.x = -r.speed
				if r.has_floor(pos.x):pos.y = r.ground_y(pos.x)-13;v.y = 0
				else:coin.landed = false
			coin.point = pos;coin.velocity = v
			if float(coin.age)>.16 and touches(r,coin.previous,pos):
				r.coins += 1
				r.events.append({"type":"coin","amount":1,"x":pos.x,"y":pos.y,"bird_bonus":true})
				collected = true;break
		if collected or coin.age>=6 or coin.point.x<r.view_left-90 or coin.point.y>950:coins.remove_at(i)

func touches(r,from: Vector2,to: Vector2) -> bool:
	if mode=="sewer":
		for boat in r.sewer.boats:
			var center = Vector2(boat.x,boat.y-30)
			if Geometry2D.get_closest_point_to_segment(center,from,to).distance_squared_to(center)<=62*62:return true
		return false
	if mode=="space" and r.space.battle.pilot_left>0:
		var center = Vector2(r.space.x+25,r.space.y-48)
		return Geometry2D.get_closest_point_to_segment(center,from,to).distance_squared_to(center)<=80*80
	for member in r.members:
		if member.falling:continue
		var center = Vector2(member.x,member.y-(r.space.member_height(r)*.5 if mode=="space" else 48.0))
		if Geometry2D.get_closest_point_to_segment(center,from,to).distance_squared_to(center)<=54*54:return true
	return false

func paint(g,bird) -> void:
	var c = g.paint_target
	for coin in coins:
		var p: Vector2 = coin.point;var age = float(coin.age)
		var opacity = clampf((6-age)*3,0,1)
		if mode=="street" and g.runner.has_floor(p.x):
			var floor_y = g.runner.ground_y(p.x)
			var shadow = clampf(1-(floor_y-p.y)/220,.05,.36)*opacity
			c.draw_set_transform(Vector2(p.x,floor_y-1),0,Vector2(1,.24))
			c.draw_circle(Vector2.ZERO,13,Color(0,0,0,shadow));c.draw_set_transform(Vector2.ZERO)
		var flip = maxf(.16,absf(cos(age*9+float(coin.spin))))
		var diameter = 29.0*(.60+.40*smoothstep(0,.14,age))
		c.draw_set_transform(p,sin(age*3+float(coin.spin))*.12,Vector2(flip,1))
		c.draw_texture_rect(g.art.items[1],Rect2(-diameter*.5,-diameter*.5,diameter,diameter),false,Color(1,1,1,opacity))
		c.draw_set_transform(Vector2.ZERO)
		if fposmod(age*2.4+float(coin.spin),1)<.24:
			var offset = Vector2(10,-12)
			c.draw_line(p+offset-Vector2(4,0),p+offset+Vector2(4,0),Color(1,.92,.60,.7*opacity),1.5,true)
			c.draw_line(p+offset-Vector2(0,4),p+offset+Vector2(0,4),Color(1,.92,.60,.7*opacity),1.5,true)
	for s in sparks:c.draw_circle(s.point,2.5*(1-s.age/s.life),Color(1,.83,.43,1-s.age/s.life))
	if action_age>=0:Art.paint_spit(c,bird.point,68,action_age)
	else:Art.paint(c,"pipoco",bird.point,68,bird.clock)

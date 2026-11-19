extends RefCounted

const Art = preload("res://scripts/fuba_art.gd")
const START_SECONDS = 20.0
const EXTRA_SECONDS = 30.0
const GUST_SECONDS = .20
const RETURN_SECONDS = .61
const READY_BEAT = .72
const READY_GOLD = Color("ffe397")
enum Phase { IDLE, DIVE, LIFT, RETURN }

var remaining = START_SECONDS
var uses = 0
var phase = Phase.IDLE
var age = 0.0
var ready_age = -1.0
var member_id = -1
var dive_seconds = .22
var takeoff = Vector2.ZERO
var position = Vector2.ZERO
var return_from = Vector2.ZERO
var face = 1.0

func reset() -> void:
	remaining = START_SECONDS
	uses = 0
	ready_age = -1
	member_id = -1
	phase = Phase.IDLE
	age = 0

func on_street(r) -> bool:
	return not (r.sky.active or r.space.active or r.sewer.active or r.transform_left>0 or (r.perk_kind==3 and r.perk_left>0))

func aim(r,m: Dictionary) -> Vector2:
	var depth = r.member_depth(r.members.find(m))
	return Vector2(m.x-12,float(m.y)-depth+15)

func start_return() -> void:
	phase = Phase.RETURN
	age = 0
	return_from = position
	member_id = -1

func advance(bird,r,dt: float) -> void:
	remaining = maxf(0,remaining-dt)
	if remaining<.000001:remaining = 0
	if not on_street(r):
		phase = Phase.IDLE
		member_id = -1
		return
	if remaining==0:
		if ready_age<0:
			r.events.append({"type":"fuba_ready","x":bird.point.x,"y":bird.point.y-10})
			ready_age = 0
		else:
			ready_age += dt
	if phase==Phase.IDLE:return
	age += dt
	if phase==Phase.RETURN:
		if age>=RETURN_SECONDS:phase = Phase.IDLE
		return
	var m: Dictionary = r.member_by_id(member_id)
	if m.is_empty() or m.falling:
		start_return()
		return
	if phase==Phase.DIVE:
		position = dive_point(aim(r,m))
	else:
		position = aim(r,m)+Vector2(0,sin(age*TAU*9)*2)
		if age>=GUST_SECONDS:start_return()

func dive_point(target: Vector2) -> Vector2:
	var t = clampf(age/dive_seconds,0,1)
	return takeoff.lerp(target,t*t*(2-t))-Vector2(12*face,22)*sin(t*PI)

func descent_time(m: Dictionary,floor_y: float) -> float:
	var spread = bool(m.get("hold_open",false)) and float(m.air_time)<HordeBalance.MAX_HOLD-.1
	var gravity = (HordeBalance.HOLD_FALL_GRAVITY if spread else HordeBalance.GRAVITY)*float(m.jump_gravity_scale)
	var speed = float(m.vy)
	var height = maxf(0,floor_y-float(m.y))
	return 2*height/maxf(1,sqrt(speed*speed+2*gravity*height)+speed)

func time_to_rim(r,x: float,floor_y: float) -> float:
	for gap in r.physics_gaps:
		if gap.kind=="collapse" and not gap.get("collapsed",false):continue
		var rim = float(gap.x+gap.width)+3
		if x<=gap.x or x>=rim-3:continue
		if r.has_floor(rim) and r.ground_y(rim)>=floor_y-3:
			return (rim-x)/maxf(1,r.speed)
	return INF

func observe(bird,r,m: Dictionary,solid: bool,floor_y: float) -> void:
	if remaining>0 or ready_age<0 or phase in [Phase.LIFT,Phase.RETURN]:return
	var is_target = int(m.id)==member_id
	if phase==Phase.DIVE and not is_target:return
	var can_help = not solid and not m.falling and m.vy>0 and m.y<floor_y and m.air_jumps>0 and m.glide_left<=0
	if not can_help:
		if is_target:start_return()
		return
	var landing = descent_time(m,floor_y)
	var deficit = time_to_rim(r,m.x,floor_y)-landing
	if deficit<.022 or deficit>GUST_SECONDS-.012:
		if is_target:start_return()
		return
	if phase==Phase.DIVE:
		if age+.00001>=dive_seconds or landing<=.036:rescue(bird,r,m)
	elif landing>=.085 and landing<=.29:
		member_id = int(m.id)
		takeoff = Art.eye(bird.point,bird.clock)
		position = takeoff
		face = -1.0 if float(m.x)<takeoff.x-12 else 1.0
		dive_seconds = clampf(landing-.044,.07,.235)
		phase = Phase.DIVE
		age = 0
		r.events.append({"type":"fuba_dive","x":takeoff.x,"y":takeoff.y})

func rescue(bird,r,m: Dictionary) -> void:
	m.fuba_until = r.elapsed+GUST_SECONDS
	m.reform_hold_until = maxf(float(m.reform_hold_until),float(m.fuba_until))
	m.y -= 7
	position = aim(r,m)
	uses += 1
	bird.attacks += 1
	remaining = START_SECONDS+uses*EXTRA_SECONDS
	ready_age = -1
	phase = Phase.LIFT
	age = 0
	var foot = position+Vector2(12,-14)
	r.events.append({"type":"fuba_rescue","member":member_id,"x":foot.x,"y":foot.y,"next":remaining})

func paint_ready(c,head: Vector2,time: float) -> void:
	var shell_pos = head+Vector2(-3,-13)
	var pulse = .73+.27*sin(time*6.2)
	var star = shell_pos+Vector2(15,-13+pulse)
	c.draw_line(star-Vector2(3.3,0),star+Vector2(3.3,0),Color(READY_GOLD,.9*pulse),1.4,true)
	c.draw_line(star-Vector2(0,4.6),star+Vector2(0,4.6),Color(READY_GOLD,.9*pulse),1.4,true)
	if time>=READY_BEAT:return
	var t = time/READY_BEAT
	var alpha = sin(t*PI)
	c.draw_set_transform(shell_pos,-.14,Vector2(1,.58))
	c.draw_arc(Vector2.ZERO,13+t*26,.12,2.8,20,Color(READY_GOLD,alpha*.9),2,true)
	c.draw_arc(Vector2.ZERO,10+t*23,3.45,5.68,20,Color(READY_GOLD,alpha*.64),1.4,true)
	c.draw_set_transform(Vector2.ZERO)

func paint(g,bird) -> void:
	var c = g.paint_target
	var head = Art.eye(bird.point,bird.clock)
	if not on_street(g.runner):
		Art.paint_flight(c,bird.point,Art.SIZE,bird.clock)
		return
	match phase:
		Phase.DIVE:
			var p = clampf(age/dive_seconds,0,1)
			var target: Dictionary = g.runner.member_by_id(member_id)
			var pos = position if target.is_empty() else dive_point(aim(g.runner,target))
			if p>.13:
				for i in range(3):
					var back = Vector2(-9*face,-18)+Vector2((i-1)*8,0)
					c.draw_line(pos+back,pos+back*2.2,Color("ffe8ad",sin(p*PI)*(.69-i*.12)),1.5,true)
			Art.paint_power(c,3 if p<.38 else 4,pos,face*lerpf(-.12,.22,p),face)
		Phase.LIFT:
			var frame = 5 if age<.034 else 6 if age<.095 else 7 if age<.145 else 6
			Art.paint_power(c,frame,position,-.15*face,face)
		Phase.RETURN:
			var t = smoothstep(0,RETURN_SECONDS,age)
			var pos = return_from.lerp(head,t)-Vector2(0,29)*sin(t*PI)
			Art.paint_power(c,8 if age<.18 else [2,6,7][floori(age*19)%3],pos,-.14*sin(t*PI),face)
		_:
			if ready_age>=0 and ready_age<READY_BEAT:
				var p = ready_age/READY_BEAT
				head.y -= sin(p*PI)*9
				Art.paint_power(c,0 if p<.26 else 1 if p<.53 else 2,head,sin(p*TAU)*.055)
			else:
				var gag = fposmod(bird.clock,11)-4.8
				if gag>=0 and gag<Art.GAG_SECONDS and remaining+gag>=Art.GAG_SECONDS+.05:
					Art.paint_gag(c,bird.point,bird.clock,gag)
				else:
					Art.paint_flight(c,bird.point,Art.SIZE,bird.clock)
			if ready_age>=0:paint_ready(c,head,ready_age)

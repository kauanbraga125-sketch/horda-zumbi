extends "res://scripts/bird_coin_flight.gd"

const Art = preload("res://scripts/barao_art.gd")
const INTERVAL = 25.0
const DOUBLE_TIME = 8.0
const DROP_TIME = 2.35
const GOLD_TIME = 1.25
const CHARGE_TIME = .16
const BOLT_TIME = .26
const RELEASES = [.64,.78,.92,1.06,1.20,1.34]
const GOLD = Color("ffd16c")
const BRIGHT = Color("fff2be")
enum Power { NONE, DOUBLE, DROP, BOMBS }
const CAST_EVENTS = ["","barao_double","barao_trail","barao_bombs"]

var until_power = INTERVAL
var next_power = Power.DOUBLE
var active_power = Power.NONE
var power_age = 0.0
var bombs_ready = false
var released = 0
var converted: Array[Dictionary] = []

func reset() -> void:
	until_power = INTERVAL
	next_power = Power.DOUBLE
	active_power = Power.NONE
	power_age = 0
	bombs_ready = false
	released = 0
	mode = ""
	coins.clear()
	clear_conversions()

func advance(bird,r,dt: float) -> void:
	if dt<=0 or r.dead or r.leader_index()<0:return
	var current = mode_of(r)
	if current!=mode:
		coins.clear()
		clear_conversions()
		if active_power in [Power.DROP,Power.BOMBS]:active_power = Power.NONE
		mode = current
	if mode not in ["street","sewer","space"] or r.transform_left>0:return

	until_power = maxf(0,until_power-dt)
	if active_power!=Power.NONE:
		power_age += dt
		match active_power:
			Power.DOUBLE:
				if power_age>=DOUBLE_TIME:active_power = Power.NONE
			Power.DROP:
				while released<RELEASES.size() and power_age>=RELEASES[released]:
					drop_coin(bird,r,released)
					released += 1
				if power_age>=DROP_TIME:active_power = Power.NONE
			Power.BOMBS:
				advance_conversions(r)
				if power_age>=GOLD_TIME:
					clear_conversions()
					active_power = Power.NONE
	if active_power==Power.NONE and until_power<=0:
		var due = next_power
		next_power = Power.DOUBLE if due==Power.BOMBS else due+1
		until_power = INTERVAL
		if due==Power.BOMBS:bombs_ready = true
		else:cast(r,due)
	if active_power==Power.NONE and bombs_ready:
		transmute(r)
	advance_coins(r,dt)

func cast(r,power: int) -> void:
	active_power = power
	power_age = 0
	released = 0
	r.events.append({"type":CAST_EVENTS[power]})

func doubles_coins() -> bool:
	return active_power==Power.DOUBLE

func coin_scale() -> float:
	if not doubles_coins():
		return 1.0
	var swell = smoothstep(0,.34,power_age)
	var settle = smoothstep(.28,.59,power_age)
	var fade = 1-smoothstep(DOUBLE_TIME-.16,DOUBLE_TIME,power_age)
	return 1+(swell*.68-settle*.08)*fade

func lead_x(r) -> float:
	if mode=="space":return r.space.x
	if mode=="sewer" and not r.sewer.boats.is_empty():return r.sewer.boats[0].x
	var leader = r.leader_index()
	return r.members[leader].x if leader>=0 else r.ANCHOR

func drop_pose(bird,r,age: float) -> Vector2:
	var travel = smoothstep(.05,.59,age)*(1-smoothstep(1.40,DROP_TIME,age))
	var forward = lerpf(220,390,smoothstep(.59,1.4,age))
	var goal = Vector2(minf(lead_x(r)+forward,r.view_right-68),maxf(92,bird.point.y-28))
	return bird.point.lerp(goal,travel)+Vector2(0,sin(age*12)*5*travel)

func drop_coin(bird,r,index: int) -> void:
	var tail = drop_pose(bird,r,RELEASES[index])+Vector2(-25,27)
	var floor_y = INF
	if mode=="sewer" and not r.sewer.boats.is_empty():floor_y = float(r.sewer.boats[0].y)-24
	elif mode=="space":floor_y = r.space.y-r.space.member_height(r)*.5
	launch_coin(tail,Vector2(-32-index*14,105+index*12),index*1.7,floor_y)
	if index%2==0:r.events.append({"type":"barao_drop"})

func bomb_point(r,e: Dictionary) -> Vector2:
	if mode=="sewer":
		return r.sewer.object_surface(e)-Vector2(0,79 if e.kind=="rotor" else 42)
	return Vector2(e.x,e.y if e.kind=="air_bomb" else e.y-HordeTuning.BOMB_HEIGHT*.5)

func transmute(r) -> void:
	if mode=="space":return
	var sewer = mode=="sewer"
	var hazards = r.sewer.objects if sewer else r.entities
	var kinds = ["barrel","rotor"] if sewer else ["bomb","air_bomb"]
	var origin = lead_x(r)
	for e in hazards:
		if coins.size()+converted.size()>=MAX_COINS:break
		if e.kind not in kinds or e.taken or e.state!="normal" or e.x<origin+90 or e.x>r.view_right-48:continue
		if e.get("damaged",false):continue
		var speed = r.sewer.scroll_speed(r) if sewer else r.speed-float(e.vx)
		# Farther bombs get the full windup. A close target receives a shorter
		# ray so its coin can still land in front of the moving horde.
		var flight_limit = maxf(.12,(float(e.x)-origin-52)/maxf(1,speed)-.07)
		var impact_at = minf(CHARGE_TIME+BOLT_TIME+minf(.20,converted.size()*.055),flight_limit)
		e.taken = true
		e.barao_visible = true
		converted.append({"hazard":e,"speed":speed,"launch_at":maxf(.03,impact_at-BOLT_TIME),
			"impact_at":impact_at,"hit":false})
	if converted.is_empty():return
	bombs_ready = false
	cast(r,Power.BOMBS)

func clear_conversions() -> void:
	for item in converted:
		item.hazard.erase("barao_visible")
	converted.clear()

func advance_conversions(r) -> void:
	for item in converted:
		if item.hit or power_age<item.impact_at:
			continue
		item.hit = true
		var hazard: Dictionary = item.hazard
		hazard.erase("barao_visible")
		var point = bomb_point(r,hazard)
		var water_lane = float(r.sewer.boats[0].y)-24 if mode=="sewer" and not r.sewer.boats.is_empty() else INF
		launch_coin(point,Vector2(-float(item.speed)*.78,-125),point.x*.01,water_lane)
		r.mission_stats.bombs_broken = int(r.mission_stats.get("bombs_broken",0))+1
		r.events.append({"type":"barao_gold_hit","x":point.x,"y":point.y})

func paint(g,bird) -> void:
	var c = g.paint_target
	var p: Vector2 = bird.point
	var r = g.runner
	const HEIGHT = 82.0
	match active_power:
		Power.DOUBLE:
			paint_double(g,p,bird.clock)
		Power.DROP:
			p = drop_pose(bird,r,power_age)
			var kick = 0.0
			for release in RELEASES:
				kick += sin(clampf((power_age-release)/.15,0,1)*PI)
			Art.paint(c,p+Vector2(kick*6,-kick*4),HEIGHT,bird.clock*1.35,-.08+kick*.20,-kick*.15,-kick*.06)
			for release in RELEASES:
				var t = (power_age-release)/.28
				if t>=0 and t<1:
					var tail = drop_pose(bird,r,release)+Vector2(-25-35*t,25+11*t)
					paint_sparks(c,tail,t,16,4,.52)
		Power.BOMBS:
			var gather = smoothstep(0,.18,power_age)*(1-smoothstep(.44,.94,power_age))
			var lean = .15*gather
			var chest = p+Art.medallion(HEIGHT).rotated(lean)
			for item in converted:
				paint_conversion(g,chest,item)
			Art.paint(c,p,HEIGHT,bird.clock,lean,.42*gather,.08*gather)
			if gather>.01:
				paint_glow(c,chest,14+gather*9,gather*.74)
				paint_star(c,chest,5+gather*5,1.0,gather)
		_:
			var startled = smoothstep(.55,.90,bird.emotion_left)
			Art.paint(c,p,HEIGHT,bird.clock,-.11*startled,.28*startled,.06*startled)
	paint_coins(g)

func paint_double(g,point: Vector2,clock: float) -> void:
	var c = g.paint_target
	var windup = smoothstep(0,.21,power_age)*(1-smoothstep(.20,.43,power_age))
	var flourish = smoothstep(.20,.45,power_age)*(1-smoothstep(.6,1.32,power_age))
	var roll = windup*.12-flourish*.16
	var body = point+Vector2(-8*windup+9*flourish,14*windup-29*flourish)
	var chest = body+Art.medallion(82).rotated(roll)
	if windup>.01:
		paint_glow(c,chest,11+windup*12,windup*.54)
		for i in range(7):
			var angle = i*TAU/7+power_age*3.4
			paint_star(c,chest+Vector2.from_angle(angle)*(41-28*windup),4*windup,angle,windup*.83)
	var sweep = clampf((power_age-.29)/.79,0,1)
	if sweep>0 and sweep<1:
		var alpha = sin(sweep*PI)
		var ring = 33+56*sweep
		c.draw_arc(body,ring,-PI+.32+sweep*.62,-.46+sweep*.62,32,Color(GOLD,.78*alpha),2,true)
		c.draw_arc(body,ring-5,.14+sweep*.62,1.15+sweep*.62,18,Color(GOLD,.40*alpha),1.6,true)
	Art.paint(c,body,82,clock,roll,flourish*.88-windup*.46,flourish*.14-windup*.14)
	if sweep>0 and sweep<1:
		var alpha = smoothstep(0,.22,sweep)*(1-smoothstep(.73,1,sweep))
		for i in range(2):
			var side = -1 if i==0 else 1
			var coin_pos = body+Vector2(side*(48+sweep*24),-sin(sweep*PI)*44+12*sweep)
			var width = 24+8*sin(sweep*PI)
			var turn = maxf(.28,absf(cos(sweep*TAU+i*.55)))
			paint_glow(c,coin_pos,width*.73,alpha*.56)
			c.draw_set_transform(coin_pos,side*(sweep-.35)*.59,Vector2(turn,1))
			c.draw_texture_rect(g.art.items[1],Rect2(Vector2.ONE*-width*.5,Vector2.ONE*width),false,Color(1,1,1,alpha))
			c.draw_set_transform(Vector2.ZERO)
			paint_star(c,coin_pos+Vector2(side*16,-11),5,side*sweep*2,alpha)
	var mark_alpha = smoothstep(.40,.64,power_age)*(1-smoothstep(DOUBLE_TIME-.30,DOUBLE_TIME,power_age))
	if mark_alpha>.01:
		var mark = body-Vector2(0,56+9*flourish)
		var radius = 16+4*flourish
		c.draw_circle(mark,radius,Color(.16,.08,.20,.91*mark_alpha),true,-1,true)
		c.draw_arc(mark,radius,0,TAU,24,Color(GOLD,.81*mark_alpha),1.5,true)
		g.text("×2",mark+Vector2(0,6),19,Color(BRIGHT,mark_alpha),true,true,2)

func paint_conversion(g,source: Vector2,item: Dictionary) -> void:
	var c = g.paint_target
	var r = g.runner
	var hazard: Dictionary = item.hazard
	var point = bomb_point(r,hazard)
	var elapsed = power_age-float(item.impact_at)
	if power_age>=item.launch_at and elapsed<.14:
		var head = smoothstep(item.launch_at,item.impact_at,power_age)
		var tip = quadratic(source,point,head)
		var fade = 1-smoothstep(0,.14,elapsed)
		if head>.005 and fade>.005:
			var taper = maxf(0,head-.58)
			var trail = PackedVector2Array()
			var core = PackedVector2Array()
			for i in range(17):
				var u = lerpf(taper,head,i/16.0)
				var curve = quadratic(source,point,u)
				trail.append(curve+Vector2(0,sin(u*29-power_age*38)*5.0*sin(u*PI)))
				core.append(curve)
			c.draw_polyline(trail,Color(.79,.28,.69,.23*fade),13,true)
			c.draw_polyline(core,Color(GOLD,.47*fade),8,true)
			c.draw_polyline(core,Color(BRIGHT,.96*fade),2.6,true)
			paint_glow(c,tip,14,fade)
			paint_star(c,tip,7,power_age*6,fade)
	if not item.hit:
		return
	var t = clampf(elapsed/.50,0,1)
	var dissolve = 1-smoothstep(0,.30,t)
	if dissolve>0 and mode=="street":
		var aerial = hazard.kind=="air_bomb"
		var tex: Texture2D = g.art.ritual[3] if aerial else g.art.props[0]
		var height = 85.8 if aerial else HordeTuning.BOMB_HEIGHT
		g.scenery.sprite(c,tex,point,height*(.49+.51*dissolve),Color(1,.88,.51,dissolve),-t*.64)
	if t<1:
		paint_glow(c,point,19+24*t,(1-t)*.94)
		paint_sparks(c,point,t,53,9,1.0)
		var ring = 12+43*t
		c.draw_arc(point,ring,1.1+t,6.8+t,28,Color(GOLD,.84*(1-t)),2.1,true)

func quadratic(source: Vector2,dest: Vector2,t: float) -> Vector2:
	var bend = (source+dest)*.5+Vector2(0,-48)
	return source.lerp(bend,t).lerp(bend.lerp(dest,t),t)

func paint_glow(c,point: Vector2,radius: float,opacity: float) -> void:
	c.draw_circle(point,radius,Color(1,.58,.15,.13*opacity),true,-1,true)
	c.draw_circle(point,radius*.68,Color(1,.72,.28,.18*opacity),true,-1,true)
	c.draw_circle(point,radius*.34,Color(BRIGHT,.32*opacity),true,-1,true)

func paint_sparks(c,point: Vector2,t: float,span: float,count: int,alpha: float) -> void:
	var opacity = (1-t)*alpha
	var radius = 5+span*(1-pow(1-t,2.4))
	for i in range(count):
		var angle = i*TAU/count+t*.35
		var p = point+Vector2.from_angle(angle)*radius*(.62+float(i%3)*.16)
		paint_star(c,p,(4+float(i%3)*1.6)*(1-t),angle,opacity)

func paint_star(c,point: Vector2,radius: float,angle: float,opacity: float) -> void:
	if radius<=0.15 or opacity<=.01:
		return
	var forward = Vector2.from_angle(angle)*radius
	var cross = forward.orthogonal()*.35
	c.draw_colored_polygon(PackedVector2Array([point-forward,point-cross,point+forward,point+cross]),Color(GOLD,opacity))
	c.draw_circle(point,radius*.25,Color(BRIGHT,opacity),true,-1,true)

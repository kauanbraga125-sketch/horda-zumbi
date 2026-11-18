extends "res://scripts/bird_coin_flight.gd"

const Art = preload("res://scripts/barao_art.gd")
const INTERVAL = 25.0
const DOUBLE_TIME = 8.0
const DROP_TIME = 2.35
const GOLD_TIME = 1.45
const CHARGE_TIME = .28
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
	var swell = smoothstep(.30,.58,power_age)
	var settle = smoothstep(.54,.80,power_age)
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
			if power_age>=.28 and power_age<1.62:
				var frame = 8 if power_age<.50 else 10 if kick>.40 else 9 if power_age<1.34 else 11
				Art.paint_action(c,p+Vector2(0,-kick*3),HEIGHT,frame)
			else:
				Art.paint_idle(c,p,HEIGHT,bird.clock)
			for release in RELEASES:
				var t = (power_age-release)/.28
				if t>=0 and t<1:
					var tail = drop_pose(bird,r,release)+Vector2(-25-35*t,25+11*t)
					Art.paint_magic(c,tail,34,t,Color(1,1,1,.70))
		Power.BOMBS:
			var gather = smoothstep(0,.28,power_age)*(1-smoothstep(.55,1.0,power_age))
			var chest = p+Art.medallion(HEIGHT)
			for item in converted:
				paint_conversion(g,chest,item)
			if power_age<1.04:
				var frame = 12 if power_age<.14 else 13 if power_age<.28 else 14 if power_age<.66 else 15
				Art.paint_action(c,p,HEIGHT,frame)
			else:
				Art.paint_idle(c,p,HEIGHT,bird.clock)
			if gather>.01:
				Art.paint_magic(c,chest,38,clampf(power_age/.8,0,.80),Color(1,1,1,gather))
		_:
			Art.paint_idle(c,p,HEIGHT,bird.clock,"hurt" if bird.emotion_left>.65 else "")
	paint_coins(g)

func paint_double(g,point: Vector2,clock: float) -> void:
	var c = g.paint_target
	var flourish = smoothstep(.26,.45,power_age)*(1-smoothstep(.74,1.13,power_age))
	var body = point+Vector2(0,-10*flourish)
	var chest = body+Art.medallion(82)
	if power_age<1.12:
		var frame = clampi(int(power_age/1.12*8),0,7)
		Art.paint_action(c,body,82,frame)
	else:
		Art.paint_idle(c,point,82,clock)
	Art.paint_magic(c,chest,64,(power_age-.26)/.70)
	var split = (power_age-.37)/.84
	if split>0 and split<1:
		var alpha = smoothstep(0,.13,split)*(1-smoothstep(.68,1,split))
		for i in range(2):
			var side = -1 if i==0 else 1
			var coin_pos = chest+Vector2(side*31*smoothstep(0,.62,split),-38*sin(split*PI*.78))
			var width = 22+7*sin(split*PI)
			var turn = .76+.24*cos(split*TAU+i*.35)
			c.draw_set_transform(coin_pos,side*.10,Vector2(turn,1))
			c.draw_texture_rect(g.art.items[1],Rect2(Vector2.ONE*-width*.5,Vector2.ONE*width),false,Color(1,1,1,alpha))
			c.draw_set_transform(Vector2.ZERO)
			Art.paint_magic(c,coin_pos,40,split,Color(1,1,1,alpha*.50))
	paint_coin_wave(g)
	var mark_alpha = smoothstep(.84,1.12,power_age)*(1-smoothstep(DOUBLE_TIME-.30,DOUBLE_TIME,power_age))
	if mark_alpha>.01:
		g.text("×2",point+Vector2(0,-51),20,Color(BRIGHT,mark_alpha),true,true,3)

func paint_coin_wave(g) -> void:
	if power_age<.35 or power_age>1.7:
		return
	var r = g.runner
	var objects = r.sewer.objects if mode=="sewer" else r.space.objects if mode=="space" else r.entities
	var painted = 0
	for coin in objects:
		if coin.kind!="coin" or coin.taken or coin.x<r.view_left or coin.x>r.view_right:
			continue
		var age = power_age-.35-clampf((coin.x-lead_x(r))/1300,0,.6)
		var at = r.sewer.coin_position(coin) if mode=="sewer" else Vector2(coin.x,coin.y)
		Art.paint_magic(g.paint_target,at,57,age/.51,Color(1,1,1,.8))
		painted += 1
		if painted>=12:break

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
			var taper = maxf(0,head-.73)
			var trail = PackedVector2Array()
			var core = PackedVector2Array()
			for i in range(17):
				var u = lerpf(taper,head,i/16.0)
				var curve = quadratic(source,point,u)
				trail.append(curve+Vector2(0,sin(u*29-power_age*38)*5.0*sin(u*PI)))
				core.append(curve)
			c.draw_polyline(trail,Color(.93,.50,.13,.21*fade),14,true)
			c.draw_polyline(core,Color(GOLD,.65*fade),7,true)
			c.draw_polyline(core,Color(BRIGHT,.98*fade),2,true)
			Art.paint_magic(c,tip,34,.12+head*.18,Color(1,1,1,fade))
			for i in range(5):
				var u = head-float(i+1)*.11
				if u>taper:
					var sparkle = quadratic(source,point,u)+Vector2(0,sin(u*27-power_age*25)*8)
					paint_star(c,sparkle,2.5+float(i%2),u*5,fade*.65)
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
		Art.paint_magic(c,point,117,t)

func quadratic(source: Vector2,dest: Vector2,t: float) -> Vector2:
	var bend = (source+dest)*.5+Vector2(0,-48)
	return source.lerp(bend,t).lerp(bend.lerp(dest,t),t)

func paint_star(c,point: Vector2,radius: float,angle: float,opacity: float) -> void:
	if radius<=0.15 or opacity<=.01:
		return
	var forward = Vector2.from_angle(angle)*radius
	var cross = forward.orthogonal()*.35
	c.draw_colored_polygon(PackedVector2Array([point-forward,point-cross,point+forward,point+cross]),Color(GOLD,opacity))
	c.draw_circle(point,radius*.25,Color(BRIGHT,opacity),true,-1,true)

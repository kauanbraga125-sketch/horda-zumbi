extends RefCounted
const Art = preload("res://scripts/sewer_art.gd")
var shaft = preload("res://scripts/sewer_shaft.gd").new()
var water_fx = preload("res://scripts/sewer_water_fx.gd").new()

func view_rect(g) -> Rect2:
	return Rect2(g.scenery.view_left,g.scenery.view_top,g.scenery.view_right-g.scenery.view_left,g.scenery.view_bottom-g.scenery.view_top)

func exit_boundary(g,s) -> float:
	var view = view_rect(g);var t = clampf(s.phase_age/s.EXIT_SECONDS,0,1)
	return lerpf(view.end.x+250,view.position.x-750,smoothstep(.03,.91,t))

func background(g,s) -> void:
	if s.phase in ["entry","exit"]: return
	var catwalk_y = shaft.catwalk_y(g, s)
	s.life.paint(g, s, catwalk_y)
	var far_bank = float(shaft.geometry(g, s).gallery_top) + shaft.GALLERY_HEIGHT * 0.708
	var drift = g.runner.world_px * 0.28
	var view = view_rect(g)
	var first = floori((view.position.x + drift) / 254.0)
	var last = ceili((view.end.x + drift) / 254.0)
	for i in range(first, last + 1):
		var x = i * 254.0 - drift + sin(i * 2.6) * 39.0
		var source = Vector2(x, catwalk_y + 10 + posmod(i, 3) * 5)
		var clock = s.age + i * 0.63
		water_fx.falling_drops(g.paint_target, source, far_bank - source.y, clock, 2, 0.43)
		water_fx.ripple(g.paint_target, Vector2(x - 7, far_bank + 2), 28, clock, 0.26)

func suspended(g,s,e: Dictionary) -> void:
	var c = g.paint_target;var gate = e.kind=="gate";var id = "gate" if gate else "pipe_mount"
	var tex = Art.fresh(id) if gate else Art.texture(id);var height = 193.0 if gate else 170.0
	var bottom = float(e.y)+(1-smoothstep(.15,.80,e.age))*-85 if gate else float(e.y)
	var size = tex.get_size()*height/tex.get_height();var top = bottom-height;var left = float(e.x)-size.x*.5
	var ceiling = g.scenery.view_top-45
	for u in [.17,.82]:
		var x = left+size.x*u
		c.draw_line(Vector2(x,ceiling),Vector2(x,top+35),Color("100d18"),13,true)
		c.draw_line(Vector2(x,ceiling),Vector2(x,top+35),Color("716744"),7,true)
		c.draw_line(Vector2(x-2,ceiling),Vector2(x-2,top+35),Color("afa67d"),1.5,true)
		for y in range(int(ceiling),int(top)+35,27):
			c.draw_arc(Vector2(x,y),5,0,TAU,10,Color("161423"),3,true)
			c.draw_circle(Vector2(x-2,y-2),1.2,Color("d6bf7c"))

	if gate: Art.new_prop(c,id,Vector2(e.x,bottom-height*.5),size.x)
	else: Art.prop(c,id,Vector2(e.x,bottom-height*.5),height)
	if gate:
		c.draw_circle(Vector2(e.x,bottom-52),3+sin(s.age*18),Color(1,.35,.15,.8))

func object(g,s,e: Dictionary) -> void:
	var c = g.paint_target;var p = Vector2(e.x,e.y)
	match e.kind:
		"coin": g.scenery.sprite(c,g.art.items[1],p,HordeBalance.COIN_DIAMETER,Color.WHITE,0)
		"rescue":
			var t = clampf(e.age/.55,0,1) if e.state=="capture" else 0.0
			var surface = Vector2(e.x,s.water_y(e.x)+7)
			var target = Vector2(s.boats[0].x,s.boats[0].y-30) if not s.boats.is_empty() else surface
			var at = surface.lerp(target,smoothstep(0,1,t))+Vector2(0,-sin(t*PI)*65)
			if t < 0.2: water_fx.ripple(c, surface + Vector2(0, 2), 72, s.age, 0.86)
			Art.survivor_new(c,int(e.get("variant",0)),at,118,s.age+e.age,Color(1,1,1,1-smoothstep(.75,1,t)))
		"fugitive":
			var t = clampf(e.age/s.CAPTURE_SECONDS,0,1) if e.state=="capture" else 0.0
			var at = Vector2(e.x,s.water_y(e.x)+10)
			if t < 0.3:
				water_fx.trail(c, at + Vector2(-71, 5), 126, s.age, 0.85 * (1 - t / 0.3))
				water_fx.ripple(c, at, 116, s.age, 0.73)
			if e.state!="capture":
				Art.fugitive(c,int(e.get("variant",2)),at,96,s.age+e.age)
			else:
				var target = Vector2(s.boats[0].x,s.boats[0].y-50) if not s.boats.is_empty() else at
				for boat in s.boats:
					if int(boat.id)==int(e.get("capture_boat_id",-1)): target = Vector2(boat.x,boat.y-50)
				Art.flipping_boat(c,at+Vector2(-t*105,-sin(t*PI)*44+t*t*96),t)
				var amount = 2 if int(e.variant)==2 else 1
				for person in range(amount):
					var u = clampf((t-person*.07)/.93,0,1)
					var origin = at+Vector2(-person*39,-63)
					var pt = origin.lerp(target+Vector2(-person*34,0),smoothstep(0,1,u))+Vector2(0,-sin(u*PI)*96)
					Art.captive(c,person if amount==2 else int(e.variant),pt,86,u,Color(1,1,1,1-smoothstep(.82,1,u)))
					g.animated_soul(pt+Vector2(0,-18),22,e.age+person*.2,Color(1,1,1,smoothstep(.45,.72,t)*(1-smoothstep(.84,1,t))))

		"rubble":
			water_fx.ripple(c, Vector2(e.x, s.water_y(e.x) + 19), 137, s.age, 0.62)
			Art.prop(c,"wreck",Vector2(e.x,s.WATER-17+sin(s.age*4+int(e.get("encounter",0)))*3),132,sin(s.age*2)*.025)
		"barrel":
			water_fx.ripple(c, Vector2(e.x, s.water_y(e.x) + 17), 77, s.age, 0.53)
			Art.prop(c,"floating_barrel",Vector2(e.x,s.WATER-28+sin(s.age*5)*3),103,sin(s.age*3)*.04)
			c.draw_circle(Vector2(e.x+12,s.WATER-80),3+sin(s.age*23),Color(1,.52,.14,.8))
		"rotor":
			var center = Vector2(e.x,s.WATER-55)
			water_fx.ripple(c, Vector2(e.x, s.WATER + 21), 152, s.age, 0.85)
			Art.new_prop(c,"pump_base",Vector2(e.x,s.WATER+37),170)
			Art.cel(c,"rotor",posmod(int(s.age*18),8),Rect2(center.x-65,center.y-68,130,130))
		"collapse":
			if e.age<float(e.get("warning",.85)):
				c.draw_arc(Vector2(e.x,s.WATER+10),45,0,PI,16,Color(1,.6,.18,.30+sin(s.age*16)*.13),3,true)
			else:
				water_fx.ripple(c, Vector2(e.x, s.WATER + 18), 85, s.age, 0.76)
				Art.new_prop(c,"spike",Vector2(e.x,e.y+32),80)
		"pipe","gate": suspended(g,s,e)

func paint(g,s) -> void:
	var r = g.runner;var c = g.paint_target;var view = view_rect(g)
	var exiting = s.phase=="exit"
	if s.phase=="entry":
		c.draw_set_transform(Vector2(0,-s.entry_drop()));g.ground(r.world_px);c.draw_set_transform(Vector2.ZERO)
		shaft.rupture_debris(g,s)
	# Draw the water particles, wakes and flood before any boat or rider.
	if not exiting: flood(g, s)
	water_fx.convoy(g, s)
	for item in s.splashes: water_fx.impact(c, s, item)
	if exiting:
		var tex = Art.fresh("ramp");var size = tex.get_size()*s.RAMP_WIDTH/tex.get_width()
		var at = Vector2(s.ramp_left(r)+size.x*.5,s.WATER+48-size.y*.5+s.exit_rise(r))
		Art.new_prop(c,"ramp",at,s.RAMP_WIDTH)
	for e in s.objects:
		if e.taken: continue
		if e.kind == "pipe":
			var pipe = Art.texture("pipe_mount")
			var width = pipe.get_width() * 170.0 / pipe.get_height()
			var nozzle = Vector2(e.x + width * 0.39, e.y - 8)
			var fall = maxf(20, s.water_y(e.x) + 14 - nozzle.y)
			water_fx.falling_drops(c, nozzle, fall, s.age, 5, 0.72)
			water_fx.ripple(c, nozzle + Vector2(-8, fall), 53, s.age, 0.55)
		elif e.kind != "gate": object(g, s, e)
	var order = range(s.boats.size());order.sort_custom(func(a,b):return float(s.boats[a].y)<float(s.boats[b].y))
	for index in order:
		var b = s.boats[index];var p = Vector2(b.x,b.y);var angle = float(b.angle)
		var opacity = 1.0
		if exiting:
			var flight = s.exit_boat(r,b);p = flight.p;angle = flight.angle
			opacity = 0.0 if p.y>view.end.y+180 else 1.0
		if opacity>.02: Art.boat(c,p,s.HULL_HEIGHT,angle,Color(1,1,1,opacity))
		for seat in range(b.ids.size()-1,-1,-1):
			var member_index = r.members.find_custom(func(m):return int(m.id)==int(b.ids[seat]))
			if member_index<0: continue
			var m = r.members[member_index];var wear = r.cosmetics_for(m,int(m.kind));var pose = str(m.get("sewer_pose","ride"))
			if s.phase=="entry" and pose in ["run","board"]: continue
			if pose in ["run","land"]:
				g.actor.paint(c,int(m.kind),Vector2(m.x,m.y),108,fposmod(r.elapsed*1.9+member_index*.1,1),"run",r.elapsed,.16 if pose=="land" else 0,Color.WHITE,false,1,false,-1,0,wear)
			elif pose=="board":
				g.actor.paint_space(c,int(m.kind),Vector2(m.x,m.y),108,r.elapsed+member_index*.13,"launch",0,wear)
			elif pose=="return":
				g.actor.paint_space(c,int(m.kind),Vector2(m.x,m.y),108,r.elapsed+member_index*.13,"return" if s.phase_age>1.45 else "launch",0,wear)
			else:
				g.actor.paint_rider(c,int(m.kind),Vector2(m.x,m.y),108,r.elapsed+member_index*.31,float(m.get("sewer_angle",b.angle)),wear,Color.WHITE,seat,pose,float(b.duck_left))
		if opacity>.02:
			Art.boat(c,p,s.HULL_HEIGHT,angle,Color(1,1,1,opacity),true)
		if b.bump<-.5: c.draw_arc(p+Vector2(65,-9),19,-1,1,12,Color(1,.75,.35,minf(.8,-float(b.bump)/25)),2,true)
	if s.phase=="entry":
		# Falling actors retain their paths independently of the boats' hull masks.
		for i in range(r.members.size()-1,-1,-1):
			var m = r.members[i];var pose = str(m.get("sewer_pose","ride"))
			if pose not in ["run","board"]: continue
			var wear = r.cosmetics_for(m,int(m.kind))
			g.actor.paint(c,int(m.kind),Vector2(m.x,m.y),108,fposmod(float(m.run_phase),1),"run" if pose=="run" else "fall",r.elapsed,0,Color.WHITE,false,1,false,-1,0,wear)
	for e in s.objects:
		if not e.taken and e.kind in ["pipe","gate"]: object(g,s,e)
	for item in s.casualties:
		var t = float(item.age);var at = Vector2(item.p)+Vector2(-t*200,-sin(t*PI)*55+t*t*145)
		g.actor.paint_space(c,int(item.kind),at,84,t,"ejected",0,item.wear,Color(1,1,1,1-smoothstep(.5,1,t)))
	if s.phase=="ride": speed_streaks(g,s)
	if s.phase=="entry" and s.phase_age>1 and s.phase_age<3.5:
		for i in range(12):
			var t = fposmod(s.age*1.6+i*.083,1);var x = view.position.x+fposmod(i*163,view.size.x)
			c.draw_line(Vector2(x,view.end.y-t*view.size.y),Vector2(x,view.end.y-t*view.size.y+28),Color(.6,.82,.79,.18),1.5,true)

func flood(g,s) -> void:
	var c = g.paint_target;var view = view_rect(g);var edge = s.wave_edge()
	var emergence = smoothstep(3.7,s.ENTRY_SECONDS,s.phase_age) if s.phase=="entry" else 1.0
	if emergence<=.005: return
	var height = (440+s.pressure*52+sin(s.age*2)*8)*emergence
	var shift = s.entry_depth() if s.phase=="entry" else 0.0
	var base = s.water_y(edge)+36+shift
	var foot = Vector2(edge + 21, base)
	Art.flood_new(c, foot, height, s.age)
	water_fx.wave_base(c, foot, height * 0.57, s.age, emergence)
	if s.pressure>.7:
		var danger = (.06+sin(s.age*11)*.025)*smoothstep(.7,1,s.pressure)
		c.draw_rect(Rect2(view.position,Vector2(55,view.size.y)),Color(1,.24,.14,danger))

func speed_streaks(g,s) -> void:
	var c = g.paint_target;var view = view_rect(g)
	for i in range(13):
		var t = fposmod(i*.137+s.age*1.5,1);var x = lerpf(view.end.x+100,view.position.x-150,t)
		var y = view.position.y+165+(i%5)*54
		c.draw_line(Vector2(x,y),Vector2(x+28+(i%3)*17,y),Color(.65,.85,.86,.04+sin(t*PI)*.06),1.1,true)

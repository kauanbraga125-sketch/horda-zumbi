extends RefCounted
const Art = preload("res://scripts/sewer_art.gd")
var shaft = preload("res://scripts/sewer_shaft.gd").new()
var water_fx = preload("res://scripts/sewer_water_fx.gd").new()

func view_rect(g) -> Rect2:
	return Rect2(g.scenery.view_left,g.scenery.view_top,g.scenery.view_right-g.scenery.view_left,g.scenery.view_bottom-g.scenery.view_top)

func background(g,s) -> void:
	if s.phase=="entry": return
	var opacity = 1.0-smoothstep(0.28,1.2,s.phase_age) if s.phase=="exit" else 1.0
	if opacity<=0.005: return
	var catwalk_y = shaft.catwalk_y(g, s)
	s.life.paint(g,s,catwalk_y,opacity)
	var far_bank = float(shaft.geometry(g, s).gallery_top) + shaft.GALLERY_HEIGHT * 0.708
	var drift = g.runner.world_px * s.GALLERY_PARALLAX
	var view = view_rect(g)
	var first = floori((view.position.x + drift) / 254.0)
	var last = ceili((view.end.x + drift) / 254.0)
	for i in range(first, last + 1):
		var x = i * 254.0 - drift + sin(i * 2.6) * 39.0
		var source = Vector2(x, catwalk_y + 10 + posmod(i, 3) * 5)
		var clock = s.age + i * 0.63
		water_fx.falling_drops(g.paint_target,source,far_bank-source.y,clock,2,0.43*opacity)
		water_fx.ripple(g.paint_target,Vector2(x-7,far_bank+2),28,clock,0.26*opacity)

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

func rescue_target(s, e: Dictionary, surface: Vector2, offset: float) -> Vector2:
	for boat in s.boats:
		if int(boat.id) == int(e.get("capture_boat_id",-1)): return Vector2(boat.x,boat.y-offset)
	return surface if s.boats.is_empty() else Vector2(s.boats[0].x,s.boats[0].y-offset)

func floating_prop(c, s, e: Dictionary, surface: Vector2, barrel: bool) -> void:
	var tex = Art.texture("floating_barrel" if barrel else "wreck")
	var height = 113.0 if barrel else 132.0
	var size = tex.get_size() * height / tex.get_height()
	var clock = s.age + int(e.get("encounter",0))*0.53
	var immersion = 0.28 + sin(clock*4.8)*0.055 if barrel else 0.17 + sin(clock*2.6)*0.015
	var tilt = sin(clock*3.6)*0.13 if barrel else sin(clock*1.8)*0.023
	water_fx.ripple(c, surface + Vector2(0,4), size.x*1.05, clock, 0.78)
	Art.immersed(c, tex, surface, size, Rect2(Vector2.ZERO,tex.get_size()), immersion, tilt)
	water_fx.contact(c, surface, size.x*(0.88 if barrel else 1.02), clock, 0.8)
	if barrel:
		var fuse = surface + Vector2(size.x*0.29, -height*(1.0-immersion)+6.0).rotated(tilt)
		for i in range(3):
			var t = fposmod(clock*5.6+i*0.331,1.0)
			var spark = fuse + Vector2(-t*(5.0+i*2.0), -15.0*t + 9.0*t*t)
			c.draw_circle(spark, 2.3-t*1.5, Color(1,0.66,0.26,(1.0-t)*0.9))

func spike(c, s, e: Dictionary, surface: Vector2) -> void:
	var tex = Art.fresh("spike")
	var cut = 350.0
	var scale = 80.0 / tex.get_width()
	var base = Vector2(tex.get_width(),tex.get_height()-cut) * scale
	var collar_y = surface.y - base.y*0.61
	var extension: float = s.spike_extension(e)
	var tip = cut * extension
	water_fx.ripple(c, surface, 92, s.age, 0.66+0.30*extension)
	if tip > 0.5:
		c.draw_texture_rect_region(tex, Rect2(surface.x-base.x*0.5,collar_y-tip*scale,base.x,tip*scale),
			Rect2(0,0,tex.get_width(),tip))
	Art.immersed(c, tex, surface, base, Rect2(0,cut,tex.get_width(),tex.get_height()-cut), 0.39)
	water_fx.contact(c, surface, 85, s.age, 0.85)
	if e.age<float(e.get("warning",0.85)):
		c.draw_circle(Vector2(surface.x,collar_y+6.0), 4.0, Color(1,0.55,0.23,0.60+sin(s.age*20)*0.28))

func object(g,s,e: Dictionary) -> void:
	var c = g.paint_target
	var surface: Vector2 = s.object_surface(e)
	match e.kind:
		"coin": g.scenery.sprite(c,g.art.items[1],s.coin_position(e),HordeBalance.COIN_DIAMETER,Color.WHITE,0)
		"rescue":
			var t = clampf(e.age/.55,0,1) if e.state=="capture" else 0.0
			var target = rescue_target(s,e,surface,30.0)
			var at = surface.lerp(target,smoothstep(0,1,t))+Vector2(0,-sin(t*PI)*65)
			var wet = 1.0 - smoothstep(0.0,0.25,t)
			water_fx.ripple(c,surface,96,s.age,0.88*wet)
			Art.survivor_new(c,int(e.get("variant",0)),at,118,s.age+e.age,Color(1,1,1,1-smoothstep(.75,1,t)),1.0-wet)
			water_fx.contact(c,surface,91,s.age,0.86*wet)
		"fugitive":
			var t = clampf(e.age/s.CAPTURE_SECONDS,0,1) if e.state=="capture" else 0.0
			var at = surface
			if t < 0.3:
				water_fx.trail(c, at + Vector2(-71, 5), 126, s.age, 0.85 * (1 - t / 0.3))
				water_fx.ripple(c, at, 116, s.age, 0.73)
			if e.state!="capture":
				Art.fugitive(c,int(e.get("variant",2)),at,96,s.age+e.age)
				water_fx.contact(c,at,135,s.age,0.65)
			else:
				var target = rescue_target(s,e,at,50.0)
				Art.flipping_boat(c,at+Vector2(-t*105,-sin(t*PI)*44+t*t*96),t)
				var amount = 2 if int(e.variant)==2 else 1
				for person in range(amount):
					var u = clampf((t-person*.07)/.93,0,1)
					var origin = at+Vector2(-person*39,-63)
					var pt = origin.lerp(target+Vector2(-person*34,0),smoothstep(0,1,u))+Vector2(0,-sin(u*PI)*96)
					Art.captive(c,person if amount==2 else int(e.variant),pt,86,u,Color(1,1,1,1-smoothstep(.82,1,u)))
					g.animated_soul(pt+Vector2(0,-18),22,e.age+person*.2,Color(1,1,1,smoothstep(.45,.72,t)*(1-smoothstep(.84,1,t))))

		"rubble","barrel":
			floating_prop(c,s,e,surface,e.kind=="barrel")
		"rotor":
			var tex = Art.fresh("pump_base")
			var base = tex.get_size()*170.0/tex.get_width()
			var joint = surface.y-base.y*0.72
			water_fx.ripple(c,surface,184,s.age,0.88)
			Art.cel(c,"rotor",posmod(int(s.age*18),8),Rect2(surface.x-65,joint-123,130,130))
			Art.immersed(c,tex,surface,base,Rect2(Vector2.ZERO,tex.get_size()),0.28)
			water_fx.contact(c,surface,172,s.age,0.89)
		"collapse": spike(c,s,e,surface)
		"pipe","gate": suspended(g,s,e)

func paint(g,s) -> void:
	var r = g.runner;var c = g.paint_target;var view = view_rect(g)
	var exiting = s.phase=="exit"
	var exit_poses: Array = []
	if exiting:
		for b in s.boats: exit_poses.append(s.exit_boat(r,b))
	if s.phase=="entry":
		c.draw_set_transform(Vector2(0,-s.entry_drop()));g.ground(r.world_px);c.draw_set_transform(Vector2.ZERO)
		shaft.rupture_debris(g,s)
	# Draw the water particles, wakes and flood before any boat or rider.
	flood(g, s)
	water_fx.convoy(g, s)
	for item in s.splashes: water_fx.impact(c, s, item)
	if exiting and s.exit_clear()<0.999:
		var tex = Art.fresh("ramp");var size = tex.get_size()*s.RAMP_WIDTH/tex.get_width()
		var deck = s.RAMP_DECK_Y+s.exit_rise(r)
		var at = Vector2(s.ramp_left(r)+size.x*.5,deck-s.RAMP_TEXTURE_DECK+size.y*.5)
		Art.new_prop(c,"ramp",at,s.RAMP_WIDTH,0.0,Color(1,1,1,1.0-s.exit_clear()))
	if exiting:
		for flight in exit_poses:
			if flight.launch>flight.detach and flight.opacity>0.02:
				Art.boat(c,flight.p,s.HULL_HEIGHT,flight.angle,Color(1,1,1,flight.opacity))
		var shore = Vector2(s.exit_bank(r)+120.0,s.RAMP_DECK_Y+s.exit_rise(r))
		if shore.x>view.position.x-80.0 and shore.x<view.end.x+100.0:
			water_fx.contact(c,shore,158.0,s.age,0.9*(1.0-s.exit_clear()))
		g.ground(r.world_px)
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
	var order = range(s.boats.size())
	order.sort_custom(func(a,b):
		var da = float(exit_poses[a].depth) if exiting else float(s.boats[a].depth)
		var db = float(exit_poses[b].depth) if exiting else float(s.boats[b].depth)
		return a>b if is_equal_approx(da,db) else da<db)
	for index in order:
		var b = s.boats[index];var p = Vector2(b.x,b.y);var angle = float(b.angle)
		var opacity = 1.0
		if exiting:
			var flight = exit_poses[index];p = flight.p;angle = flight.angle
			opacity = 0.0 if flight.launch>flight.detach else float(flight.opacity)
		if opacity>.02: Art.boat(c,p,s.HULL_HEIGHT,angle,Color(1,1,1,opacity))
		for seat in range(b.ids.size()-1,-1,-1):
			var member_index = s.member_index(r, int(b.ids[seat]))
			if member_index<0: continue
			var m = r.members[member_index];var wear = r.cosmetics_for(m,int(m.kind));var pose = str(m.get("sewer_pose","ride"))
			if s.phase=="entry" and pose in ["run","board"]: continue
			if pose in ["run","land"]:
				g.actor.paint(c,int(m.kind),Vector2(m.x,m.y),108,fposmod(r.elapsed*1.9+member_index*.1,1),"run",r.elapsed,.16 if pose=="land" else 0,Color.WHITE,false,1,false,-1,0,wear)
			elif pose=="board":
				g.actor.paint_space(c,int(m.kind),Vector2(m.x,m.y),108,r.elapsed+member_index*.13,"launch",0,wear)
			elif pose=="return":
				g.actor.paint_space(c,int(m.kind),Vector2(m.x,m.y),108,r.elapsed+member_index*.13,"launch" if m.vy<0 else "return",m.vy,wear)
			else:
				g.actor.paint_rider(c,int(m.kind),Vector2(m.x,m.y),108,r.elapsed+member_index*.31,float(m.get("sewer_angle",b.angle)),wear,Color.WHITE,seat,pose,float(b.duck_pose))
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
	var c = g.paint_target
	var view = view_rect(g)
	var edge = s.exit_wave_x - s.exit_speed*s.phase_age*0.24 if s.phase=="exit" else s.wave_edge()
	var emergence: float = s.wave_strength()
	if emergence<=.005: return
	var height = (440+s.pressure*52+sin(s.age*2)*8)*emergence
	var shift = s.entry_depth() if s.phase=="entry" else s.exit_rise(g.runner) if s.phase=="exit" else 0.0
	var base = s.water_y(edge)+36+shift
	var foot = Vector2(edge + 21, base)
	Art.flood_new(c,foot,height,s.age,emergence)
	water_fx.wave_base(c, foot, height * 0.57, s.age, emergence)
	if s.pressure>.7:
		var danger = (.06+sin(s.age*11)*.025)*smoothstep(.7,1,s.pressure)*emergence
		c.draw_rect(Rect2(view.position,Vector2(55,view.size.y)),Color(1,.24,.14,danger))

func speed_streaks(g,s) -> void:
	var c = g.paint_target;var view = view_rect(g)
	for i in range(13):
		var t = fposmod(i*.137+s.age*1.5,1);var x = lerpf(view.end.x+100,view.position.x-150,t)
		var y = view.position.y+165+(i%5)*54
		c.draw_line(Vector2(x,y),Vector2(x+28+(i%3)*17,y),Color(.65,.85,.86,.04+sin(t*PI)*.06),1.1,true)

extends RefCounted
const Old = preload("res://scripts/bird_art.gd")
const Art = preload("res://scripts/sewer_art.gd")

func view_rect(g) -> Rect2:
	return Rect2(g.scenery.view_left,g.scenery.view_top,g.scenery.view_right-g.scenery.view_left,g.scenery.view_bottom-g.scenery.view_top)

func exit_boundary(g,s) -> float:
	var view = view_rect(g);var t = clampf(s.phase_age/s.EXIT_SECONDS,0,1)
	return lerpf(view.end.x+250,view.position.x-750,smoothstep(.03,.91,t))

func entry_boundary(g,s) -> float:
	var view = view_rect(g)
	return lerpf(minf(view.end.x+100,s.LEAD+380),view.position.x-750,smoothstep(0,.96,s.entry_launch()))

func walls(g,s,left: float,right: float,alpha: float = 1.0,shift_y: float = 0.0) -> void:
	var c = g.paint_target;var view = view_rect(g);var tex = Old.texture("sewer");var height = maxf(760,view.size.y+40)
	var size = tex.get_size()*height/tex.get_height();var stride = size.x-140;var offset = fposmod(s.scroll*.45,stride)
	for i in range(-1,ceili(view.size.x/stride)+2): blend_tile(c,tex,Rect2(view.position+Vector2(i*stride-offset,-20+shift_y),size),alpha,left,right)

func background(g,s) -> void:
	var c = g.paint_target;var view = view_rect(g)
	if s.phase=="entry":
		var floor_y = g.runner.FLOOR-s.entry_drop();var seam = view.position.y-20+s.entry_depth()
		if seam>floor_y:
			var tex = Old.texture("sewer")
			c.draw_texture_rect_region(tex,Rect2(view.position.x,floor_y,view.size.x,seam-floor_y+30),Rect2(tex.get_size()*Vector2(.06,.10),tex.get_size()*Vector2(.85,.42)),Color(.72,.85,.88))
			for x in [s.shore_edge()+45,s.shore_edge()+360]:
				c.draw_line(Vector2(x,floor_y),Vector2(x,seam+30),Color("17121e"),17,true)
				c.draw_line(Vector2(x,floor_y),Vector2(x,seam+30),Color("776044"),10,true)
				c.draw_line(Vector2(x-3,floor_y),Vector2(x-3,seam+30),Color("b39866"),2,true)
		walls(g,s,view.position.x,view.end.x,1,s.entry_depth())
		return
	if s.phase=="exit":
		walls(g,s,view.position.x,view.end.x,1,s.exit_rise(g.runner));return
	walls(g,s,view.position.x,view.end.x)
	var catwalk_y = view.position.y-20+maxf(760,view.size.y+40)*.588
	s.life.paint(g,s,catwalk_y)
	for i in range(7):
		var at = Vector2(view.position.x+fposmod(i*267-s.scroll*.55,view.size.x+160)-80,view.position.y+68+(i%3)*21)
		for j in range(5):
			var t = fposmod(s.age*1.1+j*.22+i,1)
			c.draw_line(at+Vector2(-t*28,t*287),at+Vector2(-t*28-2,t*287+12),Color(.42,.8,.74,.18),1.4,true)

func dock_pool(g,s,lead: float) -> void:
	# A street opening, never a water rectangle covering a running foot.
	var c = g.paint_target;var view = view_rect(g);var edge = s.shore_edge()+lead-s.LEAD
	if edge>view.end.x+50: return
	var floor_y = g.runner.FLOOR
	c.draw_rect(Rect2(edge,floor_y,maxf(1,view.end.x-edge+100),maxf(200,view.end.y-floor_y+80)),Color("132029"))
	var tex = g.gameplay_ui.ground_texture.atlas;var source = g.gameplay_ui.ground_texture.region
	c.draw_texture_rect_region(tex,Rect2(edge-30,floor_y-5,30,view.end.y-floor_y+100),Rect2(source.position+Vector2(0,15),Vector2(35,source.size.y-15)))
	c.draw_line(Vector2(edge-34,floor_y-5),Vector2(edge-2,floor_y-5),Color("8d917b"),5,true)
	for i in range(6):
		var t = fposmod(g.ui_time*.7+i*.17,1);var at = Vector2(edge+40+i*38,floor_y+20+t*190)
		c.draw_circle(at,2.2,Color(.47,.58,.56,(1-t)*.45))

func dock(g,s) -> void:
	var r = g.runner;var lead = float(s.encounter.dock_world)-r.world_px
	if lead<r.view_left-600 or lead>r.view_right+700: return
	dock_pool(g,s,lead)
	g.text("ESGOTO SOB A RUA",Vector2(lead-180,r.FLOOR-130),19,g.MINT,true,true,2)

func blend_tile(c,tex: Texture2D,rect: Rect2,alpha: float,left: float,right: float) -> void:
	var fade = 140.0/rect.size.x
	for band in range(2):
		var u0 = 0.0 if band==0 else fade;var u1 = fade if band==0 else 1.0
		var x0 = maxf(left,rect.position.x+u0*rect.size.x);var x1 = minf(right,rect.position.x+u1*rect.size.x)
		if x1<=x0: continue
		var a = (x0-rect.position.x)/rect.size.x;var b = (x1-rect.position.x)/rect.size.x
		var ca = alpha*clampf(a/fade,0,1);var cb = alpha*clampf(b/fade,0,1)
		var points = PackedVector2Array([Vector2(x0,rect.position.y),Vector2(x1,rect.position.y),Vector2(x1,rect.end.y),Vector2(x0,rect.end.y)])
		c.draw_polygon(points,PackedColorArray([Color(1,1,1,ca),Color(1,1,1,cb),Color(1,1,1,cb),Color(1,1,1,ca)]),PackedVector2Array([Vector2(a,0),Vector2(b,0),Vector2(b,1),Vector2(a,1)]),tex)

func water(g,s,front: bool,right_limit: float = INF,alpha: float = 1.0,left_limit: float = -INF) -> void:
	var c = g.paint_target;var view = view_rect(g)
	var left = maxf(view.position.x-35,left_limit);var right = minf(view.end.x+35,right_limit);var bottom = view.end.y+100
	if right<=left: return
	var shift = s.entry_depth() if s.phase=="entry" else s.exit_rise(g.runner) if s.phase=="exit" else 0.0
	var base = s.WATER+shift+(24 if front else -5)
	if base>view.end.y+20: return
	var tex = Old.texture("sewer");var width = 870.0;var factor = 1.46 if front else 1.06
	var offset = fposmod(s.scroll*factor,width*2)
	for column in range(-1,ceili(view.size.x/width)+4):
		var origin = left+column*width-offset;var x0 = maxf(left,origin);var x1 = minf(right,origin+width)
		if x1<=x0: continue
		var sample_left = .30 if posmod(column,2)==0 else .95;var sample_right = .95 if posmod(column,2)==0 else .30
		var u0 = lerpf(sample_left,sample_right,(x0-origin)/width);var u1 = lerpf(sample_left,sample_right,(x1-origin)/width)
		var opacity = (.35 if front else 1.0)*alpha
		var points = PackedVector2Array([Vector2(x0,bottom)]);var uvs = PackedVector2Array([Vector2(u0,1)])
		var colors = PackedColorArray([Color(.7,.94,.95,opacity)]);var foam = PackedVector2Array()
		for i in range(25):
			var x = lerpf(x0,x1,float(i)/24)
			var y = minf(bottom-2,base+s.water_y(x)-s.WATER+sin(x*.047-s.age*6)*2.5)
			points.append(Vector2(x,y));uvs.append(Vector2(lerpf(sample_left,sample_right,(x-origin)/width),.735));colors.append(Color(1,1.08,1.05,opacity));foam.append(Vector2(x,y))
		points.append(Vector2(x1,bottom));uvs.append(Vector2(u1,1));colors.append(Color(.7,.94,.95,opacity))
		c.draw_polygon(points,colors,uvs,tex);c.draw_polyline(foam,Color(.4,.9,.8,.25*alpha),1.8,true)
	for i in range(45 if front else 18):
		var x = left+fposmod(i*83.7-s.scroll*(1.8 if front else 1.05),maxf(1,view.size.x+90))
		if x>right: continue
		var y = base+14+(i%7)*17+sin(s.age*4+i)*3
		c.draw_line(Vector2(x,y),Vector2(minf(right,x+25+i%4*15),y-1),Color(.6,.95,.85,.15*alpha),1.6,true)

func wake(g,s,b: Dictionary,index: int) -> void:
	if s.phase!="ride": return
	if b.y<s.water_y(b.x)-42+float(b.get("depth",0)): return
	var c = g.paint_target
	for i in range(13):
		var t = fposmod(s.age*2.8+i*.081+index*.21,1)
		var p = Vector2(b.x-62-t*183,b.y+29+t*12+sin(i*3+s.age*7)*5)
		c.draw_arc(p,7+t*16,PI*.05,PI*.82,8,Color(.7,1,.95,(1-t)*.62),2,true)
	for i in range(7):
		var t = fposmod(s.age*3.1+i*.147+index,1)
		c.draw_circle(Vector2(b.x-70-t*134,b.y+17-t*50+t*t*58),2.8*(1-t)+.4,Color(.78,1,.96,(1-t)*.7))

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
	if not gate:
		for i in range(13):
			var t = fposmod(s.age*2.8+i*.077,1)
			var p = Vector2(e.x+size.x*.4-t*22,bottom-8+t*114)
			c.draw_line(p,p+Vector2(-3,10),Color(.58,.94,.85,.32*(1-t)),1.8,true)
	else:
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
			Art.survivor_new(c,int(e.get("variant",0)),at,118,s.age+e.age,Color(1,1,1,1-smoothstep(.75,1,t)))
			if t<.2: ripple(c,surface+Vector2(0,2),55,s.age)
		"fugitive":
			var t = clampf(e.age/s.CAPTURE_SECONDS,0,1) if e.state=="capture" else 0.0
			var at = Vector2(e.x,s.water_y(e.x)+10)
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
				if t<.2: ripple(c,at,115,s.age)
			if t<.3: ripple(c,at+Vector2(-60,0),75,s.age)
			for i in range(8):
				var trail = fposmod(s.age*2+i*.13,1)
				c.draw_arc(at+Vector2(-82-trail*100,trail*14),7+trail*11,0,PI,8,Color(.7,1,.94,.5*(1-trail)),2,true)

		"rubble":
			Art.prop(c,"wreck",Vector2(e.x,s.WATER-17+sin(s.age*4+int(e.get("encounter",0)))*3),132,sin(s.age*2)*.025)
			c.draw_arc(Vector2(e.x,s.WATER+5),70,0,PI,16,Color(.55,.95,.85,.22),2,true)
		"barrel":
			Art.prop(c,"floating_barrel",Vector2(e.x,s.WATER-28+sin(s.age*5)*3),103,sin(s.age*3)*.04)
			c.draw_circle(Vector2(e.x+12,s.WATER-80),3+sin(s.age*23),Color(1,.52,.14,.8))
		"rotor":
			var center = Vector2(e.x,s.WATER-55)
			Art.new_prop(c,"pump_base",Vector2(e.x,s.WATER+37),170)
			ripple(c,Vector2(e.x,s.WATER+21),87,s.age)
			Art.cel(c,"rotor",posmod(int(s.age*18),8),Rect2(center.x-65,center.y-68,130,130))
		"collapse":
			if e.age<float(e.get("warning",.85)):
				c.draw_arc(Vector2(e.x,s.WATER+10),45,0,PI,16,Color(1,.6,.18,.30+sin(s.age*16)*.13),3,true)
			else:
				Art.new_prop(c,"spike",Vector2(e.x,e.y+32),80)
				ripple(c,Vector2(e.x,s.WATER+18),43,s.age)
		"pipe","gate": suspended(g,s,e)

func ripple(c,at: Vector2,width: float,time: float) -> void:
	for layer in range(2):
		var points = PackedVector2Array()
		for i in range(25):
			var a = i*TAU/24;points.append(at+Vector2(cos(a)*(width+layer*9),sin(a)*(6+layer*3)+sin(time*5+i)*1.2))
		c.draw_polyline(points,Color(.62,.92,.83,.38-layer*.13),1.6,true)

func paint(g,s) -> void:
	var r = g.runner;var c = g.paint_target;var view = view_rect(g)
	var exiting = s.phase=="exit";var entry = s.entry_blend() if s.phase=="entry" else 1.0
	var exit_t = clampf(s.phase_age/s.EXIT_SECONDS,0,1) if exiting else 0.0
	if s.phase=="entry":
		c.draw_set_transform(Vector2(0,-s.entry_drop()));g.ground(r.world_px);c.draw_set_transform(Vector2.ZERO)
		if s.phase_age<1.1: dock_pool(g,s,s.LEAD)
	water(g,s,false)
	if exiting:
		var tex = Art.fresh("ramp");var size = tex.get_size()*s.RAMP_WIDTH/tex.get_width()
		var at = Vector2(s.ramp_left(r)+size.x*.5,s.WATER+48-size.y*.5+s.exit_rise(r))
		Art.new_prop(c,"ramp",at,s.RAMP_WIDTH)
	for e in s.objects:
		if not e.taken and e.kind not in ["pipe","gate"]: object(g,s,e)
	var order = range(s.boats.size());order.sort_custom(func(a,b):return float(s.boats[a].y)<float(s.boats[b].y))
	for index in order:
		var b = s.boats[index];var p = Vector2(b.x,b.y);var angle = float(b.angle)
		var opacity = 1.0
		if exiting:
			var flight = s.exit_boat(r,b);p = flight.p;angle = flight.angle
			opacity = 0.0 if p.y>view.end.y+180 else 1.0
		if opacity>.02: wake(g,s,b,index);Art.boat(c,p,96,angle,Color(1,1,1,opacity))
		for seat in range(b.ids.size()-1,-1,-1):
			var member_index = r.members.find_custom(func(m):return int(m.id)==int(b.ids[seat]))
			if member_index<0: continue
			var m = r.members[member_index];var wear = r.cosmetics_for(m,int(m.kind));var pose = str(m.get("sewer_pose","ride"))
			if pose in ["run","land"]:
				g.actor.paint(c,int(m.kind),Vector2(m.x,m.y),108,fposmod(r.elapsed*1.9+member_index*.1,1),"run",r.elapsed,.16 if pose=="land" else 0,Color.WHITE,false,1,false,-1,0,wear)
			elif pose=="board":
				g.actor.paint_space(c,int(m.kind),Vector2(m.x,m.y),108,r.elapsed+member_index*.13,"launch",0,wear)
			elif pose=="return":
				g.actor.paint_space(c,int(m.kind),Vector2(m.x,m.y),108,r.elapsed+member_index*.13,"return" if s.phase_age>1.45 else "launch",0,wear)
			else:
				g.actor.paint_rider(c,int(m.kind),Vector2(m.x,m.y),108,r.elapsed+member_index*.31,float(m.get("sewer_angle",b.angle)),wear,Color.WHITE,seat,pose,float(b.duck_left))
		if opacity>.02: Art.boat(c,p,96,angle,Color(1,1,1,opacity),true)
		if b.bump<-.5: c.draw_arc(p+Vector2(65,-9),19,-1,1,12,Color(1,.75,.35,minf(.8,-float(b.bump)/25)),2,true)
	for e in s.objects:
		if not e.taken and e.kind in ["pipe","gate"]: object(g,s,e)
	for item in s.casualties:
		var t = float(item.age);var at = Vector2(item.p)+Vector2(-t*200,-sin(t*PI)*55+t*t*145)
		g.actor.paint_space(c,int(item.kind),at,84,t,"ejected",0,item.wear,Color(1,1,1,1-smoothstep(.5,1,t)))
	for item in s.splashes: splash(g,s,item)
	if s.phase=="ride": flood(g,s);speed_streaks(g,s)
	water(g,s,true)
	if s.phase=="entry" and s.phase_age>3.95: flood(g,s)
	if s.phase=="entry" and s.phase_age>1 and s.phase_age<3.5:
		for i in range(12):
			var t = fposmod(s.age*1.6+i*.083,1);var x = view.position.x+fposmod(i*163,view.size.x)
			c.draw_line(Vector2(x,view.end.y-t*view.size.y),Vector2(x,view.end.y-t*view.size.y+28),Color(.6,.82,.79,.18),1.5,true)

func splash(g,_s,item: Dictionary) -> void:
	var c = g.paint_target;var t = float(item.age);var p = Vector2(item.p)
	if item.explosion:
		for i in range(4,0,-1): c.draw_circle(p,15+i*12+t*54,Color(1,.24+i*.09,.04,(1-t)*.06))
	for i in range(14):
		var speed = 65+i*12;var a = -PI*.92+i*PI*.064
		var at = p+Vector2.from_angle(a)*t*speed+Vector2(-t*150,t*t*220)
		c.draw_circle(at,(3+i%3)*(1-t),Color(1,.6,.18,1-t) if item.explosion else Color(.65,1,.92,1-t))

func flood(g,s) -> void:
	if s.phase=="entry" and s.phase_age<3.95: return
	var c = g.paint_target;var view = view_rect(g);var edge = s.wave_edge()
	var height = 440+s.pressure*52+sin(s.age*2)*8;var base = s.water_y(edge)+36
	Art.flood_new(c,Vector2(edge+21,base),height,s.age)
	for band in range(5):
		var points = PackedVector2Array()
		for j in range(26):
			var x = edge-190+j*12;var y = s.water_y(x)+16+band*7+sin(j*.58-s.age*8+band)*3
			points.append(Vector2(x,y))
		c.draw_polyline(points,Color(.67,.94,.82,.42-band*.055),2.7-band*.25,true)
	for i in range(23):
		var t = fposmod(s.age*1.4+i*.071,1)
		var p = Vector2(edge-70+t*135,base-height*.65-t*35+t*t*91+(i%4)*7)
		c.draw_circle(p,1.4+(i%3)*.8,Color(.7,1,.94,(1-t)*.54))
	if s.pressure>.7:
		var danger = (.06+sin(s.age*11)*.025)*smoothstep(.7,1,s.pressure)
		c.draw_rect(Rect2(view.position,Vector2(55,view.size.y)),Color(1,.24,.14,danger))

func speed_streaks(g,s) -> void:
	var c = g.paint_target;var view = view_rect(g)
	for i in range(13):
		var t = fposmod(i*.137+s.age*1.5,1);var x = lerpf(view.end.x+100,view.position.x-150,t)
		var y = view.position.y+165+(i%5)*54
		c.draw_line(Vector2(x,y),Vector2(x+28+(i%3)*17,y),Color(.65,.85,.86,.04+sin(t*PI)*.06),1.1,true)

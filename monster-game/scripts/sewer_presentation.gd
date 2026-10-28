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

func walls(g,s,left: float,right: float,alpha: float = 1.0) -> void:
	var c = g.paint_target;var view = view_rect(g);var tex = Old.texture("sewer");var height = maxf(760,view.size.y+40)
	var size = tex.get_size()*height/tex.get_height();var stride = size.x-140;var offset = fposmod(s.scroll*.45,stride)
	for i in range(-1,ceili(view.size.x/stride)+2): blend_tile(c,tex,Rect2(view.position+Vector2(i*stride-offset,-20),size),alpha,left,right)

func background(g,s) -> void:
	var c = g.paint_target;var view = view_rect(g)
	if s.phase=="entry":
		g.scenery.paint(c,g.runner,g.ui_time)
		if s.entry_blend()>0: walls(g,s,view.position.x,view.end.x,s.entry_blend())
		return
	if s.phase=="exit":
		g.scenery.paint(c,g.runner,g.ui_time)
		if s.exit_blend()<1: walls(g,s,view.position.x,view.end.x,1-s.exit_blend())
		return
	walls(g,s,view.position.x,view.end.x)
	var catwalk_y = view.position.y-20+maxf(760,view.size.y+40)*.588
	s.life.paint(g,s,catwalk_y)
	for i in range(7):
		var at = Vector2(view.position.x+fposmod(i*267-s.scroll*.55,view.size.x+160)-80,view.position.y+68+(i%3)*21)
		for j in range(5):
			var t = fposmod(s.age*1.1+j*.22+i,1)
			c.draw_line(at+Vector2(-t*28,t*287),at+Vector2(-t*28-2,t*287+12),Color(.42,.8,.74,.18),1.4,true)

func dock_pool(g,s,lead: float) -> void:
	var c = g.paint_target;var view = view_rect(g);var edge = s.shore_edge()+lead-s.LEAD
	if edge>view.end.x+80: return
	var top = g.runner.FLOOR+12;var width = maxf(1,view.end.x+80-edge)
	var rect = Rect2(edge,top,width,maxf(160,view.end.y-top+70));var tex = Old.texture("sewer")
	c.draw_texture_rect_region(tex,rect,Rect2(60,720,1500,185),Color(.87,1,1))
	for i in range(17):
		var x = edge+fposmod(i*73-g.ui_time*110,width)
		c.draw_line(Vector2(x,top+16+i%4*13),Vector2(minf(rect.end.x,x+28),top+15+i%4*13),Color(.5,.9,.8,.3),1.5,true)
	# A continuous solid quay supports every running foot before take-off.
	c.draw_texture_rect_region(g.gameplay_ui.ground_texture.atlas,Rect2(edge-24,g.runner.FLOOR-5,24,view.end.y-g.runner.FLOOR+100),Rect2(50,94,90,210))
	c.draw_line(Vector2(edge-27,g.runner.FLOOR-5),Vector2(edge-1,g.runner.FLOOR-5),Color("8c9276"),5,true)

func dock(g,s) -> void:
	var r = g.runner;var lead = float(s.encounter.dock_world)-r.world_px
	if lead<r.view_left-600 or lead>r.view_right+700: return
	dock_pool(g,s,lead)
	var count = ceili(r.active_count()/2.0)
	for i in range(count):
		var at = Vector2(s.dock_x(r,i)+lead-s.LEAD,s.dock_y(r,i))
		Art.boat(g.paint_target,at,96,sin(g.ui_time*3+i)*.007)
	g.text("PORTO DO ESGOTO",Vector2(lead+20,r.FLOOR-165),19,g.MINT,true,true,2)

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
	var base = s.WATER+24 if front else s.WATER-5
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
			var y = base+sin(x*.022+s.age*4.6)*5+sin(x*.047-s.age*6)*2.5
			points.append(Vector2(x,y));uvs.append(Vector2(lerpf(sample_left,sample_right,(x-origin)/width),.735));colors.append(Color(1,1.08,1.05,opacity));foam.append(Vector2(x,y))
		points.append(Vector2(x1,bottom));uvs.append(Vector2(u1,1));colors.append(Color(.7,.94,.95,opacity))
		c.draw_polygon(points,colors,uvs,tex);c.draw_polyline(foam,Color(.4,.9,.8,.25*alpha),1.8,true)
	for i in range(45 if front else 18):
		var x = left+fposmod(i*83.7-s.scroll*(1.8 if front else 1.05),maxf(1,view.size.x+90))
		if x>right: continue
		var y = base+14+(i%7)*17+sin(s.age*4+i)*3
		c.draw_line(Vector2(x,y),Vector2(minf(right,x+25+i%4*15),y-1),Color(.6,.95,.85,.15*alpha),1.6,true)

func wake(g,s,b: Dictionary,index: int) -> void:
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
	var c = g.paint_target;var gate = e.kind=="gate";var id = "gate_mount" if gate else "pipe_mount"
	var tex = Art.texture(id);var height = 193.0 if gate else 170.0
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

	Art.prop(c,id,Vector2(e.x,bottom-height*.5),height)
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
			var t = clampf(e.age/.55,0,1) if e.state=="capture" else 0.0
			var at = Vector2(e.x-t*85,s.water_y(e.x)+9+t*t*48)
			Art.fugitive(c,int(e.get("variant",2)),at,154,s.age+e.age,Color(1,1,1,1-smoothstep(.1,.95,t)))
			if t<.3: ripple(c,at+Vector2(-70,0),94,s.age)
			for i in range(8):
				var trail = fposmod(s.age*2+i*.13,1)
				c.draw_arc(at+Vector2(-115-trail*100,trail*14),7+trail*11,0,PI,8,Color(.7,1,.94,.5*(1-trail)),2,true)

		"rubble":
			Art.prop(c,"wreck",Vector2(e.x,s.WATER-17+sin(s.age*4+int(e.get("encounter",0)))*3),83,sin(s.age*2)*.025)
			c.draw_arc(Vector2(e.x,s.WATER+5),70,0,PI,16,Color(.55,.95,.85,.22),2,true)
		"barrel":
			Art.prop(c,"floating_barrel",Vector2(e.x,s.WATER-28+sin(s.age*5)*3),103,sin(s.age*3)*.04)
			c.draw_circle(Vector2(e.x+12,s.WATER-80),3+sin(s.age*23),Color(1,.52,.14,.8))
		"rotor":
			var center = Vector2(e.x,s.WATER-50)
			var pillar = Old.texture("sewer")
			for y in range(int(s.WATER+14),int(view_rect(g).end.y+100),88):
				c.draw_texture_rect_region(pillar,Rect2(center.x-52,y,104,88),Rect2(783,321,85,120),Color(.70,.83,.79))
			c.draw_texture_rect_region(pillar,Rect2(center.x-74,s.WATER-7,148,47),Rect2(756,482,147,75),Color(.86,.92,.86))
			ripple(c,Vector2(e.x,s.WATER+24),77,s.age)
			Art.cel(c,"rotor",posmod(int(s.age*18),8),Rect2(center.x-65,center.y-68,130,130))
		"collapse":
			var point = Vector2(e.x,e.y)
			if not bool(e.get("landed",false)):
				c.draw_arc(Vector2(e.x,s.WATER-2),54,0,PI,16,Color(1,.6,.18,.25+sin(s.age*16)*.13),3,true)
				for i in range(5):
					var t = fposmod(s.age*2+i*.19,1);c.draw_circle(Vector2(e.x+(i-2)*13,s.WATER-370+t*200),2+t,Color(.7,.6,.52,.6*(1-t)))
			for i in range(5): c.draw_texture_rect_region(g.gameplay_ui.ground_texture.atlas,Rect2(point.x+(i-2)*21-22,point.y-(i%2)*17-21,45,40),Rect2(40+i*32,94,90,90))
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
	if s.phase=="entry" and entry<1:
		g.ground(r.world_px);dock_pool(g,s,s.LEAD)
	elif exiting: g.ground(r.world_px)
	var water_alpha = 1-s.exit_blend() if exiting else entry
	if s.phase!="entry" or entry>0: water(g,s,false,INF,water_alpha)
	if exiting and s.phase_age<1.05:
		var x = s.LEAD+240-s.phase_age*s.scroll_speed(r)*.65
		var tex = g.gameplay_ui.ground_texture.atlas;var source = g.gameplay_ui.ground_texture.region
		var ramp = PackedVector2Array([Vector2(x-190,s.WATER+40),Vector2(x+20,r.FLOOR-18),Vector2(x+20,r.FLOOR+85),Vector2(x-190,s.WATER+100)])
		var uv = PackedVector2Array([source.position,Vector2(source.end.x,source.position.y),source.end,Vector2(source.position.x,source.end.y)])
		for i in range(uv.size()):uv[i] /= tex.get_size()
		c.draw_polygon(ramp,PackedColorArray([Color(1,1,1,1-smoothstep(.75,1.05,s.phase_age))]),uv,tex)
	for e in s.objects:
		if not e.taken and e.kind not in ["pipe","gate"]: object(g,s,e)
	var order = range(s.boats.size());order.sort_custom(func(a,b):return float(s.boats[a].y)<float(s.boats[b].y))
	for index in order:
		var b = s.boats[index];var p = Vector2(b.x,b.y);var angle = float(b.angle)
		var opacity = 1.0
		if exiting:
			var launch = maxf(0,s.phase_age-.42)
			p += Vector2(launch*95,-28*smoothstep(0,.42,s.phase_age)-sin(clampf(launch/.8,0,1)*PI)*32+launch*launch*240)
			opacity = 1-smoothstep(.85,1.5,s.phase_age)
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
				g.actor.paint_rider(c,int(m.kind),Vector2(m.x,m.y),108,r.elapsed+member_index*.31,float(b.angle),wear,Color.WHITE,seat,pose,float(b.duck_left))
		if opacity>.02: Art.boat(c,p,96,angle,Color(1,1,1,opacity),true)
		if b.bump<-.5: c.draw_arc(p+Vector2(65,-9),19,-1,1,12,Color(1,.75,.35,minf(.8,-float(b.bump)/25)),2,true)
	for e in s.objects:
		if not e.taken and e.kind in ["pipe","gate"]: object(g,s,e)
	for item in s.casualties:
		var t = float(item.age);var at = Vector2(item.p)+Vector2(-t*200,-sin(t*PI)*55+t*t*145)
		g.actor.paint_space(c,int(item.kind),at,84,t,"ejected",0,item.wear,Color(1,1,1,1-smoothstep(.5,1,t)))
	for item in s.splashes: splash(g,s,item)
	if s.phase=="ride": flood(g,s);speed_streaks(g,s)
	if s.phase!="entry" or entry>0: water(g,s,true,INF,water_alpha)
	if s.phase=="entry":
		if s.phase_age>2.8: flood(g,s)
		var shadow = maxf(0,1-absf(s.phase_age-2.2)/.6)*.90
		if shadow>0: c.draw_rect(view,Color(.015,.01,.025,shadow))

func splash(g,_s,item: Dictionary) -> void:
	var c = g.paint_target;var t = float(item.age);var p = Vector2(item.p)
	if item.explosion:
		for i in range(4,0,-1): c.draw_circle(p,15+i*12+t*54,Color(1,.24+i*.09,.04,(1-t)*.06))
	for i in range(14):
		var speed = 65+i*12;var a = -PI*.92+i*PI*.064
		var at = p+Vector2.from_angle(a)*t*speed+Vector2(-t*150,t*t*220)
		c.draw_circle(at,(3+i%3)*(1-t),Color(1,.6,.18,1-t) if item.explosion else Color(.65,1,.92,1-t))

func flood(g,s) -> void:
	if s.phase=="entry" and s.entry_launch()<.65: return
	var c = g.paint_target;var view = view_rect(g);var edge = s.wave_edge()
	var height = 440+s.pressure*52+sin(s.age*2)*8;var base = s.WATER+25
	Art.flood_new(c,Vector2(edge+21,base),height,s.age)
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

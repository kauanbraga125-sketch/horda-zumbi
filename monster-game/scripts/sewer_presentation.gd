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

func walls(g,s,left: float,right: float) -> void:
	var c = g.paint_target;var view = view_rect(g);var tex = Old.texture("sewer");var height = maxf(760,view.size.y+40)
	var size = tex.get_size()*height/tex.get_height();var stride = size.x-140;var offset = fposmod(s.scroll*.45,stride)
	for i in range(-1,ceili(view.size.x/stride)+2): blend_tile(c,tex,Rect2(view.position+Vector2(i*stride-offset,-20),size),1,left,right)

func background(g,s) -> void:
	var c = g.paint_target;var view = view_rect(g)
	if s.phase=="entry": g.scenery.paint(c,g.runner,g.ui_time);return
	var clip_right = view.end.x
	if s.phase=="exit": g.scenery.paint(c,g.runner,g.ui_time);clip_right = exit_boundary(g,s)
	walls(g,s,view.position.x,clip_right)
	if s.phase=="exit": return
	var catwalk_y = view.position.y-20+maxf(760,view.size.y+40)*.588
	s.life.paint(g,s,catwalk_y)
	for i in range(7):
		var at = Vector2(view.position.x+fposmod(i*267-s.scroll*.55,view.size.x+160)-80,view.position.y+68+(i%3)*21)
		for j in range(5):
			var t = fposmod(s.age*1.1+j*.22+i,1)
			c.draw_line(at+Vector2(-t*28,t*287),at+Vector2(-t*28-2,t*287+12),Color(.42,.8,.74,.18),1.4,true)

func dock_pool(g,s,lead: float) -> void:
	var c = g.paint_target;var tex = Old.texture("sewer");var rect = Rect2(lead-640,g.runner.FLOOR-22,1040,maxf(190,view_rect(g).end.y-g.runner.FLOOR+110))
	c.draw_texture_rect_region(tex,rect,Rect2(60,720,1500,185),Color(.87,1,1))
	for i in range(14):
		var x = rect.position.x+fposmod(i*73-g.ui_time*110,rect.size.x)
		c.draw_line(Vector2(x,rect.position.y+16+i%4*13),Vector2(x+28,rect.position.y+15+i%4*13),Color(.5,.9,.8,.3),1.5,true)
	c.draw_line(Vector2(rect.position.x,rect.position.y-2),Vector2(rect.end.x,rect.position.y-2),Color("443941"),5,true)
	c.draw_texture_rect_region(g.gameplay_ui.ground_texture.atlas,Rect2(rect.position.x-33,rect.position.y-4,33,rect.size.y),Rect2(50,94,90,210))

func dock(g,s) -> void:
	var r = g.runner;var lead = float(s.encounter.dock_world)-r.world_px
	if lead<r.view_left-600 or lead>r.view_right+700: return
	dock_pool(g,s,lead)
	var count = ceili(r.active_count()/2.0);var columns = maxi(3,s.slot_column(count-1)+1);var spacing = minf(215,430.0/(columns-1))
	for i in range(count): Art.boat(g.paint_target,Vector2(lead-s.slot_column(i)*spacing-s.slot_lane(i)*42,r.FLOOR-35+s.slot_lane(i)*40),96,sin(g.ui_time*3+i)*.007)
	g.scenery.sprite(g.paint_target,g.art.tunnel_mouths[1],Vector2(lead+350,r.FLOOR-215),430)
	g.text("PORTO DO ESGOTO",Vector2(lead+245,r.FLOOR-375),19,g.MINT,true,true,2)

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
	var ceiling = minf(g.scenery.view_top-25,top-80)
	for u in [.17,.82]:
		var x = left+size.x*u
		var sample = Rect2(tex.get_width()*u-5,tex.get_height()*.16,10,tex.get_height()*.14)
		c.draw_texture_rect_region(tex,Rect2(x-4.5,ceiling,9,top-ceiling+14),sample)
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
		"coin": g.scenery.sprite(c,g.art.items[1],p,31,Color.WHITE,sin(s.age*6+e.age)*.2)
		"rescue":
			var t = clampf(e.age/.55,0,1) if e.state=="capture" else 0.0
			var target = Vector2(s.boats[0].x,s.boats[0].y-30) if not s.boats.is_empty() else p
			var at = p.lerp(target,smoothstep(0,1,t))+Vector2(0,-sin(t*PI)*65)
			Art.survivor_new(c,int(e.get("variant",0)),at,118,s.age+e.age,Color(1,1,1,1-smoothstep(.75,1,t)))
		"rubble":
			Art.prop(c,"wreck",Vector2(e.x,s.WATER-17+sin(s.age*4+int(e.get("encounter",0)))*3),83,sin(s.age*2)*.025)
			c.draw_arc(Vector2(e.x,s.WATER+5),70,0,PI,16,Color(.55,.95,.85,.22),2,true)
		"barrel":
			Art.prop(c,"floating_barrel",Vector2(e.x,s.WATER-28+sin(s.age*5)*3),103,sin(s.age*3)*.04)
			c.draw_circle(Vector2(e.x+12,s.WATER-80),3+sin(s.age*23),Color(1,.52,.14,.8))
		"rotor":
			var center = Vector2(e.x,s.WATER-50)
			c.draw_texture_rect_region(g.gameplay_ui.ground_texture.atlas,Rect2(center.x-61,s.WATER-6,122,35),Rect2(80,94,200,80))
			Art.cel(c,"rotor",posmod(int(s.age*18),8),Rect2(center.x-65,center.y-68,130,130))
		"collapse":
			var point = Vector2(e.x,e.y)
			if not bool(e.get("landed",false)):
				c.draw_arc(Vector2(e.x,s.WATER-2),54,0,PI,16,Color(1,.6,.18,.25+sin(s.age*16)*.13),3,true)
				for i in range(5):
					var t = fposmod(s.age*2+i*.19,1);c.draw_circle(Vector2(e.x+(i-2)*13,s.WATER-370+t*200),2+t,Color(.7,.6,.52,.6*(1-t)))
			for i in range(5): c.draw_texture_rect_region(g.gameplay_ui.ground_texture.atlas,Rect2(point.x+(i-2)*21-22,point.y-(i%2)*17-21,45,40),Rect2(40+i*32,94,90,90))
		"pipe","gate": suspended(g,s,e)

func paint(g,s) -> void:
	var r = g.runner;var c = g.paint_target;var exit_t = clampf(s.phase_age/s.EXIT_SECONDS,0,1) if s.phase=="exit" else 0.0
	var boundary = exit_boundary(g,s) if s.phase=="exit" else INF
	if s.phase in ["exit","entry"]: g.ground(r.world_px)
	var entry_left = -INF
	if s.phase=="entry":
		dock_pool(g,s,s.LEAD);entry_left = entry_boundary(g,s);walls(g,s,entry_left,view_rect(g).end.x)
	water(g,s,false,boundary,1-smoothstep(.64,.95,exit_t),entry_left)
	for e in s.objects:
		if not e.taken and e.kind not in ["pipe","gate"]: object(g,s,e)
	var order = range(s.boats.size());order.sort_custom(func(a,b):return float(s.boats[a].y)<float(s.boats[b].y))
	for index in order:
		var b = s.boats[index];var p = Vector2(b.x,b.y);var angle = float(b.angle)
		if s.phase=="exit": p += Vector2(sin(exit_t*PI)*100,-sin(exit_t*PI)*95+smoothstep(.56,1,exit_t)*460);angle += exit_t*.55
		if exit_t<.65: wake(g,s,b,index)
		if exit_t<.88: Art.boat(c,p,96,angle,Color(1,1,1,1-smoothstep(.65,.88,exit_t)))
		if s.phase!="exit":
			# Whole seated drawings stay on their own saddles.
			for seat in range(b.ids.size()-1,-1,-1):
				var member_index = r.members.find_custom(func(m):return int(m.id)==int(b.ids[seat]))
				if member_index<0: continue
				var m = r.members[member_index];var wear = r.cosmetics_for(m,int(m.kind))
				if str(m.get("sewer_pose","ride"))=="run":
					g.actor.paint(c,int(m.kind),Vector2(m.x,m.y),108,fposmod(r.elapsed*1.9+member_index*.1,1),"run",r.elapsed,0,Color.WHITE,false,1,false,-1,0,wear)
				else:
					g.actor.paint_rider(c,int(m.kind),Vector2(m.x,m.y),108,r.elapsed+member_index*.31,float(b.angle),wear,Color.WHITE,seat,str(m.get("sewer_pose","ride")),float(m.get("sewer_board",0)) if m.get("sewer_pose","")=="board" else float(b.duck_left))
		if exit_t<.88: Art.boat(c,p,96,angle,Color(1,1,1,1-smoothstep(.65,.88,exit_t)),true)
		if b.bump<-.5: c.draw_arc(p+Vector2(65,-9),19,-1,1,12,Color(1,.75,.35,minf(.8,-float(b.bump)/25)),2,true)
	for e in s.objects:
		if not e.taken and e.kind in ["pipe","gate"]: object(g,s,e)
	if s.phase=="entry": g.scenery.sprite(c,g.art.tunnel_mouths[1],Vector2(entry_left-30,r.FLOOR-215),430)
	if s.phase=="exit":
		var source = g.gameplay_ui.ground_texture.region
		var ramp = PackedVector2Array([Vector2(boundary-210,s.WATER+30),Vector2(boundary+45,r.FLOOR-22),Vector2(boundary+45,r.FLOOR+85),Vector2(boundary-210,s.WATER+85)])
		var uvs = PackedVector2Array([Vector2(source.position.x,source.position.y),Vector2(source.end.x,source.position.y),Vector2(source.end.x,source.position.y+180),Vector2(source.position.x,source.position.y+180)])
		for i in range(uvs.size()): uvs[i] /= g.gameplay_ui.ground_texture.atlas.get_size()
		c.draw_polygon(ramp,PackedColorArray([Color.WHITE]),uvs,g.gameplay_ui.ground_texture.atlas)
		g.scenery.sprite(c,g.art.tunnel_mouths[1],Vector2(boundary-30,r.FLOOR-215),430)
		for i in range(r.members.size()):
			var m = r.members[i]
			g.actor.paint_space(c,int(m.kind),Vector2(m.x,m.y),107,r.elapsed+i*.13,"return" if exit_t>.55 else "launch",0,r.cosmetics_for(m,int(m.kind)))
	for item in s.casualties:
		var t = float(item.age);var p = Vector2(item.p)+Vector2(-t*200,-sin(t*PI)*55+t*t*145)
		g.actor.paint_space(c,int(item.kind),p,84,t,"ejected",0,item.wear,Color(1,1,1,1-smoothstep(.5,1,t)))
	for item in s.splashes: splash(g,s,item)
	if s.phase!="exit":
		water(g,s,true,INF,1,entry_left)
		if s.phase!="entry" or s.entry_launch()>.65: flood(g,s)
		if s.phase=="ride": speed_streaks(g,s)
	else: water(g,s,true,boundary,1-smoothstep(.5,.90,exit_t))

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
	var height = 445+s.pressure*95+sin(s.age*3)*9;var base = s.WATER+72
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

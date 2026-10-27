extends RefCounted
const Old = preload("res://scripts/bird_art.gd")
const Art = preload("res://scripts/sewer_art.gd")

func view_rect(g) -> Rect2:
	return Rect2(g.scenery.view_left,g.scenery.view_top,g.scenery.view_right-g.scenery.view_left,g.scenery.view_bottom-g.scenery.view_top)

func exit_boundary(g,s) -> float:
	var view = view_rect(g);var t = clampf(s.phase_age/s.EXIT_SECONDS,0,1)
	return lerpf(view.end.x+250,view.position.x-750,smoothstep(.03,.91,t))

func background(g,s) -> void:
	var c = g.paint_target;var view = view_rect(g)
	var clip_right = view.end.x
	if s.phase=="exit":
		# Render the exact same district, sky, tunnel state and world coordinate
		# that ordinary gameplay uses. There is no alternate painted city.
		g.scenery.paint(c,g.runner,g.ui_time)
		clip_right = exit_boundary(g,s)
	elif s.phase=="entry": g.scenery.paint(c,g.runner,g.ui_time)
	var alpha = smoothstep(.02,.50,s.phase_age/s.ENTRY_SECONDS) if s.phase=="entry" else 1.0
	var tex = Old.texture("sewer");var height = maxf(760,view.size.y+40)
	var size = tex.get_size()*height/tex.get_height();var stride = size.x-140
	var offset = fposmod(s.scroll*.42,stride)
	for i in range(-1,ceili(view.size.x/stride)+2):
		blend_tile(c,tex,Rect2(view.position+Vector2(i*stride-offset,-20),size),alpha,view.position.x,clip_right)
	if s.phase=="exit": return
	var catwalk_y = view.position.y-20+height*.588
	# Runners use the ledge already painted in the sewer architecture.
	s.life.paint(g,s,catwalk_y)
	for i in range(7):
		var at = Vector2(view.position.x+fposmod(i*267-s.scroll*.52,view.size.x+160)-80,view.position.y+68+(i%3)*21)
		for j in range(5):
			var t = fposmod(s.age*1.1+j*.22+i,1)
			c.draw_line(at+Vector2(-t*28,t*287),at+Vector2(-t*28-2,t*287+12),Color(.42,.8,.74,.18*alpha),1.4,true)
	var burst = fposmod(s.age+2.8,4.2)
	var point = Vector2(view.position.x+100,s.WATER-175)
	if burst<.85 and s.phase=="ride":
		var a = (1-burst/.85)*.65
		for i in range(5,0,-1): c.draw_circle(point,24+i*20+burst*48,Color(1,.25+i*.045,.04,a*.04))
		for i in range(5):
			var at = point+Vector2(20+burst*(75+i*30),-20-burst*100+burst*burst*165+i*19)
			c.draw_set_transform(at,burst*(i-2))
			c.draw_texture_rect_region(g.gameplay_ui.ground_texture.atlas,Rect2(-12,-8,24+i*3,16),Rect2(90+i*40,94,80,48),Color(.8,.68,.65,a))
		c.draw_set_transform(Vector2.ZERO)

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

func water(g,s,front: bool,right_limit: float = INF,alpha: float = 1.0) -> void:
	var c = g.paint_target;var view = view_rect(g)
	var left = view.position.x-35;var right = minf(view.end.x+35,right_limit);var bottom = view.end.y+100
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
			Art.survivor(c,int(e.get("variant",0)),at,104,s.age+e.age,Color(1,1,1,1-smoothstep(.75,1,t)))
		"rubble":
			Art.prop(c,"wreck",Vector2(e.x,s.WATER-17+sin(s.age*4+int(e.get("encounter",0)))*3),83,sin(s.age*2)*.025)
			c.draw_arc(Vector2(e.x,s.WATER+5),70,0,PI,16,Color(.55,.95,.85,.22),2,true)
		"barrel":
			Art.prop(c,"floating_barrel",Vector2(e.x,s.WATER-28+sin(s.age*5)*3),103,sin(s.age*3)*.04)
			c.draw_circle(Vector2(e.x+12,s.WATER-80),3+sin(s.age*23),Color(1,.52,.14,.8))
		"pipe","gate": suspended(g,s,e)

func paint(g,s) -> void:
	var r = g.runner;var c = g.paint_target;var exit_t = clampf(s.phase_age/s.EXIT_SECONDS,0,1) if s.phase=="exit" else 0.0
	var boundary = exit_boundary(g,s) if s.phase=="exit" else INF
	if s.phase=="exit": g.ground(r.world_px)
	water(g,s,false,boundary,1-smoothstep(.64,.95,exit_t))
	for e in s.objects:
		if not e.taken: object(g,s,e)
	var order = range(s.boats.size());order.sort_custom(func(a,b):return float(s.boats[a].y)<float(s.boats[b].y))
	for index in order:
		var b = s.boats[index];var p = Vector2(b.x,b.y);var angle = float(b.angle)
		if s.phase=="exit": p += Vector2(sin(exit_t*PI)*100,-sin(exit_t*PI)*95+smoothstep(.56,1,exit_t)*460);angle += exit_t*.55
		if exit_t<.65: wake(g,s,b,index)
		if s.phase!="exit":
			# Back passenger first; both hips stay fixed to their own saddle.
			for seat in range(b.ids.size()-1,-1,-1):
				var member_index = r.members.find_custom(func(m):return int(m.id)==int(b.ids[seat]))
				if member_index<0: continue
				var m = r.members[member_index];var wear = r.cosmetics_for(m,int(m.kind))
				g.actor.paint_rider(c,int(m.kind),Vector2(m.x,m.y),108,r.elapsed+member_index*.31,float(b.angle),wear,Color.WHITE,seat)
		if exit_t<.88: Old.prop(c,"jetski",p,100,angle,Color(1,1,1,1-smoothstep(.65,.88,exit_t)))
		if b.bump<-.5: c.draw_arc(p+Vector2(65,-9),19,-1,1,12,Color(1,.75,.35,minf(.8,-float(b.bump)/25)),2,true)
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
		water(g,s,true);flood(g,s)
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
	if s.phase=="entry" and s.phase_age<.55: return
	var c = g.paint_target;var view = view_rect(g);var edge = s.wave_edge()
	var height = 247+s.pressure*85+sin(s.age*4)*5;var base = s.WATER+45
	var points = PackedVector2Array([Vector2(view.position.x-250,view.end.y+100),Vector2(view.position.x-250,base-height*.63),Vector2(edge-100,base-height*.58),Vector2(edge-55,base-height*.37),Vector2(edge-15,base-height*.12),Vector2(edge+28,base+8),Vector2(edge+55,view.end.y+100)])
	var uvs = PackedVector2Array()
	for p in points: uvs.append(Vector2(.42+sin(p.x*.01+s.age)*.08,.8+clampf((p.y-base+height)/height,0,1)*.2))
	c.draw_polygon(points,PackedColorArray([Color(.42,.78,.79,.96)]),uvs,Old.texture("sewer"))
	Art.crest(c,Vector2(edge+15,base),height,s.age)
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

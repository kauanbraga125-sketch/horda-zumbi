extends RefCounted
const Art = preload("res://scripts/bird_art.gd")
var notice = ""
var notice_left = 0.0

func notify(message: String) -> void: notice = message;notice_left = 2.4

func background(g,s) -> void:
	var c = g.paint_target
	var view = Rect2(g.scenery.view_left,g.scenery.view_top,g.scenery.view_right-g.scenery.view_left,g.scenery.view_bottom-g.scenery.view_top)
	if s.phase=="exit":
		var t = clampf(s.phase_age/s.EXIT_SECONDS,0,1)
		if t>.84: g.scenery.paint(c,g.runner,g.ui_time)
		else: c.draw_rect(view,Color("19112d"))
		var tex = Art.texture("sewer_exit")
		var width = view.size.x*2.5;var height = 800.0
		var position = Vector2(view.position.x-view.size.x*(.20+1.30*smoothstep(0,.92,t)),lerpf(450,g.runner.FLOOR,smoothstep(0,1,t))-.565*height)
		g.runner.space.atmosphere.orbit(c,tex,Rect2(position,Vector2(width,height)),view.position.y,1-smoothstep(.84,1,t))
		return
	var alpha = 1.0-smoothstep(.50,1,s.phase_age/s.EXIT_SECONDS) if s.phase=="exit" else smoothstep(.06,.62,s.phase_age/s.ENTRY_SECONDS) if s.phase=="entry" else 1.0
	if alpha<1: g.scenery.paint(c,g.runner,g.ui_time)
	var tex = Art.texture("sewer");var height = maxf(760,view.size.y+40);var size = tex.get_size()*height/tex.get_height()
	var stride = size.x-140
	var offset = fposmod(s.scroll*.30,stride)
	for i in range(-1,3):
		blend_tile(c,tex,Rect2(view.position+Vector2(i*stride-offset,-20),size),alpha)
	if s.phase=="exit": return
	for i in range(5):
		var at = Vector2(view.position.x+fposmod(i*337-s.scroll*.42,view.size.x+100),view.position.y+105+(i%2)*31)
		for j in range(5):
			var t = fposmod(s.age*.9+j*.22+i,1)
			c.draw_line(at+Vector2(sin(t*5+i)*2,t*245),at+Vector2(sin(t*5+i)*2,t*245+9),Color(.42,.8,.74,.2*alpha),1.3,true)
	# Behind the convoy, intermittent bursts and falling masonry animate the collapse.
	var burst = fposmod(s.age+2.8,5.3)
	var point = Vector2(view.position.x+35,s.WATER-150)
	if burst<.9 and s.phase=="ride":
		var a = (1-burst/.9)*.7
		for i in range(5,0,-1): c.draw_circle(point,24+i*20+burst*48,Color(1,.25+i*.045,.04,a*.035))
		for i in range(5):
			Art.prop(c,"rubble",point+Vector2(20+burst*(95+i*30),-20-burst*100+burst*burst*165+i*19),22+i*4,burst*(i-2),Color(1,1,1,a))

func blend_tile(c,tex: Texture2D,rect: Rect2,alpha: float) -> void:
	var fade = 140.0/rect.size.x
	for band in range(2):
		var a = 0.0 if band==0 else fade;var b = fade if band==0 else 1.0
		var points = PackedVector2Array([rect.position+Vector2(a*rect.size.x,0),rect.position+Vector2(b*rect.size.x,0),rect.position+Vector2(b*rect.size.x,rect.size.y),rect.position+Vector2(a*rect.size.x,rect.size.y)])
		var colors = PackedColorArray([Color(1,1,1,0 if band==0 else alpha),Color(1,1,1,alpha),Color(1,1,1,alpha),Color(1,1,1,0 if band==0 else alpha)])
		c.draw_polygon(points,colors,PackedVector2Array([Vector2(a,0),Vector2(b,0),Vector2(b,1),Vector2(a,1)]),tex)

func water(g,s,front: bool) -> void:
	var c = g.paint_target
	var left = g.scenery.view_left-30;var right = g.scenery.view_right+30;var bottom = g.scenery.view_bottom+80
	var base = s.WATER+22 if front else s.WATER-4
	var tex = Art.texture("sewer");var width = 900.0;var offset = fposmod(s.scroll*(1.14 if front else .73),width)
	for column in range(-1,4):
		var x0 = left+column*width-offset
		var sample_left = .30 if posmod(column,2)==0 else .95
		var sample_right = .95 if posmod(column,2)==0 else .30
		var points = PackedVector2Array([Vector2(x0,bottom)]);var uvs = PackedVector2Array([Vector2(sample_left,1)]);var colors = PackedColorArray([Color(.72,.92,.95,.48 if front else 1)])
		var foam = PackedVector2Array()
		for i in range(25):
			var u = float(i)/24;var x = x0+u*width
			var y = base+sin(x*.019+s.age*3.2)*5+sin(x*.037-s.age*4)*2
			points.append(Vector2(x,y));uvs.append(Vector2(lerpf(sample_left,sample_right,u),.735));colors.append(Color(1,1.08,1.05,.48 if front else .98));foam.append(Vector2(x,y))
		points.append(Vector2(x0+width,bottom));uvs.append(Vector2(sample_right,1));colors.append(Color(.72,.92,.95,.48 if front else 1))
		c.draw_polygon(points,colors,uvs,tex)
		c.draw_polyline(foam,Color(.3,.86,.74,.22 if front else .3),2,true)
	for i in range(33 if front else 12):
		var x = left+fposmod(i*93.7-s.scroll*(1.14 if front else .7),right-left)
		var y = base+12+(i%5)*19+sin(s.age*2+i)*4
		c.draw_line(Vector2(x,y),Vector2(x+14+i%4*7,y-1),Color(.36,.94,.83,.12 if front else .18),1.5,true)

func wake(g,s,b: Dictionary,index: int) -> void:
	if b.y<s.water_y(b.x)-42: return
	var c = g.paint_target
	for i in range(10):
		var t = fposmod(s.age*1.8+i*.113+index*.21,1)
		var point = Vector2(b.x-75-t*120,b.y+25+t*15+sin(i*3+s.age*4)*5)
		c.draw_arc(point,5+t*10,PI*.1,PI*.9,8,Color(.65,1,.95,(1-t)*.52),2,true)
	for i in range(4):
		var t = fposmod(s.age*2.3+i*.27+index,1)
		c.draw_circle(Vector2(b.x-65-t*100,b.y+15-t*30+t*t*43),2.5*(1-t)+.4,Color(.75,1,.95,(1-t)*.6))

func paint(g,s) -> void:
	var r = g.runner;var c = g.paint_target
	var exit_t = clampf(s.phase_age/s.EXIT_SECONDS,0,1) if s.phase=="exit" else 0.0
	if exit_t>.84: g.ground(r.world_px)
	if s.phase!="exit": water(g,s,false)
	for e in s.objects:
		if e.taken: continue
		var p = Vector2(e.x,e.y)
		match e.kind:
			"coin": g.scenery.sprite(c,g.art.items[1],p,31,Color.WHITE,sin(s.age*6+e.age)*.2)
			"rescue":
				var a = 1-smoothstep(.3,.55,e.age) if e.state=="capture" else 1.0
				var bob = sin(s.age*3+e.age)*6
				Art.prop(c,"buoy",p+Vector2(0,26+bob),46,0,Color(1,1,1,a))
				g.actor.passenger(c,4,p+Vector2(0,bob),62,s.age, sin(s.age*2)*.04)
			"rubble": Art.prop(c,"rubble",p+Vector2(0,10+sin(s.age*3)*4),73,sin(s.age*2)*.04)
			"barrel":
				Art.prop(c,"barrel",p+Vector2(0,2+sin(s.age*4)*4),95,sin(s.age*2)*.07)
				c.draw_circle(p-Vector2(0,40),5+sin(s.age*19)*1.5,Color(1,.36,.10,.65))
			"pipe":
				Art.prop(c,"pipe",p,121)
				for i in range(8):
					var t = fposmod(s.age*2+i*.12,1)
					c.draw_line(p+Vector2(65,50+t*88),p+Vector2(65,58+t*88),Color(.3,.9,.7,.38*(1-t)),2,true)
	var order = range(s.boats.size());order.sort_custom(func(a,b):return float(s.boats[a].y)<float(s.boats[b].y))
	for index in order:
		var b = s.boats[index];var p = Vector2(b.x,b.y)
		var angle = float(b.angle)
		if s.phase=="exit": p += Vector2(sin(exit_t*PI)*130,-sin(exit_t*PI)*115+smoothstep(.6,1,exit_t)*390);angle += exit_t*.5
		if exit_t<.95: wake(g,s,b,index)
		if s.phase!="exit":
			for id in b.ids:
				var member_index = r.members.find_custom(func(m):return int(m.id)==int(id))
				if member_index<0: continue
				var m = r.members[member_index];var foot = Vector2(m.x,m.y)
				var wear = r.cosmetics_for(m,int(m.kind))
				g.actor.paint_rider(c,int(m.kind),foot,102,r.elapsed+member_index*.31,float(b.angle),wear,Color.WHITE)
		if exit_t<.93: Art.prop(c,"jetski",p,100,angle)
		if b.bump<-.5:
			c.draw_arc(p+Vector2(65,-9),19,-1,1,12,Color(1,.75,.35,minf(.8,-float(b.bump)/25)),2,true)
	if s.phase=="exit":
		Art.prop(c,"ramp",Vector2(g.scenery.view_left+120,s.WATER+12),165,0,Color(1,1,1,1-smoothstep(.3,.7,exit_t)))
		for i in range(r.members.size()):
			var m = r.members[i]
			g.actor.paint_space(c,int(m.kind),Vector2(m.x,m.y),107,r.elapsed+i*.13,"return" if exit_t>.55 else "launch",0,r.cosmetics_for(m,int(m.kind)))
	for item in s.casualties:
		var t = float(item.age);var p = Vector2(item.p)+Vector2(-t*130,-sin(t*PI)*65+t*t*100)
		g.actor.paint_space(c,int(item.kind),p,84,t,"ejected",0,item.wear,Color(1,1,1,1-smoothstep(.5,1,t)))
	for splash in s.splashes:
		var t = float(splash.age);var p = Vector2(splash.p)
		if splash.explosion:
			for i in range(4,0,-1): c.draw_circle(p,15+i*12+t*54,Color(1,.24+i*.09,.04,(1-t)*.05))
		for i in range(10):
			var speed = 50+i*13;var a = -PI*.9+i*PI*.08
			var at = p+Vector2.from_angle(a)*t*speed+Vector2(-t*85,t*t*180)
			c.draw_circle(at,(3+i%3)*(1-t),Color(1,.6,.18,1-t) if splash.explosion else Color(.65,1,.92,1-t))
	if s.phase!="exit":
		water(g,s,true);flood(g,s)
	if s.phase=="entry":
		var cover = smoothstep(.08,.35,s.phase_age/s.ENTRY_SECONDS)*(1-smoothstep(.55,.9,s.phase_age/s.ENTRY_SECONDS))
		c.draw_rect(Rect2(g.scenery.view_left,g.scenery.view_top,g.scenery.view_right-g.scenery.view_left,g.scenery.view_bottom-g.scenery.view_top),Color(.025,.02,.06,cover*.6))

func flood(g,s) -> void:
	var c = g.paint_target;var left = g.scenery.view_left
	var edge = left+20+s.pressure*135;var base = s.WATER+20;var height = 65+s.pressure*100
	var points = PackedVector2Array([Vector2(left-50,g.scenery.view_bottom+40),Vector2(left-50,base-height)])
	for i in range(25):
		var t = float(i)/24;points.append(Vector2(lerpf(left-20,edge,t),base-sin(t*PI*.6)*height+sin(s.age*5+t*12)*5))
	points.append(Vector2(edge+40,g.scenery.view_bottom+40))
	c.draw_colored_polygon(points,Color(.08,.53,.48,.90))
	for i in range(19):
		var t = float(i)/18
		var p = Vector2(lerpf(left-20,edge,t),base-sin(t*PI*.6)*height+sin(s.age*5+t*12)*5)
		c.draw_arc(p,7+(i%3)*3,PI*.9,PI*1.9,10,Color(.7,1,.92,.64),2,true)

func hud(g,s) -> void:
	var view: Rect2 = g.full_rect();var o = view.position;var right = view.end.x
	for i in range(2):
		var box = Rect2(o+Vector2(23+i*151,19),Vector2(140,68))
		g.home_menu.slab(g,box,Color("231b32"),Color("937894"),11,3)
		g.home_menu.label(g,"HORDA" if i==0 else "MOEDAS",box.position+Vector2(12,20),13,g.MINT,false)
		g.home_menu.label(g,str(g.runner.active_count() if i==0 else g.runner.coins),box.position+Vector2(13,54),30,g.CREAM if i==0 else g.GOLD,false)
	var centre = Rect2(o.x+345,o.y+19,maxf(240,view.size.x-690),68)
	g.home_menu.slab(g,centre,Color("231b32"),Color("937894"),11,3)
	g.home_menu.label(g,"FUGA PELO ESGOTO" if s.phase=="ride" else "SALTO DE SAÍDA" if s.phase=="exit" else "TODOS A BORDO!",centre.get_center()+Vector2(0,-9),20,g.GOLD,true,centre.size.x-20)
	g.progress_bar(Rect2(centre.position+Vector2(16,43),Vector2(centre.size.x-32,9)),1-float(s.left)/s.duration,g.MINT)
	var timer = Rect2(right-319,o.y+19,192,68)
	g.home_menu.slab(g,timer,Color("231b32"),Color("937894"),11,3)
	g.home_menu.label(g,"SAÍDA EM %d s" % ceili(s.left) if s.phase=="ride" else "SALTANDO!" if s.phase=="exit" else "EMBARCANDO",timer.get_center()+Vector2(0,9),23,g.CREAM,true,170)
	var pause = Rect2(right-105,o.y+19,73,68)
	g.home_menu.slab(g,pause,Color("493053"),Color("bd915b"),11,3);g.gameplay_ui.glyph(g,"pause",pause.get_center(),34,g.CREAM);g.home_menu.register(g,pause,"pause")
	if notice_left>0:
		g.home_menu.label(g,notice,Vector2(view.get_center().x,o.y+124),23,g.CREAM,true,view.size.x-80)
	g.home_menu.label(g,"ENCHENTE",Vector2(o.x+27,o.y+111),15,g.MINT,false)
	g.progress_bar(Rect2(o.x+27,o.y+118,190,8),s.pressure,g.CORAL if s.pressure>.65 else g.MINT)
	g.home_menu.label(g,"ALMAS %d • MAIOR HORDA %d" % [g.runner.souls,g.runner.max_horde],Vector2(right-290,o.y+118),15,g.MINT,false,265)
	if s.age<8 and notice_left<=0: g.home_menu.label(g,"TOQUE PARA SALTAR • SEGURE PARA ALONGAR",Vector2(view.get_center().x,o.y+158),19,g.CREAM,true,view.size.x-80)
	if g.lab_active:
		var labels = ["RECOMEÇAR","ENCHENTE +","IR PARA SAÍDA"]
		for i in range(3):
			var width = (view.size.x-85)/3
			g.button(Rect2(o.x+25+i*(width+15),view.end.y-73,width,44),labels[i],["lab_sewer_restart","lab_sewer_wave","lab_sewer_exit"][i],Color("513c67"),-2,18)

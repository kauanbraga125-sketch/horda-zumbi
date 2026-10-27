extends RefCounted
## One presentation layer: shared art, cabin occlusion and one notice slot.
static var textures: Dictionary = {}
static var ship_layout: Dictionary = {}
var notices: Array[Dictionary] = []
var current: Dictionary = {}
var clock = 0.0
var controls_left = 0.0
static var props: Dictionary = {}
var impacts: Array[Dictionary] = []
var casualties: Array[Dictionary] = []

func warm() -> void:
	if not textures.is_empty(): return
	for key in ["tour_bus-front","tour_bus-inside","fighter-front","fighter-inside","vortex"]:
		var image = Image.new()
		assert(image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/space_v133/"+key+".png"))==OK)
		textures[key] = ImageTexture.create_from_image(image)
	ship_layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/space_v133/layout.json")).ships

func prop(g,key: String,point: Vector2,height: float,alpha: float = 1.0,angle: float = 0.0) -> void:
	if props.is_empty():
		for name in ["pylon","portal","rock","core","mine"]:
			var im = Image.new()
			assert(im.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/"+("space_v135/" if name=="mine" else "space_v134/")+name+".png"))==OK)
			props[name] = ImageTexture.create_from_image(im)
	var tex: Texture2D = props[key];var size = tex.get_size()*height/tex.get_height()
	g.paint_target.draw_set_transform(point,angle)
	g.paint_target.draw_texture_rect(tex,Rect2(-size*.5,size),false,Color(1,1,1,alpha))
	g.paint_target.draw_set_transform(Vector2.ZERO)

func reset() -> void:
	notices.clear();current.clear();impacts.clear();casualties.clear();clock = 0;controls_left = 0

func notify(message: String, priority: int = 1, seconds: float = 1.8) -> void:
	if message.is_empty(): return
	if not current.is_empty() and str(current.text)==message: return
	for n in notices:
		if str(n.text)==message: return
	var next = {"text":message,"priority":priority,"left":seconds,"expires":clock+3.0}
	if current.is_empty() or priority>int(current.priority): current = next
	else:
		if notices.size()>=3: notices.pop_front()
		notices.append(next)

func advance(dt: float) -> void:
	for i in range(casualties.size()-1,-1,-1):
		casualties[i].age += dt
		if float(casualties[i].age)>.72: casualties.remove_at(i)
	for i in range(impacts.size()-1,-1,-1):
		impacts[i].age += dt
		if float(impacts[i].age)>.32: impacts.remove_at(i)
	clock += dt;controls_left = maxf(0,controls_left-dt)
	if not current.is_empty():
		current.left = float(current.left)-dt
		if float(current.left)<=0: current.clear()
	while current.is_empty() and not notices.is_empty():
		var next = notices.pop_front()
		if float(next.expires)>clock: current = next

func takeoff_shift(s) -> float:
	if s.phase!="ascent": return 0.0
	var progress = transition_progress(s)
	return 420*pow(clampf(progress/.48,0,1),1.8) if progress<.48 else 0.0

func rise_offset(progress: float) -> float:
	return -145*smoothstep(.10,.54,progress)*(1-smoothstep(.73,1,progress))

func impact(point: Vector2,normal: Vector2,guarded: bool) -> void:
	if impacts.size()>13: return
	impacts.append({"p":point,"n":normal,"age":0.0,"guarded":guarded})

func casualty(event: Dictionary) -> void:
	if casualties.size()>=12: casualties.pop_front()
	casualties.append({"kind":int(event.kind),"p":Vector2(event.foot_x,event.foot_y),"height":float(event.space_height),"wear":event.space_wear.duplicate(),"age":0.0})

func paint_impacts(g) -> void:
	var c = g.paint_target
	for actor in casualties:
		var age = float(actor.age)
		var point = Vector2(actor.p)+Vector2(-90*age,65*age+45*age*age)
		g.actor.paint_space(c,int(actor.kind),point,float(actor.height)*(1-age*.17),age,"ejected",80,actor.wear,Color(1,.86,.8,1-smoothstep(.25,.72,age)))
	for hit in impacts:
		var age = float(hit.age);var opacity = 1-age/.32
		var color = Color(.5,.88,1,opacity) if hit.guarded else Color(1,.68,.32,opacity)
		for j in range(4):
			var direction = Vector2(hit.n).rotated((j-1.5)*.5)
			var p = Vector2(hit.p)+direction*(4+age*90)
			c.draw_line(p,p+direction*(4+opacity*6),color,1.4,true)
		c.draw_arc(hit.p,5+age*24,Vector2(hit.n).angle()-.8,Vector2(hit.n).angle()+.8,10,Color(color,opacity*.6),2,true)

func cabin_view(g) -> SubViewport:
	var view = g.get_node_or_null("SpaceCabin") as SubViewport
	if is_instance_valid(view): return view
	view = SubViewport.new();view.name = "SpaceCabin";view.size = Vector2i(640,400)
	view.transparent_bg = true;view.disable_3d = true;view.gui_disable_input = true
	view.world_2d = World2D.new();view.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	g.add_child(view)
	var clip = Control.new();clip.name = "WindowClip";clip.clip_contents = true;clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(clip)
	var actors = Node2D.new();actors.name = "Occupants";clip.add_child(actors)
	var mask = ShaderMaterial.new();mask.shader = load("res://scripts/cabin_mask.gdshader");actors.material = mask
	actors.draw.connect(func():g.runner.space.visual.paint_passengers(g,actors))
	return view

func paint_passengers(g,canvas: Node2D) -> void:
	if not g.runner.space.active or g.runner.space.battle.pilot_left<=0: return
	var kind = str(g.runner.space.battle.pilot_kind)
	if not ship_layout.has(kind): return
	var window: Array = ship_layout[kind].window
	var count = mini(1 if kind=="fighter" else 2,g.runner.members.size())
	var height = minf(151,float(window[3])*1.70)
	for i in range(count):
		var m = g.runner.members[i]
		var foot = Vector2(float(window[0])+float(window[2])*.5+(i-(count-1)*.5)*minf(95,float(window[2])*.43),float(window[1]+window[3])+height*.35)
		g.actor.paint_space(canvas,int(m.kind),foot,height,g.runner.elapsed+i*.2,"pilot",0,g.runner.cosmetics_for(m,int(m.kind)))

func cabin(g,s) -> void:
	warm()
	var b = s.battle;var kind = str(b.pilot_kind)
	if not ship_layout.has(kind): return
	var c = g.paint_target;var spec: Dictionary = ship_layout[kind]
	var centre = Vector2(s.x+25,s.y-48)
	var scale = 330.0/640.0;var angle = clampf(s.vy*.00018,-.045,.045)
	var root = Transform2D(angle,centre)
	var rect = Rect2(Vector2(-320,-200)*scale,Vector2(640,400)*scale)
	var view = cabin_view(g);view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var clip = view.get_node("WindowClip") as Control
	var window: Array = spec.window
	clip.position = Vector2(window[0],window[1]);clip.size = Vector2(window[2],window[3])
	var occupants = clip.get_node("Occupants") as Node2D
	(occupants.material as ShaderMaterial).set_shader_parameter("window_mask",textures[kind+"-inside"])
	occupants.position = -clip.position;occupants.queue_redraw()
	c.draw_set_transform_matrix(root)
	c.draw_texture_rect(textures[kind+"-inside"],rect,false)
	c.draw_texture_rect(view.get_texture(),rect,false)
	c.draw_texture_rect(textures[kind+"-front"],rect,false)
	c.draw_set_transform(Vector2.ZERO)
	if b.pilot_hit_left>0: c.draw_arc(centre,97,-.8,.8,18,Color(1,.45,.32,b.pilot_hit_left*1.8),3,true)

func vortex(g,s,point: Vector2,size: float,alpha: float = 1.0) -> void:
	warm()
	var tex: Texture2D = textures.vortex
	var scale = size/tex.get_width()
	var extent = tex.get_size()*scale
	g.paint_target.draw_set_transform(point,sin(s.age*.22)*.035,Vector2.ONE*(1+sin(s.age*.65)*.016))
	g.paint_target.draw_texture_rect(tex,Rect2(-extent*.5,extent),false,Color(1,1,1,alpha))
	g.paint_target.draw_set_transform(Vector2.ZERO)

func transition_progress(s) -> float:
	if s.phase=="ascent": return clampf(s.phase_age/s.ASCENT_SECONDS,0,1)
	if s.phase=="return": return 1-clampf(s.phase_age/s.RETURN_SECONDS,0,1)
	return 1.0

func ground_visible(s) -> bool:
	return s.phase in ["ascent","return"] and transition_progress(s)<.48

func transition(g,s) -> void:
	if s.phase not in ["ascent","return"]: return
	var t = transition_progress(s)
	# Switch opaque scenes behind a short cloud passage; city and Earth never bleed.
	var cover = smoothstep(.23,.44,t)*(1-smoothstep(.52,.76,t))
	var view = Rect2(g.scenery.view_left,g.scenery.view_top,g.scenery.view_right-g.scenery.view_left,g.scenery.view_bottom-g.scenery.view_top)
	if cover>0: g.paint_target.draw_rect(view,Color(.055,.045,.12,cover))
	if t>.12 and t<.86:
		for i in range(18):
			var x = view.position.x+fposmod(i*117.3,view.size.x)
			var y = view.position.y+fposmod(i*77.1+s.age*320,view.size.y)
			g.paint_target.draw_line(Vector2(x,y),Vector2(x-2,y+14+cover*32),Color(.65,.86,1,cover*.32),1.5,true)

func layout(view: Rect2) -> Dictionary:
	var top = view.position.y+18
	var width = clampf(view.size.x-700,240,440)
	return {"horde":Rect2(view.position.x+24,top,126,64),"coins":Rect2(view.position.x+162,top,126,64),
		"impulse":Rect2(view.get_center().x-width*.5,top,width,64),
		"time":Rect2(view.end.x-266,top,150,64),"pause":Rect2(view.end.x-94,top,68,64),
		"notice":Rect2(view.get_center().x-minf(510,view.size.x-70)*.5,top+78,minf(510,view.size.x-70),42)}

func hud(g,s) -> void:
	var r = g.runner;var view = g.full_rect();var d = layout(view)
	for key in ["horde","coins","time","impulse"]:
		g.home_menu.slab(g,d[key],Color(.12,.09,.19,.94),Color("7a608f"),12,2)
	for key in ["horde","coins"]:
		var rect: Rect2 = d[key]
		g.home_menu.label(g,"HORDA" if key=="horde" else "MOEDAS",rect.position+Vector2(12,18),12,g.MINT,false)
		g.scenery.sprite(g,g.actor.zombie.portrait if key=="horde" else g.art.items[1],rect.position+Vector2(28,41),37)
		g.home_menu.label(g,str(r.active_count() if key=="horde" else r.coins),rect.position+Vector2(54,51),28,g.CREAM if key=="horde" else g.GOLD,false,64)
	var timer: Rect2 = d.time
	g.home_menu.label(g,"ESPAÇO",timer.position+Vector2(12,18),12,g.MINT,false)
	var note = "SUBINDO ↑" if s.phase in ["ascent","boost"] else "POUSANDO" if s.phase=="return" else "%d s" % ceili(s.left)
	g.home_menu.label(g,note,timer.position+Vector2(12,49),24,g.CREAM if s.left>5 else g.CORAL,false,126)
	var impulse: Rect2 = d.impulse
	var title = s.ZONES[s.zone()] if s.phase not in ["ascent","return"] else "DEIXANDO A TERRA" if s.phase=="ascent" else "RETORNO À CORRIDA"
	g.home_menu.label(g,title,impulse.position+Vector2(impulse.size.x*.5,21),15,g.GOLD,true,impulse.size.x-22)
	var bar = Rect2(impulse.position+Vector2(13,31),Vector2(impulse.size.x-26,7))
	g.draw_rect(bar,Color("171125"));bar.size.x *= float(s.charge)/100.0;g.draw_rect(bar,g.MINT)
	var info = (("PORTAL À FRENTE" if s.routes.exit_spawned else "PRÓXIMO PORTAL") if s.charge>=100 else "IMPULSO • %d%%" % int(s.charge)) if s.phase=="flight" else "PREPARANDO SALTO" if s.phase=="boost" else ""
	if not info.is_empty(): g.home_menu.label(g,"%d/4  •  %s" % [s.zone()+1,info],impulse.position+Vector2(impulse.size.x*.5,54),12,g.MINT,true,impulse.size.x-20)
	var pause_rect: Rect2 = d.pause
	g.home_menu.slab(g,pause_rect,Color("493053"),Color("bd915b"),12,3);g.gameplay_ui.glyph(g,"pause",pause_rect.get_center(),32,g.CREAM);g.home_menu.register(g,pause_rect,"pause")
	if not current.is_empty():
		var rect: Rect2 = d.notice
		var perfect = str(current.text)=="PERFECT!"
		g.home_menu.slab(g,rect,Color(.13,.08,.2,.95),g.GOLD if perfect else Color("80688e"),11,2)
		g.home_menu.label(g,str(current.text),rect.get_center()+Vector2(0,8),26 if perfect else 19,g.GOLD if perfect else g.CREAM,true,rect.size.x-26)
	g.home_menu.label(g,"ALMAS %d  •  MAIOR HORDA %d" % [r.souls,r.max_horde],Vector2(view.position.x+28,view.end.y-(180 if g.lab_active and g.lab_kind=="space" else 110)),15,g.MINT,false,360)
	var bottom = view.end.y-(154 if g.lab_active and g.lab_kind=="space" else 85)
	if s.phase=="flight" or s.phase=="boost":
		var dash_ready = s.phase=="flight" and s.dash_cooldown<=0
		g.button(Rect2(view.end.x-218,bottom,194,57),"SUBINDO..." if s.phase=="boost" else "INVESTIDA" if dash_ready else "RECARGA %.1f" % s.dash_cooldown,"space_dash",Color("4c786a") if dash_ready else Color("513c67"),-2,20)
		if s.battle.pilot_left>0:
			g.home_menu.label(g,"NAVE • %d s" % ceili(s.battle.pilot_left),Vector2(view.position.x+28,bottom+16),18,g.MINT,false,220)
			for i in range(3):
				g.draw_circle(Vector2(view.position.x+37+i*20,bottom+37),5,g.MINT if i<s.battle.pilot_hp else Color("44344f"))
		elif s.battle.power_left>0:
			g.home_menu.label(g,("SIMBIONTE" if s.battle.power_kind==7 else "ESCUDO %d" % s.battle.shield_charges)+" • %d s" % ceili(s.battle.power_left),Vector2(view.position.x+28,bottom+29),18,g.MINT,false,300)
		if s.chain_left>0 and s.chain>1:
			g.home_menu.label(g,"COMBO x%d" % s.chain,Vector2(view.end.x-120,bottom-17),22,g.GOLD,true,180)
		if controls_left>0:
			g.home_menu.label(g,"ARRASTE EM TODAS AS DIREÇÕES  •  INVESTIDA PARA ATACAR",Vector2(view.get_center().x,bottom-15),16,g.CREAM,true,view.size.x-60)
	if g.lab_active and g.lab_kind=="space":
		var labels = ["RECOMEÇAR","TEMPO: %d s" % int(s.duration),"CAMADA +","TESTAR PODER","POUSAR"]
		var actions = ["lab_space_restart","lab_space_time","lab_space_zone","lab_space_power","lab_space_land"]
		var width = (view.size.x-80)/5
		for i in range(5): g.button(Rect2(view.position.x+20+i*(width+10),view.end.y-70,width,43),labels[i],actions[i],Color("513c67"),-2,16)

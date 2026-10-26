extends RefCounted
# Reward data is already saved. This class only presents that immutable report.
const SOUL_FLIGHT = 0.72
const FIRST_ARRIVAL = 1.0
const BOARD_PAUSE = 0.76
var presentation = HordeExperimentPresentation.new()
var entered = false
var clock = 0.0
var souls = 0
var old_altar = 0
var landed = 0
var interval = 0.15
var essence_at = 1.8
var report: Dictionary = {}
var reward_coins = 0
var reward_eyes = 0
var reward_level = 0
var reward_clock = -20.0
var full_clock = -20.0
var coin_beat = -1
var empty_style: StyleBoxFlat
var filled_style: StyleBoxFlat
var flash_style: StyleBoxFlat
var soul_frames: Array[AtlasTexture] = []
const SOUL_SEQUENCE = [0,1,2,5,3,5,2,1]

func _init() -> void:
	empty_style = cell_style(Color("25172f"), Color("61416f"))
	filled_style = cell_style(Color("16434a"), Color("67decf"))
	flash_style = cell_style(Color("267c83"), Color("c5fff1"))
	var image=Image.new()
	if image.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/results_v110/souls.webp"))==OK:
		var sheet=ImageTexture.create_from_image(image)
		var meta=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/results_v110/manifest.json"))
		for region in meta.regions:
			var tex=AtlasTexture.new();tex.atlas=sheet;tex.region=Rect2(region[0],region[1],region[2],region[3]);tex.filter_clip=true
			soul_frames.append(tex)

func soul(g, point: Vector2, height: float, time: float, tint: Color = Color.WHITE, animate: bool = true) -> void:
	if soul_frames.is_empty(): g.animated_soul(point,height,time,tint);return
	var phase=fposmod(time*3.1,SOUL_SEQUENCE.size()) if animate else 0.0
	var index=floori(phase);var blend=smoothstep(0.25,0.9,phase-index) if animate else 0.0
	for layer in range(2):
		var weight=1.0-blend if layer==0 else blend
		if weight<0.005: continue
		var texture=soul_frames[SOUL_SEQUENCE[(index+layer)%SOUL_SEQUENCE.size()]]
		var size=texture.get_size()*height/texture.get_height()
		g.paint_target.draw_texture_rect(texture,Rect2(point-size*0.5,size),false,Color(tint,tint.a*weight))

func cell_style(face: Color, edge: Color) -> StyleBoxFlat:
	var box = StyleBoxFlat.new();box.bg_color = face;box.border_color = edge
	box.set_border_width_all(1);box.border_width_bottom = 2;box.set_corner_radius_all(7)
	box.anti_aliasing = true
	return box

func reset() -> void:
	entered = false;clock = 0.0;landed = 0;reward_coins = 0;reward_eyes = 0
	reward_level = 0;reward_clock = -20;full_clock = -20;coin_beat = -1
	report.clear();presentation.reset(1,0)

func enter(g) -> void:
	if entered: return
	entered = true;clock = 0.0;landed = 0
	souls = maxi(0,int(g.runner.souls));old_altar = clampi(int(g.run_report.get("old_altar",g.data.altar_souls)),0,99)
	interval = clampf(4.8/maxf(24.0,float(souls)),0.025,0.15)
	essence_at = clampf(0.9+float(mini(souls,20))*interval*0.4,1.3,2.1)
	report = {"old_level":int(g.data.player_level),"old_progress":int(g.data.level_souls),"points":0,"coins":0,"eyes":0,"bonuses":0,"steps":[]}
	if not g.run_ritual_reports.is_empty():
		report.old_level=int(g.run_ritual_reports[0].old_level);report.old_progress=int(g.run_ritual_reports[0].old_progress)
		for part in g.run_ritual_reports:
			for key in ["points","coins","eyes","bonuses"]: report[key]+=int(part.get(key,0))
			report.steps.append_array(part.get("steps",[]))
	presentation.reset(int(report.old_level),float(report.old_progress))
	if int(report.points)>0: presentation.enqueue(report,1.8)
	g.result_time=0

func leave(g) -> void:
	# Navigation finishes the presentation, never pays or debits any reward.
	if not entered: return
	landed=souls;clock=maxf(clock,arrival_at(souls-1)+BOARD_PAUSE+1.0 if souls>0 else 1.0)
	reward_coins=int(report.get("coins",0));reward_eyes=int(report.get("eyes",0));reward_level=int(g.data.player_level) if int(report.get("bonuses",0))>0 else 0
	presentation.reset(int(g.data.player_level),float(g.data.level_souls))
	g.sound.results_fill(false)
	g.hub.presentation.reset(int(g.data.player_level),float(g.data.level_souls))

func arrival_at(index: int) -> float:
	return FIRST_ARRIVAL+index*interval+floori(float(old_altar+index)/100.0)*BOARD_PAUSE

func arrival_count(at: float) -> int:
	# Binary search keeps long runs bounded; only visible flights are drawn.
	var low=0;var high=souls
	while low<high:
		var mid=(low+high)/2
		if arrival_at(mid)<=at: low=mid+1
		else: high=mid
	return low

func update(g, dt: float) -> void:
	if not entered: enter(g)
	var before=clock;clock+=maxf(0,dt);g.result_time=clock
	var previous=landed;landed=arrival_count(clock)
	for i in range(maxi(previous,landed-4),landed):
		# A stalled frame cannot replay a burst of old sound cues.
		if clock-arrival_at(i)<0.14: g.sound.results_soul(i)
		if (old_altar+i+1)%100==0:
			full_clock=arrival_at(i);g.sound.results_one_shot("result_full",1.0,-13)
	var advance=maxf(0,clock-essence_at)-maxf(0,before-essence_at)
	if advance>0:
		presentation.advance(advance)
		for phase in presentation.transitions:
			if phase.kind=="react": full_clock=clock;g.sound.results_one_shot("result_full",1.08,-14)
			if phase.kind=="award":
				reward_coins+=int(phase.coins);reward_eyes+=int(phase.eyes);reward_level=int(phase.new_level)
				reward_clock=clock;coin_beat=-1;g.sound.results_one_shot("result_reward",1.0,-12)
	var filling=clock>=essence_at and presentation.stage()=="fill"
	g.sound.results_fill(filling,presentation.portion())
	if presentation.stage()=="award":
		var beat=mini(15,floori((presentation.elapsed-0.42)/0.055))
		if beat>coin_beat and beat>=0 and int(presentation.current.coins)>0:
			coin_beat=beat;g.sound.results_one_shot("result_coin",0.96+beat*0.012,-20)
	if not presentation.busy() and clock>=essence_at:
		if presentation.shown_level!=int(g.data.player_level) or not is_equal_approx(presentation.shown_xp,float(g.data.level_souls)):
			presentation.reset(int(g.data.player_level),float(g.data.level_souls))

func board_state() -> Dictionary:
	var total=old_altar+landed;var amount=total%100;var clear=0.0
	if landed>0 and amount==0:
		var age=clock-arrival_at(landed-1)
		if age<BOARD_PAUSE:
			amount=100;clear=smoothstep(0.32,BOARD_PAUSE,age)
	return {"amount":amount,"clear":clear,"graves":floori(float(total)/100.0)*2}

static func layout(view: Rect2) -> Dictionary:
	var margin=maxf(26,view.size.x*0.038)
	var left=view.position.x+margin;var width=view.size.x-margin*2
	var stats: Array[Rect2]=[];var gap=10.0;var stat_w=(width-gap*3)/4
	for i in range(4): stats.append(Rect2(left+i*(stat_w+gap),view.position.y+103,stat_w,70))
	var body=Rect2(left,view.position.y+191,width,view.size.y-290)
	var board=Rect2(body.position,Vector2((width-16)*0.555,body.size.y))
	var chamber=Rect2(board.end.x+16,body.position.y,body.end.x-board.end.x-16,body.size.y)
	var grid=Rect2(board.position+Vector2(21,61),Vector2(board.size.x-42,board.size.y-126))
	var vessel=Rect2(chamber.position+Vector2(chamber.size.x*0.29,45),Vector2(chamber.size.x*0.69,chamber.size.y-112))
	var badge=Rect2(chamber.position+Vector2(16,93),Vector2(chamber.size.x*0.30,chamber.size.y*0.30))
	var reward=Rect2(chamber.position+Vector2(18,chamber.size.y-63),Vector2(chamber.size.x-36,49))
	var nav_y=view.end.y-78
	var nav=[Rect2(left,nav_y,minf(225,width*0.22),58),Rect2(view.get_center().x-minf(290,width*0.29)*0.5,nav_y,minf(290,width*0.29),58),Rect2(left+width-minf(300,width*0.31),nav_y-4,minf(300,width*0.31),66)]
	return {"stats":stats,"body":body,"board":board,"chamber":chamber,"grid":grid,"vessel":vessel,"badge":badge,"reward":reward,"nav":nav,"wallet":Rect2(left+width-308,view.position.y+23,308,58)}

static func cell_rect(grid: Rect2, index: int) -> Rect2:
	var gap=4.0;var size=(grid.size-Vector2.ONE*gap*9)/10.0
	var start=grid.position+Vector2(index%10,int(index/10))*(size+Vector2.ONE*gap)
	var end=start+size
	start=Vector2(ceilf(start.x),ceilf(start.y));end=Vector2(floorf(end.x),floorf(end.y))
	return Rect2(start,end-start)

static func remaining_graves(data: Dictionary) -> int:
	var result=0
	for pair in data.graves:
		for claimed in pair.claimed:
			if not claimed: result+=1
	return result

func paint(g) -> void:
	if not entered: enter(g)
	var d=layout(g.full_rect());var view: Rect2=g.full_rect()
	g.home_menu.backdrop(g,view)
	g.paint_target.draw_rect(view,Color(0.035,0.012,0.065,0.19))
	g.home_menu.label(g,"A NOITE TERMINOU",Vector2(d.body.position.x,view.position.y+59),40,g.GOLD,false,d.body.size.x-335,true,4)
	g.home_menu.label(g,"Suas conquistas ganham vida.",Vector2(d.body.position.x,view.position.y+86),19,g.MINT,false,d.body.size.x-335)
	g.hub.wallet(g,d.wallet)
	stats(g,d.stats)
	framed(g,d.board,"ALTAR DE ALMAS",29)
	framed(g,d.chamber,"EXPERIMENTO DE RESSURREIÇÃO",23)
	grid(g,d)
	chamber(g,d)
	g.pages.button(g,d.nav[0],"MENU","home")
	g.pages.button(g,d.nav[1],"LÁPIDES ("+str(remaining_graves(g.data))+")","graves_open")
	g.pages.button(g,d.nav[2],"JOGAR DE NOVO","play",true,"play")

func framed(g, rect: Rect2, title: String, size: int) -> void:
	g.paint_target.draw_style_box(g.hub.profile_ui.featured,rect)
	var banner=Rect2(rect.position+Vector2(15,9),Vector2(rect.size.x-30,41))
	g.home_menu.slab(g,banner,Color("34213f"),Color("987244"),10,2)
	g.home_menu.label(g,title,banner.get_center()+Vector2(0,9),size,g.GOLD,true,banner.size.x-25,true,2)
	# The existing isolated skull and a few drawn cobweb strands match the menu art.
	HordeExperimentArt.draw(g.paint_target,"specimen_skull",Rect2(rect.get_center().x-14,rect.position.y-16,28,26))
	for side in [0,1]:
		var origin=rect.position+Vector2(13 if side==0 else rect.size.x-13,53)
		var sign_x=1.0 if side==0 else -1.0
		for i in range(3):
			var a=Vector2(sign_x*(12+i*8),3);var b=Vector2(sign_x*2,19+i*6)
			g.paint_target.draw_line(origin+a,origin+b,Color(0.78,0.66,0.83,0.18),0.8,true)

func stats(g, cards: Array[Rect2]) -> void:
	var names=["ALMAS","DISTÂNCIA","MOEDAS","MAIOR HORDA"]
	var values=[str(souls),str(g.runner.distance())+" m",str(g.runner.coins),str(g.runner.max_horde)]
	var art=["mission_souls","mission_distance","mission_coins","mission_horde"]
	for i in range(4):
		var box=cards[i]
		g.paint_target.draw_style_box(g.hub.profile_ui.panel,box)
		if i==0: soul(g,box.position+Vector2(41,34),53,g.ui_time)
		elif i==1: g.scenery.sprite(g.paint_target,g.art.items[4],box.position+Vector2(41,35),47)
		else: HordeExperimentArt.draw(g.paint_target,art[i],Rect2(box.position+Vector2(8,6),Vector2(66,57)))
		g.home_menu.label(g,names[i],box.position+Vector2(78,25),16,g.MINT,false,box.size.x-88)
		g.home_menu.label(g,values[i],box.position+Vector2(78,55),30,g.GOLD,false,box.size.x-88,true,2)

func grid(g, d: Dictionary) -> void:
	var state=board_state();var recent: Dictionary={}
	for i in range(maxi(0,landed-20),landed):
		var age=clock-arrival_at(i)
		if age<0.7: recent[(old_altar+i)%100]=age
	for index in range(100):
		var box=cell_rect(d.grid,index);var active=index<int(state.amount)
		var age=float(recent.get(index,20.0));var pulse=exp(-age*7.0) if active else 0.0
		var clear=float(state.clear)
		var alpha=1.0-smoothstep(float(index%10)*0.045,float(index%10)*0.045+0.55,clear) if clear>0 else 1.0
		g.paint_target.draw_style_box(empty_style,box)
		if active:
			g.paint_target.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
			g.paint_target.draw_style_box(flash_style if pulse>0.45 else filled_style,box.grow(pulse*1.2))
			g.paint_target.draw_line(box.position+Vector2(7,3),Vector2(box.end.x-7,box.position.y+3),Color(0.57,1.0,0.89,0.22*alpha),1,true)
		var size=minf(box.size.y*0.84,box.size.x*0.73)*(1.0+pulse*0.32)
		var point=box.get_center()+Vector2(0,-sin(age*17)*pulse*2.0 if age<0.7 else (sin(g.ui_time*2+index)*0.45 if active else 0))
		if active: glow(g.paint_target,point,size*0.68,Color(0.3,1,0.87,0.13*alpha+pulse*0.12))
		soul(g,point,size,g.ui_time+index*0.13,Color(1,1,1,alpha) if active else Color(0.30,0.24,0.40,0.64),active)
		if pulse>0.07:
			for j in range(4):
				var angle=j*TAU/4+index;var at=point+Vector2(cos(angle),sin(angle))*(7+age*24)
				g.paint_target.draw_circle(at,1.1,Color(0.7,1,0.9,pulse*0.9))
	var board: Rect2=d.board
	g.home_menu.label(g,str(int(state.amount))+" / 100",Vector2(board.position.x+28,board.end.y-30),29,g.MINT,false,board.size.x*0.36,true,2)
	g.home_menu.label(g,"+"+str(landed)+" NESTA PARTIDA",Vector2(board.position.x+board.size.x*0.40,board.end.y-31),17,g.GOLD,false,board.size.x*0.56-18)
	var graves=int(state.graves)
	if graves>0:
		for i in range(2): g.scenery.sprite(g.paint_target,g.hub.grave_texture,Vector2(board.end.x-48+i*17,board.end.y-17),24)
	g.home_menu.label(g,"LÁPIDES GANHAS: "+str(graves),Vector2(board.get_center().x,board.end.y-10),14,g.GOLD,true,board.size.x-70)

func chamber(g, d: Dictionary) -> void:
	var box: Rect2=d.chamber;var badge: Rect2=d.badge;var p=presentation
	var color: Color=HordeExperimentArt.variant(p.shown_level).color
	g.hub.experiment(g,d.vessel)
	g.home_menu.slab(g,badge,Color("2b1937"),Color("916b4c"),10,3)
	HordeExperimentArt.draw(g.paint_target,"specimen_vial",Rect2(badge.get_center().x-22,badge.position.y+5,44,36),Color.WHITE)
	g.home_menu.label(g,"MISSÕES",Vector2(badge.get_center().x,badge.position.y+56),16,g.MINT,true,badge.size.x-12)
	g.home_menu.label(g,"CONCLUÍDAS" if int(report.points)>0 else "CONTINUE JOGANDO",Vector2(badge.get_center().x,badge.position.y+75),13,g.MINT,true,badge.size.x-12)
	g.home_menu.label(g,"+"+str(int(report.points)),Vector2(badge.get_center().x,badge.position.y+104),28,g.CREAM,true,badge.size.x-12,true,2)
	g.home_menu.label(g,"ESSÊNCIA",Vector2(badge.get_center().x,badge.position.y+121),13,g.MINT,true,badge.size.x-12)
	var level=p.shown_level
	var label="NÍVEL "+str(int(p.current.new_level) if p.stage()=="award" else level)
	g.home_menu.label(g,label,Vector2(badge.get_center().x,badge.end.y+29),20,g.GOLD,true,badge.size.x+8)
	g.pages.lines(g,str(HordeExperimentArt.variant(level).name),Rect2(badge.position.x-1,badge.end.y+38,badge.size.x+4,43),14,color,true,2)
	var counter="FRASCO CHEIO!" if p.stage() in ["react","award"] else str(floori(p.shown_xp))+" / "+str(HordeProgress.level_target(level))
	g.home_menu.label(g,counter,Vector2(badge.get_center().x,badge.end.y+101),17,g.MINT if p.stage() in ["react","award"] else g.CREAM,true,badge.size.x+6)
	var reward: Rect2=d.reward
	g.home_menu.slab(g,reward,Color("422336") if reward_level>0 else Color("2a1a34"),g.GOLD if reward_level>0 else Color("8b7053"),11,3)
	HordeExperimentArt.draw(g.paint_target,"mission_coins",Rect2(reward.position+Vector2(6,1),Vector2(58,reward.size.y-2)))
	if reward_level>0:
		g.home_menu.label(g,"SUBIU DE NÍVEL!",reward.position+Vector2(71,20),18,g.GOLD,false,reward.size.x-80,true,2)
		g.home_menu.label(g,"+"+str(reward_coins)+" MOEDAS"+(" · +"+str(reward_eyes)+" OLHOS" if reward_eyes>0 else ""),reward.position+Vector2(71,40),20,g.GOLD,false,reward.size.x-80)
	else:
		g.home_menu.label(g,"ENCHA O FRASCO PARA SUBIR DE NÍVEL",reward.position+Vector2(69,19),13,g.MINT,false,reward.size.x-78)
		var next_coins=100+mini(50,level+1)*10
		g.home_menu.label(g,"PRÊMIO: "+str(next_coins)+" MOEDAS" if level<500 else "NÍVEL MÁXIMO",reward.position+Vector2(69,39),19,g.GOLD,false,reward.size.x-78)

func glow(canvas: CanvasItem, point: Vector2, radius: float, color: Color) -> void:
	for i in range(4,0,-1):
		var tint=color;tint.a*=0.18
		canvas.draw_circle(point,radius*float(i)/2.0,tint)

func soul_position(d: Dictionary, index: int, t: float) -> Vector2:
	var to=cell_rect(d.grid,(old_altar+index)%100).get_center()
	var origin=Vector2(d.board.end.x-35,d.board.position.y+57)
	origin+=Vector2(sin(index*2.4)*6,cos(index*1.3)*4)
	var a=origin+Vector2(-50-index%5*7,-13)
	var b=to+Vector2(40+sin(index)*12,-28)
	return origin.bezier_interpolate(a,b,to,smoothstep(0.0,1.0,t))

func paint_overlay(g, canvas: Node2D) -> void:
	if not entered: return
	var before=g.paint_target;g.paint_target=canvas
	var d=layout(g.full_rect())
	for i in range(landed,mini(souls,landed+ceili(SOUL_FLIGHT/interval)+2)):
		var t=(clock-(arrival_at(i)-SOUL_FLIGHT))/SOUL_FLIGHT
		if t<=0 or t>=1: continue
		var point=soul_position(d,i,t)
		var line=PackedVector2Array()
		for j in range(13): line.append(soul_position(d,i,maxf(0,t-0.22+0.22*j/12.0)))
		canvas.draw_polyline(line,Color(0.22,1.0,0.85,0.12),8,true)
		canvas.draw_polyline(line,Color(0.53,1.0,0.95,0.7),1.5,true)
		var size=lerpf(36.0,22.0,smoothstep(0.45,1.0,t))*smoothstep(0.0,0.15,t)
		glow(canvas,point,20,Color(0.22,1,0.86,0.28))
		soul(g,point,size,g.ui_time+i*0.19)
		for j in range(3):
			var at=soul_position(d,i,maxf(0,t-0.08-j*0.055))+Vector2(sin(i+j)*3,cos(t*13+j)*3)
			canvas.draw_circle(at,1.5-j*0.25,Color(0.6,1,0.92,0.65-j*0.18))
	if clock>=essence_at and presentation.stage()=="fill": paint_stream(g,canvas,d)
	if presentation.stage()=="react":
		var rect: Rect2=g.hub.vessel.rect;var phase=presentation.portion()
		var color: Color=HordeExperimentArt.variant(presentation.shown_level).color
		glow(canvas,rect.get_center(),rect.size.y*0.35,Color(color,0.16*sin(phase*PI)))
		for i in range(12):
			var angle=i*TAU/12+phase
			var point=rect.get_center()+Vector2(cos(angle)*rect.size.x*0.5,sin(angle)*rect.size.y*0.33)*(0.4+phase)
			star(canvas,point,2.0+sin(phase*PI)*2.5,Color(1,0.85,0.4,sin(phase*PI)))
	if presentation.stage()=="award": paint_coins(g,canvas,d)
	var state=board_state()
	if int(state.amount)==100:
		var power=1.0-float(state.clear)
		for i in range(16):
			var at=d.board.position+d.board.size*Vector2(0.08+0.84*fposmod(i*0.618,1),0.18+0.67*fposmod(i*0.357,1))
			star(canvas,at,2.4,Color(0.7,1,0.87,power*0.7))
	g.paint_target=before

func paint_stream(g, canvas: Node2D, d: Dictionary) -> void:
	var color: Color=HordeExperimentArt.variant(presentation.shown_level).color
	var source: Vector2=d.badge.get_center()+Vector2(0,-22)
	var vessel: Rect2=g.hub.vessel.rect
	var end=vessel.position+vessel.size*Vector2(0.27,0.14)
	var a=source+Vector2(6,-60);var b=end+Vector2(-48,-23)
	var line=PackedVector2Array();var power=sin(presentation.portion()*PI)
	for i in range(33):
		var t=i/32.0;var point=source.bezier_interpolate(a,b,end,t)
		point+=Vector2(0,sin(t*18-clock*12)*2.4*sin(t*PI))
		line.append(point)
	canvas.draw_polyline(line,Color(color,0.08+power*0.06),13,true)
	canvas.draw_polyline(line,Color(color,0.65),4,true)
	canvas.draw_polyline(line,Color(color.lightened(0.65),0.9),1.2,true)
	for i in range(9):
		var t=fposmod(clock*1.3-i*0.115,1.0)
		var point=source.bezier_interpolate(a,b,end,t)
		canvas.draw_circle(point,1.2+sin(t*PI)*1.5,Color(color.lightened(0.5),sin(t*PI)*0.9))
	# Interior falling droplets make the incoming stream read as liquid.
	var pane: Rect2=g.hub.vessel.pane
	var surface=pane.position.y+pane.size.y*(1.0-presentation.amount())
	for i in range(5):
		var t=fposmod(clock*1.5+i*0.21,1.0)
		var point=Vector2(pane.get_center().x+sin(i*2.4)*pane.size.x*0.12,lerpf(pane.position.y+5,maxf(pane.position.y+6,surface),t))
		canvas.draw_circle(point,1.7,Color(color.lightened(0.5),0.7))

func coin_position(from: Vector2, to: Vector2, index: int, t: float) -> Vector2:
	var angle=index*2.39996
	var burst=Vector2(cos(angle)*49,sin(angle)*35)
	return from+(to-from)*smoothstep(0.12,1.0,t)+burst*sin(t*PI)*(1-t)+Vector2(0,-sin(t*PI)*69)

func paint_coins(g, canvas: Node2D, d: Dictionary) -> void:
	var p=presentation
	if int(p.current.coins)<=0: return
	var from=g.hub.vessel.rect.get_center()+Vector2(0,24)
	var to: Vector2=d.wallet.position+Vector2(25,29)
	for i in range(16):
		var t=(p.elapsed-0.055*i)/0.66
		if t<=0 or t>=1: continue
		var point=coin_position(from,to,i,t)
		var trail=PackedVector2Array()
		for j in range(6): trail.append(coin_position(from,to,i,maxf(0,t-0.12+0.12*j/5.0)))
		canvas.draw_polyline(trail,Color(1,0.75,0.2,0.2),3,true)
		g.scenery.sprite(canvas,g.art.items[1],point,21+sin(t*PI)*8,Color(1,1,1,smoothstep(0,0.07,t)))
		star(canvas,point+Vector2(-8,-8),1.6,Color(1,0.92,0.6,0.7))
	var pop=sin(p.award_portion()*PI)
	glow(canvas,to,22,Color(1,0.72,0.2,pop*0.3))

func star(canvas: CanvasItem, point: Vector2, size: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([point+Vector2(0,-size*2),point+Vector2(size*0.35,-size*0.35),point+Vector2(size,0),point+Vector2(size*0.35,size*0.35),point+Vector2(0,size*2),point+Vector2(-size*0.35,size*0.35),point+Vector2(-size,0),point+Vector2(-size*0.35,-size*0.35)]),color)

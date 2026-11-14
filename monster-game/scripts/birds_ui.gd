extends RefCounted
const Catalog = preload("res://scripts/bird_catalog.gd")
const BirdArt = preload("res://scripts/bird_art.gd")
const CRATE_TIME = 1.15
const FUSION_TIME = 1.65
const SHORT = ["Moedas extras nos Perfects","Avisa quando há perigo","Sabota ameaças no caminho","Última chance para a horda","Ataca após sequências de Perfects"]
var art = preload("res://scripts/aviary_art.gd").new()
var selected = 0
var page = "collection"
var fusion_inputs = ["",""]
var from = "market"
var age = 0.0
var reveal_sound = false
var shake_left = 0.0
var equip_left = [0.0,0.0]

func open(g) -> void:
	from = "market" if g.screen=="market" else "home"
	if g.lab_active:g.leave_lab()
	page = "collection";fusion_inputs = ["",""];age = 0;reveal_sound = false;shake_left = 0
	g.change_screen("birds")

func stage(g) -> String:
	var pending: Dictionary = g.data.get("bird_pending",{})
	return str(pending.get("stage","reveal" if int(pending.get("taps",0))>=3 else "egg"))

func fusion_choices(g) -> Array:
	return fusion_inputs if page=="fusion" else Catalog.fusion_pair(g.data,Catalog.IDS[selected])

func open_fusion(g) -> void:
	page = "fusion";fusion_inputs = Catalog.fusion_pair(g.data,Catalog.IDS[selected])

func choose_fusion(id: String) -> void:
	var current = fusion_inputs.find(id)
	if current>=0:fusion_inputs[current] = ""
	elif str(fusion_inputs[0]).is_empty():fusion_inputs[0] = id
	else:fusion_inputs[1] = id

func transition(g,value: String) -> bool:
	var before = g.data.duplicate(true)
	g.data.bird_pending.stage = value
	if value=="reveal":Catalog.unlock_receipt(g.data)
	if not g.save_game():g.data = before;age = 0;g.show_toast("NÃO FOI POSSÍVEL SALVAR. TENTE NOVAMENTE.",3);return false
	age = 0;return true

func update(g,dt: float) -> void:
	if g.screen in ["home","birds","market","developer"]:art.warm_step()
	if g.screen!="birds":return
	age += dt;shake_left = maxf(0,shake_left-dt)
	for i in range(2):equip_left[i] = maxf(0,float(equip_left[i])-dt)
	var pending: Dictionary = g.data.get("bird_pending",{})
	if pending.is_empty():return
	if stage(g)=="crate" and age>=CRATE_TIME:transition(g,"egg")
	elif stage(g)=="fusion" and age>=FUSION_TIME:transition(g,"reveal")
	elif stage(g)=="reveal" and age>=.18 and not reveal_sound:
		reveal_sound = true;g.sound.play("egg_hatch",-14)

func transaction(g,fusion: bool) -> void:
	var before = g.data.duplicate(true)
	var receipt = Catalog.fuse(g.data,str(fusion_inputs[0]),str(fusion_inputs[1])) if fusion else Catalog.roll(g.data,g.reward_rng)
	if receipt.is_empty():g.sound.play("ui_denied");g.show_toast("ESCOLHA DUAS ESPÉCIES DIFERENTES COM 3 BARRAS." if fusion else "VOCÊ PRECISA DE 30 DIAMANTES.",2);return
	if not g.save_game():g.data = before;g.show_toast("NÃO FOI POSSÍVEL SALVAR. TENTE NOVAMENTE.",3);return
	age = 0;reveal_sound = false;shake_left = 0
	g.sound.play("ritual_fill" if fusion else "sewer_gate",-20 if fusion else -25)

func acknowledge(g) -> bool:
	if stage(g)!="reveal" or age<.7:return false
	var before = g.data.duplicate(true);var pending: Dictionary = g.data.bird_pending.duplicate(true)
	Catalog.unlock_receipt(g.data);g.data.bird_pending = {}
	if not g.save_game():g.data = before;return false
	selected = maxi(0,Catalog.tier(str(pending.get("id",""))));page = "collection";fusion_inputs = ["",""];age = 0;return true

func action(g,value: String) -> bool:
	if value in ["birds_open","market_tab_4"]:g.sound.play("ui_confirm");open(g);return true
	if g.screen!="birds":return false
	if not g.data.bird_pending.is_empty():
		if value=="back":g.sound.play("ui_back");g.change_screen(from);return true
		if value=="bird_tap" and stage(g)=="egg" and int(g.data.bird_pending.get("taps",0))<3:
			var before = g.data.duplicate(true)
			g.data.bird_pending.taps = int(g.data.bird_pending.taps)+1
			if int(g.data.bird_pending.taps)==3:g.data.bird_pending.stage = "reveal";Catalog.unlock_receipt(g.data)
			if not g.save_game():g.data = before;return true
			g.sound.play_ui_restart("egg_crack");age = 0;shake_left = .24
		elif value=="bird_done":acknowledge(g)
		return true
	if value.begins_with("bird_select_"):
		selected = clampi(int(value.trim_prefix("bird_select_")),0,4)
		if page=="fusion" and Catalog.fusion_eligible(g.data,Catalog.IDS[selected]):choose_fusion(Catalog.IDS[selected])
		g.sound.play("ui_confirm");return true
	if value.begins_with("bird_equip_"):
		var slot = int(value.trim_prefix("bird_equip_"));var before = g.data.duplicate(true)
		if Catalog.equip(g.data,Catalog.IDS[selected],slot):
			if not g.save_game():g.data = before
			else:g.sound.play("ui_confirm");equip_left[slot] = .65
		else:
			g.sound.play("ui_denied")
			var other = Catalog.equipped_slots(g.data)[1-slot] if slot in [0,1] else ""
			g.show_toast("ESTA ESPÉCIE JÁ ESTÁ NO OUTRO NINHO." if other==Catalog.IDS[selected] else "REVELE UMA CÓPIA DISPONÍVEL NO OVO.",2)
		return true
	match value:
		"back":g.sound.play("ui_back");g.change_screen(from)
		"bird_collection":page = "collection";fusion_inputs = ["",""];g.sound.play("ui_confirm")
		"bird_fusion":
			g.sound.play("ui_confirm")
			if page=="fusion":page = "collection";fusion_inputs = ["",""]
			else:open_fusion(g)
		"bird_draw":transaction(g,false)
		"bird_fuse":
			if page!="fusion":open_fusion(g);g.sound.play("ui_confirm")
			else:transaction(g,true)
	return true

func layout(view: Rect2) -> Dictionary:
	var s = view.size.y/720.0;var margin = 22*s
	var left_width = (view.size.x-margin*3)*.54
	var right = view.position.x+margin+left_width+margin
	var right_width = view.end.x-margin-right
	return {"view":view,"scale":s,"collection":Rect2(view.position+Vector2(margin,78*s),Vector2(left_width,454*s)),
		"eggs":Rect2(view.position+Vector2(margin,550*s),Vector2(left_width,151*s)),
		"nests":[Rect2(right,view.position.y+66*s,(right_width-10*s)*.5,240*s),Rect2(right+(right_width+10*s)*.5,view.position.y+66*s,(right_width-10*s)*.5,240*s)],
		"fusion":Rect2(right,view.position.y+310*s,right_width,229*s),"crate":Rect2(right,view.position.y+542*s,right_width,166*s),
		"back":Rect2(view.position+Vector2(16*s,10*s),Vector2(132*s,48*s)),
		"title":Rect2(view.position+Vector2(154*s,0),Vector2(left_width-130*s,74*s)),
		"wallet":Rect2(view.end.x-margin-minf(400*s,right_width),view.position.y+10*s,minf(400*s,right_width),48*s)}

func label(g,value: String,p: Vector2,size: int = 22,colour: Color = Color("fff1d3"),center: bool = true,width: float = -1) -> void:
	g.home_menu.label(g,value,p,size,colour,center,width)

func register(g,rect: Rect2,value: String) -> void:g.buttons.append({"rect":rect,"action":value})

func button(g,rect: Rect2,value: String,action_name: String,enabled: bool = true,size: int = 21) -> void:
	art.frame(g.paint_target,"button",rect,Color.WHITE if enabled else Color(.52,.49,.60))
	label(g,value,rect.get_center()+Vector2(0,size*.34),size,g.CREAM,true,rect.size.x-16)
	if enabled:register(g,rect,action_name)

func bars(g,p: Vector2,count: int,scale: float = 1) -> void:
	for i in range(3):g.panel(Rect2(p+Vector2(i*16*scale,0),Vector2(12,9)*scale),Color("64e9ee") if i<count else Color("21162f"),Color("927ca8"),3,1,false)

func paint(g) -> void:
	if not g.data.get("bird_pending",{}).is_empty():hatch(g);return
	var d = layout(g.full_rect());var s = float(d.scale);var c = g.paint_target
	art.draw(c,"background",d.view,Color.WHITE,0,true)
	button(g,d.back,"‹ VOLTAR","back",true,20*s)
	art.draw(c,"header",d.title,Color.WHITE,0,true);label(g,"AVES MALDITAS",d.title.get_center()+Vector2(0,10*s),roundi(30*s),g.GOLD,true,d.title.size.x-28*s)
	g.hub.wallet(g,d.wallet)
	art.frame(c,"panel",d.collection)
	label(g,"COLEÇÃO" if page=="collection" else "ESCOLHA DUAS ESPÉCIES",Vector2(d.collection.get_center().x,d.collection.position.y+35*s),roundi(23*s),g.CREAM,true,d.collection.size.x*.65)
	var y = d.collection.position.y+57*s;var eligible = 0
	for i in range(5):
		var id = Catalog.IDS[i];var count = Catalog.copies(g.data,id);var known = Catalog.discovered(g.data,id)
		if page=="fusion" and not Catalog.fusion_eligible(g.data,id):continue
		eligible += 1
		var chosen = id in fusion_inputs if page=="fusion" else selected==i
		var h = (103 if chosen else 65)*s
		var row = Rect2(d.collection.position.x+14*s,y,d.collection.size.x-28*s,h)
		art.frame(c,"selected" if chosen else "row",row)
		var portrait = Rect2(row.position+Vector2(6*s,4*s),Vector2(94*s,h-8*s))
		if known:art.portrait(c,id,portrait,g.ui_time,chosen)
		else:art.unknown(c,portrait,g)
		var name = Catalog.NAMES[i] if known else "AVE DESCONHECIDA"
		if page=="fusion" and id in fusion_inputs:name = str(fusion_inputs.find(id)+1)+" · "+name
		label(g,name,row.position+Vector2(106*s,(42 if chosen else 29)*s),roundi((24 if known else 20)*s),Catalog.COLORS[i],false,row.size.x-120*s)
		var badge = Rect2(row.position+Vector2(105*s,(47 if chosen else 38)*s),Vector2(115*s,(20 if chosen else 22)*s))
		art.draw(c,"badge",badge,Catalog.COLORS[i],0,true);label(g,Catalog.RARITIES[i],badge.get_center()+Vector2(0,5*s),roundi(13*s),g.CREAM,true,badge.size.x-10*s)
		if chosen:
			label(g,SHORT[i] if known else "Abra uma caixa para revelar esta ave.",row.position+Vector2(107*s,82*s),roundi(14*s),g.CREAM,false,maxf(140*s,row.size.x-290*s))
			var copies_shown = 1 if page=="fusion" else mini(3,maxi(1,ceili(count/3.0)))
			for copy in range(copies_shown):
				var pos = Vector2(row.end.x-(copies_shown-copy)*61*s-9*s,row.position.y+29*s)
				if known and count>copy*3:art.portrait(c,id,Rect2(pos,Vector2(51,40)*s),g.ui_time)
				bars(g,pos+Vector2(4,43)*s,clampi(count-copy*3,0,3),s)
		else:bars(g,Vector2(row.end.x-69*s,row.position.y+39*s),mini(count,3),s)
		register(g,row,"bird_select_"+str(i));y += h+6*s
	if page=="fusion":
		if eligible<2:
			label(g,"DUAS ESPÉCIES DIFERENTES",d.collection.get_center()+Vector2(0,28*s),roundi(23*s),g.GOLD,true,d.collection.size.x-60*s)
			label(g,"Cada ave precisa de 3 barras completas.",d.collection.get_center()+Vector2(0,58*s),roundi(18*s),g.MINT,true,d.collection.size.x-40*s)
			label(g,"Aves lendárias não participam da fusão.",d.collection.get_center()+Vector2(0,87*s),roundi(16*s),g.CREAM,true,d.collection.size.x-40*s)
		label(g,"Toque nas aves para escolher as entradas 1 e 2.",Vector2(d.collection.get_center().x,d.collection.end.y-15*s),roundi(14*s),g.MINT,true,d.collection.size.x-40*s)
	paint_eggs(g,d.eggs)
	for i in range(2):paint_nest(g,d.nests[i],i)
	paint_fusion(g,d.fusion)
	paint_crate(g,d.crate)

func paint_eggs(g,rect: Rect2) -> void:
	var s = rect.size.y/151.0;var c = g.paint_target
	art.frame(c,"panel",rect)
	label(g,"OVOS POR RARIDADE",Vector2(rect.get_center().x,rect.position.y+29*s),roundi(17*s),g.CREAM,true,rect.size.x*.75)
	var width = (rect.size.x-30*s)/5
	for i in range(5):
		var cell = Rect2(rect.position+Vector2(15*s+i*width,37*s),Vector2(width,109*s))
		art.egg(c,i,Rect2(cell.position+Vector2(7*s,0),Vector2(width-14*s,82*s)),g.ui_time)
		var badge = Rect2(cell.position+Vector2(2*s,86*s),Vector2(width-4*s,23*s))
		art.draw(c,"badge",badge,Catalog.COLORS[i],0,true);label(g,Catalog.RARITIES[i],badge.get_center()+Vector2(0,5*s),roundi(13*s),g.CREAM,true,badge.size.x-8*s)

func paint_nest(g,rect: Rect2,index: int) -> void:
	var c = g.paint_target;var actual = art.draw(c,"nest",rect)
	label(g,"NINHO "+str(index+1),actual.position+actual.size*Vector2(.51,.125),roundi(actual.size.y*.071),Color("352033"),true,actual.size.x*.49)
	var slots: Array = Catalog.equipped_slots(g.data);var id = str(slots[index])
	var occupied = Catalog.available(g.data,id)
	if occupied:
		var pop = 1+sin(clampf(float(equip_left[index])/.65,0,1)*PI)*.12
		BirdArt.paint(c,id,actual.position+actual.size*Vector2(.53,.53),actual.size.y*.46*pop,g.ui_time)
	for j in range(2):
		var phase = fposmod(g.ui_time*.30+j*.5,1)
		c.draw_circle(actual.position+actual.size*Vector2(.087,.52-phase*.17),1.1+phase,Color(.55,1,.88,.5-phase*.35))
	var choice = Catalog.IDS[selected];var duplicate = slots[1-index]==choice
	var available = Catalog.available(g.data,choice) and not duplicate
	var text = "RETIRAR" if occupied and id==choice else "TROCAR" if occupied else "EQUIPAR"
	var area = Rect2(actual.position+actual.size*Vector2(.265,.805),actual.size*Vector2(.53,.108))
	button(g,area,text if available else "JÁ EQUIPADA" if duplicate else "SELECIONE", "bird_equip_"+str(index),available,roundi(actual.size.y*.066))

func paint_fusion(g,rect: Rect2,input_ids: Array = [],progress: float = -1) -> void:
	var c = g.paint_target;var actual = art.draw(c,"fusion",rect,Color.WHITE,0,true)
	var ids: Array = input_ids if input_ids.size()==2 else fusion_choices(g)
	var ready = Catalog.can_fuse(g.data,str(ids[0]),str(ids[1]))
	label(g,"FUSÃO",actual.position+actual.size*Vector2(.50,.105),roundi(actual.size.y*.079),g.CREAM,true,actual.size.x*.29)
	if progress<0:register(g,Rect2(actual.position,Vector2(actual.size.x,actual.size.y*.18)),"bird_fusion")
	for i in range(2):
		var id = str(ids[i]);var count = 3 if progress>=0 and not id.is_empty() else Catalog.copies(g.data,id)
		var centre = actual.position+actual.size*Vector2(.16 if i==0 else .84,.51)
		if Catalog.discovered(g.data,id) and count>0:
			var size = actual.size.y*.40*(1-maxf(0,progress)*.6)
			art.portrait(c,id,Rect2(centre-Vector2.ONE*size*.5,Vector2.ONE*size),g.ui_time)
		else:label(g,str(i+1),centre+Vector2(0,actual.size.y*.05),roundi(actual.size.y*.14),g.MINT)
		bars(g,actual.position+actual.size*Vector2(.112 if i==0 else .792,.682),mini(count,3),actual.size.y/240.0)
		var name = Catalog.NAMES[Catalog.tier(id)] if id in Catalog.IDS else "ESCOLHA UMA AVE"
		label(g,name,actual.position+actual.size*Vector2(.16 if i==0 else .84,.785),roundi(actual.size.y*.049),g.MINT,true,actual.size.x*.25)
	var centre = actual.position+actual.size*Vector2(.5,.49)
	if progress>=0:
		for j in range(12):
			var a = g.ui_time*4+j*TAU/12;var radius = actual.size.y*(.04+.19*(1-progress))
			c.draw_circle(centre+Vector2.from_angle(a)*radius,2+j%3,Color(.55,1,.85,.75))
		for side in [-1,1]:
			for j in range(3):
				var t = fposmod(g.ui_time*1.3+j*.33,1)
				var p = centre+Vector2(side*actual.size.x*.29*(1-t),-sin(t*PI)*actual.size.y*.21)
				c.draw_circle(p,2.5,Color(.5,1,.9,.85))
	else:
		label(g,"?",centre+Vector2(0,actual.size.y*.10),roundi(actual.size.y*.34),g.MINT,true,actual.size.x*.24)
		if ready:
			var result = Catalog.tier(Catalog.fusion_result(str(ids[0]),str(ids[1])))
			label(g,Catalog.RARITIES[result],centre+Vector2(0,actual.size.y*.17),roundi(actual.size.y*.058),Catalog.COLORS[result],true,actual.size.x*.24)
	var heat = progress if progress>=0 else .10+sin(g.ui_time*.7)*.05
	var needle = actual.position+actual.size*Vector2(.666,.272)
	c.draw_line(needle,needle+Vector2.from_angle(-2.8+heat*2.3)*actual.size.y*.07,Color("71333a"),2,true)
	label(g,"ESPÉCIES DIFERENTES",actual.position+actual.size*Vector2(.5,.752),roundi(actual.size.y*.059),g.CREAM,true,actual.size.x*.34)
	var area = Rect2(actual.position+actual.size*Vector2(.325,.783),actual.size*Vector2(.35,.16))
	label(g,"FUNDINDO..." if progress>=0 else "ESCOLHER AVES" if page!="fusion" else "FUNDIR",area.get_center()+Vector2(0,actual.size.y*.033),roundi(actual.size.y*.102),g.CREAM if ready or progress>=0 or page!="fusion" else Color("ad9cba"),true,area.size.x-10)
	if progress<0:
		if page!="fusion":register(g,area,"bird_fusion")
		elif ready:register(g,area,"bird_fuse")

func paint_crate(g,rect: Rect2) -> void:
	var c = g.paint_target;var s = rect.size.y/166.0
	var box = Rect2(rect.position+Vector2(0,-16*s),Vector2(rect.size.x*.49,rect.size.y+22*s))
	art.draw(c,"crate_0",box,Color.WHITE,sin(g.ui_time*1.8)*.009)
	var panel = Rect2(rect.position+Vector2(rect.size.x*.50,13*s),Vector2(rect.size.x*.50,rect.size.y-22*s))
	art.frame(c,"row",panel)
	label(g,"CAIXA MALDITA",Vector2(panel.get_center().x,panel.position.y+34*s),roundi(22*s),g.GOLD,true,panel.size.x-15*s)
	label(g,"Abra e descubra sua ave",Vector2(panel.get_center().x,panel.position.y+59*s),roundi(14*s),g.MINT,true,panel.size.x-14*s)
	var buy = Rect2(panel.position+Vector2(16*s,76*s),Vector2(panel.size.x-32*s,51*s))
	art.frame(c,"button",buy,Color.WHITE if int(g.data.eyes)>=30 else Color(.60,.55,.68))
	g.hub.eye(g,Vector2(buy.get_center().x-26*s,buy.get_center().y),32*s)
	label(g,"30",buy.get_center()+Vector2(19*s,11*s),roundi(32*s),g.CREAM,true,70*s)
	register(g,rect,"bird_draw")

func hatch(g) -> void:
	var receipt: Dictionary = g.data.bird_pending;var index = Catalog.tier(str(receipt.id));var colour = Catalog.COLORS[index]
	var view: Rect2 = g.full_rect();var centre = view.get_center();var c = g.paint_target;var s = view.size.y/720
	g.buttons.clear();art.draw(c,"background",view,Color(.50,.43,.60),0,true);c.draw_rect(view,Color(.04,.02,.07,.65))
	var current = stage(g)
	if current=="crate":
		label(g,"ABRINDO A CAIXA MALDITA",Vector2(centre.x,view.position.y+100*s),roundi(32*s),g.GOLD,true,view.size.x-80*s)
		var t = clampf(age/CRATE_TIME,0,1);var frame = mini(3,floori(t*4))
		art.draw(c,"crate_"+str(frame),Rect2(centre-Vector2(235,160)*s,Vector2(470,390)*s),Color.WHITE,sin(age*45)*.025*(1-t))
		if t>.68:art.egg(c,index,Rect2(centre-Vector2(70,40+(t-.68)*230)*s,Vector2(140,170)*s),g.ui_time)
		for i in range(7):
			var p = centre+Vector2(sin(i*3.7)*t*210,-sin(t*PI)*110+i*7)*s
			c.draw_circle(p,2.4*s,Color(.7,.4,.25,(1-t)*.7))
		label(g,"Uma surpresa está prestes a acordar...",Vector2(centre.x,view.end.y-110*s),roundi(18*s),g.MINT,true,view.size.x-80*s)
	elif current=="fusion":
		label(g,"A MALDIÇÃO ESTÁ SE TRANSFORMANDO...",Vector2(centre.x,view.position.y+104*s),roundi(30*s),g.GOLD,true,view.size.x-80*s)
		paint_fusion(g,Rect2(centre-Vector2(440,155)*s,Vector2(880,380)*s),receipt.get("inputs",[]),clampf(age/FUSION_TIME,0,1))
	elif current=="egg":
		label(g,"OVO • "+Catalog.RARITIES[index],Vector2(centre.x,view.position.y+100*s),roundi(34*s),colour,true,view.size.x-80*s)
		var pop = .72+.28*(1-exp(-age*8))
		var size = Vector2(310,360)*s*pop
		art.egg(c,index,Rect2(centre-Vector2(size.x*.5,size.y*.5-5*s),size),g.ui_time,shake_left/.24,int(receipt.taps))
		label(g,"TOQUE NO OVO  •  %d / 3" % int(receipt.taps),Vector2(centre.x,view.end.y-115*s),roundi(25*s),g.CREAM,true,view.size.x-80*s)
		register(g,Rect2(centre-Vector2(205,215)*s,Vector2(410,440)*s),"bird_tap")
	else:
		label(g,"FUSÃO CONCLUÍDA!" if receipt.source=="fusion" else "AVE REVELADA!",Vector2(centre.x,view.position.y+95*s),roundi(34*s),colour)
		label(g,Catalog.NAMES[index],Vector2(centre.x,view.position.y+143*s),roundi(40*s),g.CREAM)
		var pop = 1+sin(clampf(age/.5,0,1)*PI)*.15
		if Catalog.discovered(g.data,str(receipt.id)):BirdArt.paint(c,str(receipt.id),centre-Vector2(0,12*s),300*s*pop,g.ui_time,"ability")
		if receipt.source!="fusion":art.shell(c,index,Rect2(centre-Vector2(135,155)*s,Vector2(270,320)*s),clampf(age/.65,0,1))
		bars(g,centre+Vector2(-44,172)*s,posmod(Catalog.copies(g.data,str(receipt.id))-1,3)+1,2*s)
		label(g,"CADA SORTEIO PREENCHE UMA BARRA DA CÓPIA",Vector2(centre.x,view.end.y-115*s),roundi(18*s),g.MINT,true,view.size.x-80*s)
		if age>=.7:button(g,Rect2(centre.x-150*s,view.end.y-83*s,300*s,52*s),"CONTINUAR","bird_done",true,roundi(22*s))
	button(g,Rect2(view.position+Vector2(24*s,view.size.y-65*s),Vector2(158,43)*s),"‹ VOLTAR","back",true,roundi(18*s))

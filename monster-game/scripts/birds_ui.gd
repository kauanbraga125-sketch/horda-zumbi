extends RefCounted
const Catalog = preload("res://scripts/bird_catalog.gd")
const Art = preload("res://scripts/bird_art.gd")
var selected = 0
var page = "collection"
var from = "market"
var age = 0.0
var reveal_sound = false
var crack_sound = false
func open(g) -> void:
	from = "market" if g.screen=="market" else "home"
	if g.lab_active: g.leave_lab()
	page = "collection";age = 0;reveal_sound = false
	g.change_screen("birds")
func update(g,dt: float) -> void:
	if g.screen!="birds": return
	age += dt
	var pending: Dictionary = g.data.get("bird_pending",{})
	if not pending.is_empty() and int(pending.get("taps",0))>=3 and age>=.18 and not reveal_sound:
		reveal_sound = true;g.sound.play("egg_hatch",-14)
func transaction(g,fusion: bool) -> void:
	var before = g.data.duplicate(true)
	var receipt = Catalog.fuse(g.data,Catalog.IDS[selected]) if fusion else Catalog.roll(g.data,g.reward_rng)
	if receipt.is_empty(): g.sound.play("ui_denied");g.show_toast("FUSÃO: DUAS CÓPIAS COM 3 BARRAS" if fusion else "VOCÊ PRECISA DE 30 DIAMANTES.",2);return
	if not g.save_game(): g.data = before;g.show_toast("NÃO FOI POSSÍVEL SALVAR. TENTE NOVAMENTE.",3);return
	age = 0;reveal_sound = false;crack_sound = false
	g.sound.play("ui_confirm",-17)
func acknowledge(g) -> bool:
	var pending: Dictionary = g.data.bird_pending.duplicate(true)
	if int(pending.get("taps",0))<3: return false
	g.data.bird_pending = {}
	if not g.save_game(): g.data.bird_pending = pending;return false
	selected = maxi(0,Catalog.tier(str(pending.get("id",""))));age = 0
	return true
func action(g,value: String) -> bool:
	if value in ["birds_open","market_tab_4"]: g.sound.play("ui_confirm");open(g);return true
	if g.screen!="birds": return false
	if not g.data.bird_pending.is_empty():
		if value=="bird_tap" and int(g.data.bird_pending.get("taps",0))<3:
			var old = int(g.data.bird_pending.get("taps",0));g.data.bird_pending.taps = old+1
			if not g.save_game(): g.data.bird_pending.taps = old;return true
			g.sound.play_ui_restart("egg_crack");age = 0
		elif value=="bird_done" and age>=.7: acknowledge(g)
		return true
	if value.begins_with("bird_select_"):
		selected = clampi(int(value.trim_prefix("bird_select_")),0,4);g.sound.play("ui_confirm");return true
	if value.begins_with("bird_equip_"):
		var before = g.data.duplicate(true)
		if Catalog.equip(g.data,Catalog.IDS[selected],int(value.trim_prefix("bird_equip_"))):
			if not g.save_game(): g.data = before
			else: g.sound.play("ui_confirm")
		else: g.sound.play("ui_denied");g.show_toast("ESTA CÓPIA JÁ ESTÁ EQUIPADA.")
		return true
	match value:
		"back": g.sound.play("ui_back");g.change_screen(from)
		"bird_collection": page = "collection";g.sound.play("ui_confirm")
		"bird_fusion":
			page = "fusion";g.sound.play("ui_confirm")
			for i in range(4):
				if Catalog.copies(g.data,Catalog.IDS[i])>=6: selected = i;break
		"bird_draw": transaction(g,false)
		"bird_fuse": transaction(g,true)
	return true
func label(g,s: String,p: Vector2,size: int = 22,color: Color = Color("fff1d3"),center: bool = true,width: float = -1) -> void:
	g.home_menu.label(g,s,p,size,color,center,width)
func bars(g,p: Vector2,count: int,scale: float = 1.0) -> void:
	for i in range(3):
		g.panel(Rect2(p+Vector2(i*16*scale,0),Vector2(12,9)*scale),Color("64e9ee") if i<count else Color("21162f"),Color("927ca8"),3,1,false)
func paint(g) -> void:
	if not g.data.get("bird_pending",{}).is_empty(): hatch(g);return
	var view: Rect2 = g.full_rect();var o = view.position;var right = view.end.x-30
	g.home_menu.slab(g,Rect2(o+Vector2(28,22),Vector2(view.size.x-56,96)),Color("261b35"),g.GOLD,14,3)
	label(g,"AVES MALDITAS",o+Vector2(50,66),34,g.GOLD,false,view.size.x-500)
	label(g,"Complete 3 barras por cópia. Duas cópias completas permitem a fusão.",o+Vector2(50,98),17,g.MINT,false,view.size.x-500)
	g.hub.wallet(g,Rect2(right-400,o.y+34,390,66))
	var width = view.size.x-350;var y = o.y+145
	var eligible = 0
	for i in range(5):
		if page=="fusion" and (i==4 or Catalog.copies(g.data,Catalog.IDS[i])<6):continue
		eligible += 1
		var id = Catalog.IDS[i];var count = Catalog.copies(g.data,id);var chosen = i==selected
		var h = 150.0 if chosen else 76.0
		var rect = Rect2(o.x+30,y,width,h)
		g.home_menu.slab(g,rect,Color("392643") if chosen else Color("251c32"),Catalog.COLORS[i] if chosen else Color("65506e"),11,2)
		Art.paint(g.paint_target,id,rect.position+Vector2(40,35),65,g.ui_time,"",Color.WHITE if count>0 else Color(.24,.18,.31,1))
		label(g,Catalog.NAMES[i],rect.position+Vector2(86,28),23,Catalog.COLORS[i],false,width-100)
		label(g,Catalog.RARITIES[i]+"  •  "+str(count)+" SORTEIOS",rect.position+Vector2(86,53),15,g.MINT,false,width-100)
		g.home_menu.register(g,rect,"bird_select_"+str(i))
		if chosen:
			label(g,Catalog.description(i,maxi(1,Catalog.level(g.data,id))),rect.position+Vector2(20,83),16,g.CREAM,false,width-30)
			for copy in range(mini(5,maxi(1,ceili(count/3.0)))):
				var pos = rect.position+Vector2(52+copy*85,117)
				Art.paint(g.paint_target,id,pos,50,g.ui_time,"",Color.WHITE if count>copy*3 else Color(.3,.25,.35,1))
				bars(g,pos+Vector2(-22,19),clampi(count-copy*3,0,3))
		y += h+8
	if page=="fusion" and eligible==0:
		Art.prop(g.paint_target,"fusion",Vector2(o.x+width*.5,o.y+340),180)
		label(g,"NENHUMA FUSÃO DISPONÍVEL",Vector2(o.x+width*.5,o.y+485),25,g.GOLD,true,width-30)
		label(g,"Complete duas cópias da mesma ave: 3/3 + 3/3.",Vector2(o.x+width*.5,o.y+522),19,g.MINT,true,width-30)
	var slots: Array = g.data.get("bird_equipped_slots",[g.data.bird_equipped,""])
	for i in range(2):
		var box = Rect2(right-258,o.y+149+i*158,258,146)
		g.home_menu.slab(g,box,Color("30213f"),g.GOLD,12,2)
		label(g,"COMPANHEIRA "+str(i+1),box.position+Vector2(129,25),17,g.GOLD)
		if not str(slots[i]).is_empty(): Art.paint(g.paint_target,str(slots[i]),box.position+Vector2(129,75),87,g.ui_time)
		else: label(g,"VAGA LIVRE",box.position+Vector2(129,77),18,g.MINT)
		if Catalog.copies(g.data,Catalog.IDS[selected])>0: g.button(Rect2(box.position+Vector2(14,110),Vector2(230,29)),"EQUIPAR / RETIRAR","bird_equip_"+str(i),Color("4c786a"),-2,16)
	var fusion_ready = selected<4 and Catalog.copies(g.data,Catalog.IDS[selected])>=6
	g.button(Rect2(right-258,o.y+475,258,55),"FUSÃO" if page!="fusion" else "COLEÇÃO","bird_fusion" if page!="fusion" else "bird_collection",Color("513c67"),-2,23)
	if page=="fusion":
		label(g,"DUAS CÓPIAS • 3/3 + 3/3",Vector2(right-129,o.y+557),15,g.MINT,true,260)
		if fusion_ready: g.button(Rect2(right-258,o.y+575,258,43),"FUNDIR → "+Catalog.NAMES[selected+1],"bird_fuse",Color("4c786a"),-2,18)
		else: label(g,"NÍVEL MÁXIMO" if selected==4 else "COMPLETE AS DUAS CÓPIAS",Vector2(right-129,o.y+593),15,g.CREAM,true,260)
	g.button(Rect2(o.x+30,view.end.y-66,190,47),"VOLTAR","back",Color("513c67"),-2,21)
	g.button(Rect2(right-410,view.end.y-66,410,47),"ABRIR OVO  •  30 DIAMANTES","bird_draw",Color("4c786a"),-2,21)
func hatch(g) -> void:
	var receipt: Dictionary = g.data.bird_pending;var taps = int(receipt.get("taps",0));var index = Catalog.tier(str(receipt.id));var color = Catalog.COLORS[index]
	var view: Rect2 = g.full_rect();var centre = view.get_center();var c = g.paint_target
	g.buttons.clear();c.draw_rect(view,Color(.055,.028,.10,.98))
	for i in range(10,0,-1): c.draw_circle(centre,30+i*24,Color(color,.012))
	if taps<3:
		label(g,"QUEM ESTÁ AÍ DENTRO?",Vector2(centre.x,view.position.y+100),34,g.GOLD)
		Art.prop(c,"nest",centre+Vector2(0,160),150)
		Art.prop(c,"egg" if taps==0 else "egg_crack",centre+Vector2(sin(age*50)*maxf(0,1-age*5)*12,-10),260,sin(age*40)*maxf(0,1-age*5)*.08)
		label(g,"TOQUE NO OVO  •  %d / 3" % taps,Vector2(centre.x,view.end.y-120),25,g.CREAM)
		g.home_menu.register(g,Rect2(centre-Vector2(190,200),Vector2(380,390)),"bird_tap")
	else:
		var pop = 1+sin(clampf(age/.5,0,1)*PI)*.15
		Art.prop(c,"egg_open",centre+Vector2(0,130),130)
		Art.paint(c,str(receipt.id),centre-Vector2(0,20),300*pop,g.ui_time,"ability")
		label(g,"FUSÃO CONCLUÍDA!" if receipt.source=="fusion" else "AVE REVELADA!",Vector2(centre.x,view.position.y+95),34,color)
		label(g,Catalog.NAMES[index],Vector2(centre.x,view.position.y+143),40,g.CREAM)
		bars(g,centre+Vector2(-44,167),posmod(Catalog.copies(g.data,str(receipt.id))-1,3)+1,2)
		label(g,"CADA SORTEIO PREENCHE UMA BARRA DA CÓPIA",Vector2(centre.x,view.end.y-115),18,g.MINT)
		if age>=.7:g.button(Rect2(centre.x-150,view.end.y-83,300,52),"CONTINUAR","bird_done",Color("4c786a"),-2,22)

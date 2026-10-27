extends RefCounted
const Catalog = preload("res://scripts/bird_catalog.gd")
const Art = preload("res://scripts/bird_art.gd")
var selected = 0
var page = "collection"
var from = "home"
var age = 0.0
var reveal_sound = false
var crack_sound = false

func open(g) -> void:
	from = g.screen if g.screen in ["home","developer"] else "home"
	if g.lab_active: g.leave_lab()
	selected = maxi(0,Catalog.tier(str(g.data.get("bird_equipped",""))))
	page = "collection";age = 0;reveal_sound = false;crack_sound = false
	g.change_screen("birds")

func update(g,dt: float) -> void:
	if g.screen!="birds": return
	age += dt
	if not g.data.get("bird_pending",{}).is_empty() and age>=1.4 and not crack_sound:
		crack_sound = true;g.sound.play("egg_crack",-16)
	if not g.data.get("bird_pending",{}).is_empty() and age>=2.35 and not reveal_sound:
		reveal_sound = true;g.sound.play("egg_hatch",-15);g.sound.play("bird_"+str(g.data.bird_pending.id),-15)

func transaction(g,fusion: bool) -> void:
	var before = g.data.duplicate(true)
	var receipt = Catalog.fuse(g.data,Catalog.IDS[selected]) if fusion else Catalog.roll(g.data,g.reward_rng)
	if receipt.is_empty():
		g.show_toast("FALTAM ESSÊNCIAS OU MOEDAS" if fusion else "OLHOS INSUFICIENTES",2);return
	if not g.save_game():
		g.data = before;g.show_toast("NÃO FOI POSSÍVEL SALVAR. TENTE NOVAMENTE.",3);return
	age = 0;reveal_sound = false;crack_sound = false;g.sound.play("ritual_fill",-15)

func acknowledge(g) -> bool:
	var pending: Dictionary = g.data.bird_pending.duplicate()
	g.data.bird_pending = {}
	if not g.save_game(): g.data.bird_pending = pending;g.show_toast("NÃO FOI POSSÍVEL SALVAR",2);return false
	selected = maxi(0,Catalog.tier(str(pending.get("id",""))));age = 0
	return true

func action(g,value: String) -> bool:
	if value=="birds_open": open(g);return true
	if g.screen!="birds": return false
	if not g.data.bird_pending.is_empty():
		if value in ["bird_skip","back"] and age<3.0: age = 3.0;return true
		if value in ["bird_done","back"] and age>=3.0: acknowledge(g)
		return true
	if value.begins_with("bird_select_"):
		selected = clampi(int(value.trim_prefix("bird_select_")),0,4);age = 0;return true
	match value:
		"back": g.change_screen(from)
		"bird_collection": page = "collection"
		"bird_fusion": page = "fusion"
		"bird_draw": transaction(g,false)
		"bird_fuse": transaction(g,true)
		"bird_equip":
			var id = Catalog.IDS[selected]
			if Catalog.level(g.data,id)>0:
				var old = g.data.bird_equipped;g.data.bird_equipped = "" if old==id else id
				if not g.save_game(): g.data.bird_equipped = old;g.show_toast("NÃO FOI POSSÍVEL SALVAR",2)
				else: g.sound.play("buy",-17)
		"bird_try_ground","bird_try_space","bird_try_sewer":
			var id = Catalog.IDS[selected]
			g.start_lab("space" if value=="bird_try_space" else "sewer" if value=="bird_try_sewer" else "bomb")
			var demo = Catalog.defaults();demo.bird_equipped = id;demo.bird_copies[id] = 3
			g.runner.bird.configure(demo)
			g.show_toast("TESTE • "+Catalog.NAMES[selected]+" • NÍVEL 3",2)
		_: return true
	return true

func label(g,s: String,p: Vector2,size: int = 22,color: Color = Color("fff1d3"),center: bool = true,width: float = -1) -> void:
	g.home_menu.label(g,s,p,size,color,center,width)

func paint(g) -> void:
	if not g.data.get("bird_pending",{}).is_empty(): hatch(g);return
	var view: Rect2 = g.full_rect();var o = view.position;var w = view.size.x
	var left = o.x+34;var right = view.end.x-34
	g.home_menu.slab(g,Rect2(left,o.y+21,w-68,92),Color("261b35"),Color("a47b9a"),16,4)
	label(g,"NINHO DAS AVES MALDITAS",Vector2(left+24,o.y+61),31,g.GOLD,false,w-400)
	label(g,"Cinco personalidades. Uma companheira por partida.",Vector2(left+25,o.y+91),19,g.MINT,false,w-400)
	g.hub.eye(g,Vector2(right-197,o.y+54),35)
	label(g,str(g.data.eyes)+" OLHOS",Vector2(right-167,o.y+62),24,Color("dda7ff"),false,160)
	label(g,"CHANCES BASE: CLÁSSICA 60% • SUPER 25% • HIPER 10% • ULTRA 4% • LENDÁRIA 1%",Vector2(view.get_center().x,o.y+140),16,g.CREAM,true,w-80)
	for i in range(5):
		var id = Catalog.IDS[i];var own = Catalog.level(g.data,id)>0
		var rect = Rect2(left,o.y+161+i*76,250,68)
		g.home_menu.slab(g,rect,Color("3b304a") if i!=selected else Color("4d4560"),Catalog.COLORS[i] if i==selected else Color("65506e"),11,3)
		Art.paint(g.paint_target,id,rect.position+Vector2(36,32),61,g.ui_time,"",Color.WHITE if own else Color(.14,.10,.20,.94))
		label(g,Catalog.NAMES[i] if own else "???",rect.position+Vector2(75,28),20,g.CREAM,false,160)
		label(g,Catalog.RARITIES[i],rect.position+Vector2(75,51),15,Catalog.COLORS[i],false,160)
		if str(g.data.bird_equipped)==id: label(g,"✓",rect.end-Vector2(18,20),18,g.MINT)
		g.home_menu.register(g,rect,"bird_select_"+str(i))
	var id = Catalog.IDS[selected];var lv = Catalog.level(g.data,id);var color = Catalog.COLORS[selected]
	var centre = Vector2(left+440,o.y+350)
	for i in range(6,0,-1): g.paint_target.draw_circle(centre,float(i)*26,Color(color,.009))
	Art.prop(g.paint_target,"nest",centre+Vector2(0,164),94)
	Art.paint(g.paint_target,id,centre,290,g.ui_time,"",Color.WHITE if lv>0 else Color(.12,.08,.19,1))
	label(g,Catalog.NAMES[selected] if lv>0 else Catalog.RARITIES[selected]+" DESCONHECIDA",centre+Vector2(0,-170),25,color,true,340)
	var detail = Rect2(left+646,o.y+160,right-left-646,380)
	g.home_menu.slab(g,detail,Color("291d37"),color,13,3)
	g.pages.lines(g,Catalog.PERSONALITIES[selected] if lv>0 else Catalog.HINTS[selected],Rect2(detail.position+Vector2(23,18),Vector2(detail.size.x-46,72)),24,color,true,3)
	if page=="fusion":
		Art.prop(g.paint_target,"fusion",detail.position+Vector2(detail.size.x*.5,157),130)
		var count = int(g.data.bird_essence.get(id,0))
		var text = "6 ESSÊNCIAS + 500 MOEDAS" if selected<4 else "RARIDADE MÁXIMA"
		label(g,text,detail.position+Vector2(detail.size.x*.5,248),20,g.GOLD,true,detail.size.x-32)
		label(g,"SUAS ESSÊNCIAS: %d / 6" % count,detail.position+Vector2(detail.size.x*.5,276),18,g.MINT)
		if selected<4:
			g.pages.lines(g,"Resultado garantido: "+Catalog.NAMES[selected+1]+". Sua ave mantém os poderes.",Rect2(detail.position+Vector2(20,289),Vector2(detail.size.x-40,48)),18,g.CREAM,true,2)
			if count>=6 and int(g.data.wallet)>=500: g.button(Rect2(detail.position+Vector2(20,337),Vector2(detail.size.x-40,38)),"FAZER FUSÃO","bird_fuse",Color("4c786a"),-2,18)
	else:
		label(g,"NÍVEL %d / 3" % lv,detail.position+Vector2(detail.size.x*.5,122),24,g.MINT)
		g.pages.lines(g,Catalog.description(selected,maxi(1,lv)) if lv>0 else "Invoque um ovo ou avance pela fusão para descobrir esta ave.",Rect2(detail.position+Vector2(22,145),Vector2(detail.size.x-44,100)),23,g.CREAM,true,4)
		label(g,"CÓPIAS: %d   •   ESSÊNCIAS: %d" % [Catalog.copies(g.data,id),int(g.data.bird_essence.get(id,0))],detail.position+Vector2(detail.size.x*.5,281),18,g.MINT,true,detail.size.x-28)
		if lv>0: g.button(Rect2(detail.position+Vector2(20,307),Vector2(detail.size.x-40,49)),"DESEQUIPAR" if g.data.bird_equipped==id else "LEVAR NA HORDA","bird_equip",Color("4c786a"),-2,20)
	var y = view.end.y-133
	var controls = [["TERRA","bird_try_ground"],["ESPAÇO","bird_try_space"],["ESGOTO","bird_try_sewer"]]
	label(g,"PRÉVIA GRÁTIS • NÍVEL 3",Vector2(left+438,y+15),14,g.MINT,true,320)
	for i in range(3): g.button(Rect2(left+285+i*108,y+25,100,33),controls[i][0],controls[i][1],Color("513c67"),-2,15)
	var cost = "PRIMEIRO OVO GRÁTIS" if int(g.data.bird_draws)==0 else "INVOCAR • 30 OLHOS"
	g.button(Rect2(left,view.end.y-66,165,47),"VOLTAR","back",Color("513c67"),-2,21)
	g.button(Rect2(left+180,view.end.y-66,300,47),cost,"bird_draw",Color("4c786a"),-2,21)
	g.button(Rect2(left+495,view.end.y-66,195,47),"COLEÇÃO" if page=="fusion" else "FUSÃO","bird_collection" if page=="fusion" else "bird_fusion",Color("513c67"),-2,21)
	# Right-aligned compact odds and pity lines stay in the details column.
	var odds_x = left+710
	label(g,"HIPER+ EM ATÉ %d OVOS" % (10-int(g.data.bird_rare_pity)),Vector2(odds_x,view.end.y-56),15,g.MINT,false,right-odds_x)
	label(g,"LENDÁRIA EM ATÉ %d" % (50-int(g.data.bird_legend_pity)),Vector2(odds_x,view.end.y-32),15,g.GOLD,false,right-odds_x)

func hatch(g) -> void:
	var receipt: Dictionary = g.data.bird_pending;var index = Catalog.tier(str(receipt.id));var color = Catalog.COLORS[index]
	var view: Rect2 = g.full_rect();var centre = view.get_center()+Vector2(0,-10);var c = g.paint_target
	c.draw_rect(view,Color(.055,.028,.10,.97))
	var opening = smoothstep(1.4,2.35,age);var revealed = age>=2.35
	for i in range(14,0,-1): c.draw_circle(centre,30+i*18,Color(color,.006+.002*opening))
	for i in range(18):
		var a = i*TAU/18+age*.17;var direction = Vector2.from_angle(a)
		c.draw_line(centre+direction*90,centre+direction*(170+opening*110),Color(color,.06+opening*.13),3,true)
	Art.prop(c,"fusion" if receipt.source=="fusion" else "nest",centre+Vector2(0,175),140)
	if not revealed:
		var shake = sin(age*(10+age*11))*.055*smoothstep(.3,1.9,age)
		Art.prop(c,"egg_crack" if age>=1.4 else "egg",centre+Vector2(sin(age*39)*opening*4,-absf(sin(age*5))*opening*13),250,shake)
		label(g,"A FUSÃO ESTÁ ACORDANDO..." if receipt.source=="fusion" else "QUEM ESTÁ AÍ DENTRO?",Vector2(centre.x,view.position.y+100),32,g.GOLD)
		if age>.8: g.button(Rect2(centre.x-110,view.end.y-84,220,49),"ABRIR AGORA","bird_skip",Color("4c786a"),-2,21)
	else:
		var t = age-2.35;var pop = 1+sin(clampf(t/.45,0,1)*PI)*.15
		Art.prop(c,"egg_open",centre+Vector2(0,131),120,0,Color(1,1,1,.55))
		Art.paint(c,str(receipt.id),centre-Vector2(0,15),330*pop,g.ui_time,"ability" if t<1.1 else "")
		for i in range(24):
			var a = i*2.399;var p = centre+Vector2.from_angle(a)*(90+fposmod(t*.28+i*.17,1)*190)
			c.draw_circle(p,1.5+(i%3)*.6,Color(color,.65*(1-fposmod(t*.28+i*.17,1))))
		label(g,"NOVA AVE MALDITA!" if receipt.new else "+1 ESSÊNCIA" if int(receipt.essence)>0 else "SUA AVE EVOLUIU!",Vector2(centre.x,view.position.y+84),32,color)
		label(g,Catalog.NAMES[index],Vector2(centre.x,view.position.y+129),42,g.CREAM)
		label(g,Catalog.RARITIES[index]+" • NÍVEL "+str(receipt.level),Vector2(centre.x,view.position.y+163),21,color)
		label(g,Catalog.PERSONALITIES[index],Vector2(centre.x,view.end.y-109),22,g.CREAM,true,view.size.x-100)
		if age>=3.0: g.button(Rect2(centre.x-150,view.end.y-83,300,52),"CONHECER MINHA AVE","bird_done",Color("4c786a"),-2,22)

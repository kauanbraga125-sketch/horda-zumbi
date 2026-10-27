extends "res://scripts/sewer_presentation.gd"
var notice = ""
var notice_left = 0.0
func notify(message: String) -> void: notice = message;notice_left = 2.4

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
	g.home_menu.label(g,"ONDA • %d KM/H" % roundi(s.scroll_speed(g.runner)*.12),Vector2(o.x+27,o.y+111),15,g.CORAL if s.pressure>.7 else g.MINT,false)
	g.progress_bar(Rect2(o.x+27,o.y+118,190,8),s.pressure,g.CORAL if s.pressure>.65 else g.MINT)
	g.home_menu.label(g,"ALMAS %d • MAIOR HORDA %d" % [g.runner.souls,g.runner.max_horde],Vector2(right-290,o.y+118),15,g.MINT,false,265)
	if s.age<8 and notice_left<=0: g.home_menu.label(g,"TOQUE PARA SALTAR • SEGURE PARA ALONGAR",Vector2(view.get_center().x,o.y+158),19,g.CREAM,true,view.size.x-80)
	if g.lab_active:
		var labels = ["RECOMEÇAR","ENCHENTE +","IR PARA SAÍDA"]
		for i in range(3):
			var width = (view.size.x-85)/3
			g.button(Rect2(o.x+25+i*(width+15),view.end.y-73,width,44),labels[i],["lab_sewer_restart","lab_sewer_wave","lab_sewer_exit"][i],Color("513c67"),-2,18)

extends RefCounted
var item: Dictionary = {}
var committing = false
var success: Dictionary = {}
var success_left = 0.0
func is_open() -> bool:return not item.is_empty()
func action(g,a: String) -> bool:
	if a=="shop_cancel" or (a=="back" and is_open()):item.clear();g.sound.play("ui_back");return true
	if a=="shop_confirm":
		if item.is_empty():return true
		var chosen = item.duplicate(true);item.clear()
		var before = g.data.duplicate(true)
		committing = true;g.perform_action(str(chosen.action));committing = false
		if g.data!=before:
			success = chosen;success_left = 1.0;g.toast_left = 0
		return true
	if committing or g.screen not in ["market","evolution"] or is_open():return is_open()
	for candidate in g.market.items(g.data):
		if candidate.action==a and int(candidate.price)>0 and not bool(candidate.full):
			item = candidate.duplicate(true);success_left = 0;g.sound.play("ui_confirm");return true
	return false
func update(dt: float) -> void:success_left = maxf(0,success_left-dt)
func paint(g) -> void:
	if item.is_empty() and success_left<=0:return
	var view: Rect2 = g.full_rect();var centre = view.get_center();var c = g.paint_target
	var chosen: Dictionary = item if is_open() else success
	c.draw_rect(view,Color(.025,.01,.05,.82))
	var box = Rect2(centre-Vector2(330,244),Vector2(660,488))
	g.home_menu.slab(g,box,Color("30203f"),g.GOLD,20,4)
	g.home_menu.label(g,"LEVAR PARA SUA HORDA?" if is_open() else "COMPRA CONCLUÍDA!",centre+Vector2(0,-195),30,g.GOLD,true,610)
	g.home_menu.label(g,str(chosen.name),centre+Vector2(0,-155),25,g.CREAM,true,610)
	if chosen.illustration=="cosmetic":g.market.preview(g,chosen,centre+Vector2(0,-36),155)
	else:g.market.illustration(g,chosen,centre+Vector2(0,-36),155)
	g.market.wrapped(g,str(chosen.description),centre+Vector2(-285,75),570,19,2)
	if is_open():
		g.buttons.clear()
		var premium = str(chosen.get("currency","coins"))=="eyes"
		g.home_menu.label(g,str(chosen.price)+(" DIAMANTES" if premium else " MOEDAS"),centre+Vector2(0,145),27,g.GOLD,true,550)
		g.button(Rect2(centre+Vector2(-290,177),Vector2(265,48)),"AGORA NÃO","shop_cancel",Color("513c67"),-2,22)
		g.button(Rect2(centre+Vector2(25,177),Vector2(265,48)),"QUERO COMPRAR","shop_confirm",Color("4c786a"),-2,22)
	else:
		var t = 1.0-success_left
		for i in range(18):
			var p = centre+Vector2.from_angle(i*2.399)*(60+t*185)
			c.draw_circle(p,2+(i%3),Color(g.GOLD,success_left))
		g.home_menu.label(g,"PRONTO PARA FAZER PARTE DA SUA HISTÓRIA",centre+Vector2(0,165),19,g.MINT,true,600)

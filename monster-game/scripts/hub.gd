class_name HordeHub
extends RefCounted
const EYE = preload("res://assets/art/meta_v100/eye.png")
const BOOK = preload("res://assets/art/meta_v100/book.png")
var grave_texture: Texture2D = preload("res://assets/art/meta_v100/grave.png")
var fluid: ColorRect
var name_edit: LineEdit
var fluid_rect = Rect2()
var shown_xp = -1.0
var shown_level = 1
var brush_down = false
var brush_id = -999
var brush_point = Vector2.ZERO
var brush_last = Vector2.ZERO
var book_reaction = 0.0
var signature_points: Array = []
var signature_down = false
var detail_kind = 0
var detail_buy_action = ""
var profile_page = 0
var profile_from = "home"
var graves_from = "home"
var progress_notice_left = 0.0
var mud_nodes: Array[ColorRect] = []
var mud_keys: Array[String] = ["", ""]
var polish = HordePolish.new()
var vessel_overlay: TextureRect
var book_phase = 0.0
var book_opened = false
var last_screen = ""
var reveal_left: Array[float] = [0.0,0.0]
var level_glow = 0.0

func init(g) -> void:
	if is_instance_valid(fluid): return
	fluid = ColorRect.new();fluid.mouse_filter = Control.MOUSE_FILTER_IGNORE;fluid.z_index = 1
	var material = ShaderMaterial.new();material.shader = preload("res://scripts/experiment.gdshader");fluid.material = material
	g.add_child(fluid)
	vessel_overlay = TextureRect.new();vessel_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vessel_overlay.z_index = 2;vessel_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.add_child(vessel_overlay)
	for i in range(2):
		var mud = ColorRect.new();mud.mouse_filter = Control.MOUSE_FILTER_IGNORE;mud.z_index = 1
		var mat = ShaderMaterial.new();mat.shader = preload("res://scripts/grave_mud.gdshader");mud.material = mat
		g.add_child(mud);mud_nodes.append(mud)
	name_edit = LineEdit.new();name_edit.placeholder_text = "Seu nome no Livro dos Mortos";name_edit.max_length = 24
	name_edit.add_theme_font_override("font", g.art.body_font);name_edit.add_theme_font_size_override("font_size", 24)
	name_edit.z_index = 8;name_edit.visible = false;g.add_child(name_edit)

func update(g, dt: float) -> void:
	init(g)
	if g.screen == "results": g.result_time += dt
	progress_notice_left = maxf(0, progress_notice_left - dt)
	for i in range(2): reveal_left[i] = maxf(0,reveal_left[i]-dt)
	level_glow = maxf(0,level_glow-dt)
	if g.screen == "book" and last_screen != "book":
		book_phase = 0.0;book_opened = HordeMeta.relic_count(int(g.data.player_level)) >= 4
	if g.screen != "graves": brush_down = false
	book_phase = move_toward(book_phase,1.0 if book_opened else 0.0,dt*1.45)
	last_screen = g.screen
	fluid.visible = (g.screen in ["missions", "results"] or (g.screen == "run" and progress_notice_left > 0)) and fluid_rect.size.x > 0
	vessel_overlay.visible = fluid.visible
	for i in range(mud_nodes.size()): mud_nodes[i].visible = g.screen == "graves" and not g.data.graves.is_empty() and not bool(g.data.graves[0].claimed[i])
	name_edit.visible = (g.screen == "book" and book_phase >= 0.95 and HordeMeta.relic_count(int(g.data.player_level)) >= 4 and str(g.data.book_signed_at).is_empty()) or g.codex.signature_active(g)
	if name_edit.visible:
		var panel = body(g)
		name_edit.position = panel.position + Vector2(panel.size.x * 0.49, 202)
		name_edit.size = Vector2(panel.size.x * 0.44, 48)
		if g.screen == "collection":
			var field = g.codex.name_rect(g);name_edit.position = field.position;name_edit.size = field.size
	book_reaction = maxf(0, book_reaction - dt)
	if shown_xp < 0: shown_xp = float(g.data.level_souls);shown_level = int(g.data.player_level)
	var target_level = int(g.data.player_level)
	if shown_level < target_level:
		shown_xp = move_toward(shown_xp, float(HordeProgress.level_target(shown_level)), dt * maxf(38, HordeProgress.level_target(shown_level) * 0.7))
		if shown_xp >= HordeProgress.level_target(shown_level):
			shown_xp = 0;shown_level += 1;level_glow = 1.4;g.sound.play("jar_full", -15)
	else: shown_xp = move_toward(shown_xp, float(g.data.level_souls), dt * maxf(30, HordeProgress.level_target(shown_level) * 0.65))
	if is_instance_valid(fluid):
		fluid.material.set_shader_parameter("amount", clampf(shown_xp / HordeProgress.level_target(shown_level), 0, 1))
		fluid.material.set_shader_parameter("liquid", [Color("79edba"), Color("df85ff"), Color("ff7b8d"), Color("76caff")][posmod(shown_level - 1, 4)])

func body(g) -> Rect2:
	var view: Rect2 = g.full_rect()
	return Rect2(view.position + Vector2(60, 165), view.size - Vector2(120, 265))

func label(g, value: String, point: Vector2, size: int = 24, color: Color = Color("fff1d3"), center: bool = false, width: float = -1) -> void:
	g.home_menu.label(g, value, point, size, color, center, width)

func frame(g, title: String, note: String) -> Rect2:
	var r = body(g)
	label(g, title, Vector2(r.position.x, g.full_rect().position.y + 70), 42, g.GOLD, false, r.size.x * 0.62)
	label(g, note, Vector2(r.position.x, g.full_rect().position.y + 116), 20, g.MINT, false, r.size.x)
	wallet(g, Rect2(r.end.x - 370, g.full_rect().position.y + 24, 370, 62))
	return r

func button(g, rect: Rect2, text: String, action: String, primary: bool = false) -> void:
	g.pages.button(g, rect, text, action, primary)

func footer(g, right: String = "JOGAR", action: String = "play") -> void:
	var r = body(g)
	button(g, Rect2(r.position.x, g.full_rect().end.y - 78, 225, 58), "VOLTAR", "back")
	button(g, Rect2(r.end.x - 300, g.full_rect().end.y - 82, 300, 66), right, action, true)

func eye(g, point: Vector2, size: float) -> void:
	g.scenery.sprite(g.paint_target, EYE, point, size, Color.WHITE, sin(g.ui_time * 1.4) * 0.025)

func wallet(g, rect: Rect2) -> void:
	g.home_menu.slab(g, rect, Color("21152e"), Color("ba925c"), 10, 3)
	var middle = rect.position.x + rect.size.x * 0.55
	g.scenery.sprite(g.paint_target, g.art.items[1], Vector2(rect.position.x + 25, rect.get_center().y), 34)
	label(g, str(g.data.wallet), Vector2(rect.position.x + 48, rect.get_center().y + 10), 27, g.GOLD, false, rect.size.x * 0.4)
	eye(g, Vector2(middle + 18, rect.get_center().y), 36)
	label(g, str(g.data.eyes), Vector2(middle + 44, rect.get_center().y + 10), 27, Color("dda7ff"), false, rect.end.x - middle - 50)

func experiment(g, rect: Rect2) -> void:
	fluid_rect = rect
	var index = posmod(shown_level-1,4)
	var panes = [Rect2(0.245,0.216,0.515,0.583),Rect2(0.222,0.214,0.548,0.583),Rect2(0.267,0.205,0.463,0.544),Rect2(0.252,0.204,0.503,0.544)]
	if is_instance_valid(fluid):
		fluid.position = rect.position + panes[index].position*rect.size
		fluid.size = panes[index].size*rect.size
		vessel_overlay.texture = polish.icon("vessels",index)
		vessel_overlay.position = rect.position;vessel_overlay.size = rect.size
	if level_glow > 0:
		g.paint_target.draw_arc(rect.get_center(),rect.size.y*0.38+(1.4-level_glow)*24,0,TAU,40,Color(0.85,0.6,1.0,level_glow*0.25),3,true)
	label(g, "NÍVEL " + str(shown_level), rect.position + Vector2(rect.size.x * 0.5, rect.size.y + 45), 25, g.GOLD, true, rect.size.x * 1.5)

func object_icon(g, index: int, p: Vector2, height: float) -> void:
	if index < 6:
		polish.draw(g.paint_target,"objects",index,p,Vector2(height,height));return
	match index:
		6,7: g.actor.paint(g.paint_target,3 if index == 6 else 2,p+Vector2(0,height*0.48),height,g.ui_time*0.7,"run",g.ui_time)
		8:
			g.paint_target.draw_circle(p,height*0.4,Color(0.45,0.9,1.0,0.16))
			g.scenery.sprite(g.paint_target,g.art.items[2],p,height*0.85)
		9: g.scenery.sprite(g.paint_target,g.art.items[5],p,height)

func home(g) -> void:
	var d = g.home_menu.layout(g.full_rect())
	wallet(g,d.wallet)
	button(g,d.profile,"MEU PERFIL","profile_open")
	if HordeMeta.daily_available(g.data,int(Time.get_unix_time_from_system())):
		button(g,Rect2(d.profile.position+Vector2(0,63),Vector2(d.profile.size.x,44)),"+5 OLHOS GRÁTIS","daily_eyes")

func prepare(g) -> void:
	var r = frame(g, "PREPARAR A HORDA", "Selecione os objetos que quer usar. Cada item escolhido consome 1 unidade ao começar.")
	var entries: Array = []
	for item in HordeMeta.OBJECTS:
		if int(g.data.stock.get(item.id, 0)) > 0: entries.append(item)
	var columns = mini(5,maxi(1,entries.size()));var rows = ceili(entries.size()/float(columns))
	var h = 120.0 if rows > 1 else 156.0;var gap = 12.0
	for i in range(entries.size()):
		var item: Dictionary = entries[i];var w = (r.size.x - gap * (columns-1)) / columns
		var box = Rect2(r.position + Vector2((i%columns) * (w + gap), 10 + int(i/columns)*(h+gap)), Vector2(w, h))
		var selected = item.id in g.selection
		g.panel(box, Color("354f48") if selected else Color("30203f"), g.MINT if selected else Color("8b6c77"), 16, 3)
		object_icon(g, int(item.icon), box.get_center() - Vector2(0, 19), 54 if rows > 1 else 70)
		g.pages.lines(g, item.name, Rect2(box.position + Vector2(8, h-62), Vector2(w - 16, 34)), 16, g.CREAM)
		label(g, ("✓  " if selected else "") + "x" + str(g.data.stock[item.id]), Vector2(box.get_center().x, box.end.y - 10), 22, g.GOLD, true)
		g.buttons.append({"rect": box, "action": "select_object_" + item.id})
	if entries.is_empty():
		label(g, "SEU INVENTÁRIO ESTÁ VAZIO", r.position + Vector2(r.size.x * 0.5, 65), 29, g.GOLD, true)
		label(g, "Compre objetos no mercado ou encontre prêmios nas lápides.", r.position + Vector2(r.size.x * 0.5, 106), 22, g.MINT, true)
	var floor_y = r.end.y - 25
	g.paint_target.draw_line(Vector2(r.position.x + 20, floor_y), Vector2(r.end.x - 20, floor_y), Color("9e7a8c"), 4, true)
	for i in range(mini(5, 1 + int(g.data.levels.horde))):
		g.actor.paint(g.paint_target, 0, Vector2(r.position.x + 170 + i * 65, floor_y), 125, g.ui_time * 1.3 + i * 0.2, "run", g.ui_time, 0, Color.WHITE, false, 1, false)
	label(g, "A horda espera seu comando.", Vector2(r.end.x - 290, floor_y - 45), 24, g.MINT, true, 400)
	button(g, Rect2(r.position.x + 245, g.full_rect().end.y - 78, 240, 58), "VER OBJETOS", "objects_open")
	footer(g, "COMEÇAR", "commit_play")

func revive(g) -> void:
	g.paint_target.draw_rect(g.full_rect(), Color(0.025, 0.01, 0.05, 0.75))
	var r = frame(g, "MAIS UMA CHANCE?", "Uma reanimação por partida. Você mantém almas, moedas e distância.")
	g.panel(r, Color("271932"), g.GOLD, 24, 3)
	for i in range(2):
		var box = Rect2(r.position + Vector2(30 + i * r.size.x * 0.5, 24), Vector2(r.size.x * 0.5 - 60, r.size.y - 48))
		var count = 5 if i == 0 else 1
		for j in range(count): g.actor.paint(g.paint_target, 0, Vector2(box.get_center().x - (count - 1) * 20 + j * 40, box.position.y + 170), 115, g.ui_time * 0.6 + j * 0.17, "idle", g.ui_time, 0, Color.WHITE, false, 1, false)
		label(g, str(count) + (" MONSTROS" if count == 5 else " MONSTRO"), Vector2(box.get_center().x, box.position.y + 214), 30, g.CREAM, true)
		if i == 0: eye(g, Vector2(box.get_center().x - 95, box.end.y - 46), 43)
		button(g, Rect2(box.position.x + 36, box.end.y - 81, box.size.x - 72, 68), "25 OLHOS" if i == 0 else "GRÁTIS", "revive_paid" if i == 0 else "revive_free", true)
	button(g, Rect2(r.get_center().x - 160, g.full_rect().end.y - 78, 320, 58), "ENCERRAR PARTIDA", "revive_decline")

func results(g) -> void:
	var r = frame(g, "A NOITE TERMINOU", "As almas alimentam o altar. As missões fazem o experimento crescer.")
	g.panel(r, Color("241830"), Color("8a6a78"), 22, 2)
	var left = Rect2(r.position + Vector2(20, 20), Vector2(r.size.x * 0.36, r.size.y - 40))
	label(g, "ALTAR DE ALMAS", left.position + Vector2(left.size.x * 0.5, 29), 29, g.GOLD, true)
	var amount = mini(g.runner.souls, floori(maxf(0, g.result_time - 0.2) * maxf(6, g.runner.souls / 1.8)))
	var total = int(g.run_report.get("old_altar", 0)) + amount
	var shown = total % 100
	g.draw_soul_grid(Rect2(left.position + Vector2(15, 56), Vector2(left.size.x - 30, left.size.y - 133)), shown, 100)
	label(g, str(shown) + " / 100", Vector2(left.get_center().x, left.end.y - 44), 28, g.MINT, true)
	label(g, "+" + str(g.run_report.get("graves", 0)) + " PARES DE LÁPIDES", Vector2(left.get_center().x, left.end.y - 12), 23, g.GOLD, true)
	var x = r.position.x + r.size.x * 0.41
	var stats = [["ALMAS", str(g.runner.souls)], ["DISTÂNCIA", str(g.runner.distance()) + " m"], ["MOEDAS", str(g.runner.coins)], ["MAIOR HORDA", str(g.runner.max_horde)]]
	for i in range(4):
		var p = Vector2(x + (i % 2) * 240, r.position.y + 45 + int(i / 2) * 92)
		label(g, stats[i][0], p, 18, g.MINT);label(g, stats[i][1], p + Vector2(0, 37), 34, g.GOLD)
	experiment(g, Rect2(r.end.x - 155, r.position.y + 20, 120, r.size.y - 90))
	label(g, "MISSÕES +" + str(g.run_mission_report.get("points", 0)) + " ESSÊNCIA", Vector2(x, r.end.y - 86), 22, g.MINT)
	if int(g.run_mission_report.get("bonuses", 0)) > 0: label(g, "SUBIU DE NÍVEL! +" + str(g.run_mission_report.coins) + " MOEDAS · +" + str(g.run_mission_report.eyes) + " OLHOS", Vector2(x, r.end.y - 48), 20, g.GOLD, false, r.size.x * 0.48)
	button(g, Rect2(r.position.x, g.full_rect().end.y - 78, 225, 58), "MENU", "home")
	button(g, Rect2(r.get_center().x - 145, g.full_rect().end.y - 78, 290, 58), "LÁPIDES (" + str(g.data.graves.size()) + ")", "graves_open")
	button(g, Rect2(r.end.x - 300, g.full_rect().end.y - 82, 300, 66), "JOGAR DE NOVO", "play", true)

func missions(g) -> void:
	var r = frame(g, "EXPERIMENTO DE RESSURREIÇÃO", "Complete missões para encher o recipiente e avançar de nível.")
	var chamber = Rect2(r.position, Vector2(r.size.x * 0.31, r.size.y))
	g.panel(chamber, Color("21192d"), Color("997c61"), 20, 2)
	experiment(g, Rect2(chamber.get_center().x - 80, chamber.position.y + 36, 160, chamber.size.y - 135))
	g.pages.lines(g, HordeMeta.EXPERIMENTS[posmod(int(g.data.player_level) - 1, 4)], Rect2(chamber.position + Vector2(15, chamber.size.y - 58), Vector2(chamber.size.x - 30, 42)), 20, g.MINT)
	var x = chamber.end.x + 20;var w = r.end.x - x
	var missions = MonsterCatalog.active_missions(int(g.data.mission_tier))
	for i in range(3):
		var m: Dictionary = missions[i];var row = Rect2(x, r.position.y + i * (r.size.y - 70) / 3, w, (r.size.y - 94) / 3)
		g.panel(row, Color("30213e"), Color("89647d"), 14, 2)
		var count = int(g.data.mission_progress.get(m.id, 0))
		label(g, m.title, row.position + Vector2(20, 32), 24, g.GOLD, false, w - 170)
		label(g, str(count) + " / " + str(m.target), Vector2(row.end.x - 130, row.position.y + 32), 22, g.CREAM)
		g.progress_bar(Rect2(row.position + Vector2(20, 48), Vector2(w - 160, 10)), float(count) / maxf(1, float(m.target)), g.MINT)
		label(g, ("EM UMA PARTIDA" if m.mode == "best" else "ACUMULATIVA") + " · +" + str(m.ritual) + " ESSÊNCIA", row.position + Vector2(20, row.size.y - 12), 16, g.MINT)
	var dose_count = int(g.data.doses) if Time.get_unix_time_from_system() < int(g.data.dose_reset_at) + 86400 else 3
	for i in range(3): polish.draw(g.paint_target,"relics",7,Vector2(x+12+i*22,r.end.y-41),Vector2(24,31),Color.WHITE if i < dose_count else Color(0.35,0.3,0.4,0.65))
	label(g, "ADRENALINA " + str(dose_count) + "/3 · +50% NAS MISSÕES · RENOVA EM 24H", Vector2(x+80, r.end.y - 35), 16, g.MINT, false, w-80)
	label(g, str(g.data.level_souls) + " / " + str(HordeProgress.level_target(int(g.data.player_level))) + " ESSÊNCIA · PRÓXIMO NÍVEL: " + str(100 + mini(50, int(g.data.player_level) + 1) * 10) + " MOEDAS + " + str(HordeMeta.level_eyes(int(g.data.player_level) + 1)) + " OLHOS", Vector2(x, r.end.y - 7), 17, g.GOLD, false, w)
	footer(g)

func grave_rects(g) -> Array[Rect2]:
	var r = body(g);var h = r.size.y - 12;var w = minf(290, r.size.x * 0.3)
	return [Rect2(r.get_center().x - w - 40, r.position.y + 10, w, h), Rect2(r.get_center().x + 40, r.position.y + 10, w, h)]

func clean_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position + rect.size * Vector2(0.16, 0.35), rect.size * Vector2(0.68, 0.42))

func graves(g) -> void:
	var r = frame(g, "OS PRÊMIOS DO CEMITÉRIO", "Passe o dedo para limpar cada lápide e revelar o que o coveiro deixou.")
	if g.data.graves.is_empty():
		g.scenery.sprite(g.paint_target, grave_texture, r.get_center() - Vector2(0, 20), r.size.y * 0.65)
		label(g, "JUNTE 100 ALMAS PARA ABRIR DUAS LÁPIDES", Vector2(r.get_center().x, r.end.y - 3), 28, g.GOLD, true, r.size.x)
		footer(g);return
	for i in range(4):
		g.animated_soul(r.get_center() + Vector2(sin(g.ui_time * 0.35 + i * 1.7) * r.size.x * 0.44, cos(g.ui_time * 0.48 + i * 2.1) * r.size.y * 0.4), 18, g.ui_time + i, Color(1,1,1,0.28))
	for layer in range(3):
		var mist = PackedVector2Array()
		for j in range(33): mist.append(Vector2(r.position.x+j*r.size.x/32.0,r.end.y-22-layer*28+sin(j*0.37+g.ui_time*0.35+layer)*9))
		g.paint_target.draw_polyline(mist,Color(0.57,0.87,0.79,0.045),18,true)
	var pair: Dictionary = g.data.graves[0]
	var rects = grave_rects(g)
	for side in range(2):
		var rect: Rect2 = rects[side]
		g.paint_target.draw_texture_rect(grave_texture, rect, false)
		var clean = clean_rect(rect)
		var prize: Dictionary = pair.rewards[side]
		if prize.type == "eyes": eye(g, clean.get_center() - Vector2(0, 22), 57)
		elif prize.type == "coins": g.scenery.sprite(g.paint_target, g.art.items[1], clean.get_center() - Vector2(0, 22), 56)
		elif prize.type == "object":
			for item in HordeMeta.OBJECTS:
				if item.id == prize.id: object_icon(g, item.icon, clean.get_center() - Vector2(0, 22), 52)
		elif prize.type == "cosmetic": hat(g.paint_target, clean.get_center() - Vector2(0, 22), 84,str(prize.id))
		else: label(g, "X", clean.get_center(), 58, g.CORAL, true)
		g.pages.lines(g, str(prize.label), Rect2(clean.position + Vector2(3, clean.size.y * 0.59), Vector2(clean.size.x - 6, clean.size.y * 0.4)), 19, Color("fff0c9"))
		if not bool(pair.claimed[side]):
			var mud: ColorRect = mud_nodes[side]
			mud.position = clean.position;mud.size = clean.size
			var key = str(pair.id) + ":" + str(pair.clean[side].size())
			if mud_keys[side] != key:
				var mask = Image.create(12, 16, false, Image.FORMAT_RGBA8);mask.fill(Color.BLACK)
				for j in pair.clean[side]: mask.set_pixel(int(j) % 12, int(int(j) / 12), Color.WHITE)
				mud.material.set_shader_parameter("cleaned", ImageTexture.create_from_image(mask));mud_keys[side] = key
		else:
			label(g, "RESGATADO", Vector2(rect.get_center().x, rect.end.y - 12), 22, g.MINT, true)
			if reveal_left[side] > 0:
				var t = 1.5-reveal_left[side]
				var color = Color(1.0,0.77,0.35,reveal_left[side]*0.46)
				g.paint_target.draw_arc(clean.get_center()-Vector2(0,20),25+t*65,0,TAU,36,color,3,true)
				for ray in range(12):
					var direction = Vector2.from_angle(ray*TAU/12+t*0.4)
					g.paint_target.draw_line(clean.get_center()-Vector2(0,20)+direction*(30+t*30),clean.get_center()-Vector2(0,20)+direction*(45+t*55),color,2,true)
	if brush_down:
		polish.draw(g.paint_target,"props",3,brush_point+Vector2(18,-17),Vector2(70,70),Color.WHITE,sin(g.ui_time*24)*0.08)
	var both = bool(pair.claimed[0]) and bool(pair.claimed[1])
	button(g, Rect2(r.get_center().x - 190, g.full_rect().end.y - 78, 380, 58), "PRÓXIMO PAR" if both else ("DEIXAR AO COVEIRO · 180" if not pair.started else "LIMPE AS DUAS LÁPIDES"), "graves_next" if both else "graves_sell" if not pair.started else "none")
	button(g, Rect2(r.position.x, g.full_rect().end.y - 78, 225, 58), "VOLTAR", "back")
	label(g, str(g.data.graves.size()) + " PARES GUARDADOS", Vector2(r.end.x - 220, g.full_rect().end.y - 40), 20, g.MINT, false, 240)

func brush(g, point: Vector2) -> void:
	if g.data.graves.is_empty(): return
	brush_point = point
	var pair: Dictionary = g.data.graves[0]
	for side in range(2):
		if pair.claimed[side]: continue
		var rect = clean_rect(grave_rects(g)[side])
		var cell = rect.size / Vector2(12, 16)
		var changed = false
		for j in range(192):
			if j in pair.clean[side]: continue
			var p = rect.position + (Vector2(j % 12, int(j / 12)) + Vector2.ONE * 0.5) * cell
			if Geometry2D.get_closest_point_to_segment(p, brush_last, point).distance_to(p) < 24:
				pair.clean[side].append(j);changed = true;pair.started = true
		if changed: g.ui_effects.spark(point, Color("ad965d"), 2)
		if changed and pair.clean[side].size() >= 106:
			var result = HordeMeta.claim_grave(g.data, side)
			g.save_game();reveal_left[side] = 1.5;g.sound.play("challenge");g.show_toast(result, 2.7)
	brush_last = point

func hat(canvas: Node2D, p: Vector2, size: float, id: String = "coveiro") -> void:
	polish.draw(canvas,"props",HordeMeta.cosmetic_index(id),p,Vector2(size,size*0.85))

func signature_rect(g) -> Rect2:
	var r = body(g)
	return Rect2(r.position + Vector2(r.size.x * 0.49, 269), Vector2(r.size.x * 0.44, r.size.y - 282))

func book(g) -> void:
	var r = frame(g, "LIVRO DOS MORTOS", "Quatro relíquias abrem o livro. Depois, sua assinatura e três selos de prestígio.")
	var unlocked = HordeMeta.relic_count(int(g.data.player_level)) >= 4
	var center = r.position + Vector2(r.size.x*0.22,r.size.y*0.43)
	var box = Vector2(r.size.x*0.43-16,r.size.y*0.75)*(1.0+sin(g.ui_time*1.8)*0.006)
	var turn = clampf(book_phase*3.0,0,3)
	var index = floori(turn);var blend = turn-index
	var tint = Color.WHITE if unlocked else Color(0.65,0.58,0.68)
	var tilt = sin(g.ui_time*1.5)*0.009+sin(book_reaction*35)*book_reaction*0.025
	polish.draw(g.paint_target,"book",index,center,box,tint,tilt)
	if blend > 0.001:
		var next_tint = tint;next_tint.a = blend
		polish.draw(g.paint_target,"book",mini(index+1,3),center,box,next_tint,tilt)
	if book_phase >= 0.99 and not str(g.data.book_signed_at).is_empty():
		var stamp = Rect2(center+Vector2(25,-20),Vector2(box.x*0.32,box.y*0.26))
		label(g,str(g.data.book_name),stamp.position+Vector2(0,-10),14,Color("8f2034"),false,stamp.size.x)
		for i in range(1,g.data.book_signature.size()):
			var a = g.data.book_signature[i-1];var b = g.data.book_signature[i]
			if b.get("new",false): continue
			g.paint_target.draw_line(stamp.position+Vector2(a.x,a.y)*stamp.size,stamp.position+Vector2(b.x,b.y)*stamp.size,Color("9d2438"),1.4,true)
	g.buttons.append({"rect": Rect2(r.position, Vector2(r.size.x * 0.43, r.size.y)), "action": "book_touch"})
	label(g,"TOQUE PARA " + ("FECHAR" if book_opened else "ABRIR") if unlocked else "AS RELÍQUIAS DESPERTAM O LIVRO",r.position+Vector2(r.size.x*0.22,r.size.y*0.85),15,g.MINT,true,r.size.x*0.43)
	var earned_seals = HordeMeta.seals(int(g.data.player_level))
	for seal in range(3):
		var at = r.position + Vector2(r.size.x * 0.22 + (seal - 1) * 52, r.size.y - 12)
		polish.draw(g.paint_target,"relics",4+seal,at,Vector2(48,48),Color.WHITE if seal < earned_seals else Color(0.35,0.29,0.4,0.7))
	if earned_seals > 0:
		for i in range(earned_seals * 2):
			var a = g.ui_time * 0.5 + i * TAU / (earned_seals * 2)
			g.animated_soul(r.position + Vector2(r.size.x * 0.22 + cos(a) * r.size.y * 0.36, r.size.y * 0.45 + sin(a) * r.size.y * 0.4), 21, g.ui_time + i, Color(1,1,1,0.6))
	for i in range(4):
		var p = r.position + Vector2(r.size.x * 0.49 + (i % 2) * r.size.x * 0.25, 26 + int(i / 2) * 66)
		var owned = int(g.data.player_level) >= HordeMeta.RELIC_LEVELS[i]
		polish.draw(g.paint_target,"relics",i,p+Vector2(18,5),Vector2(45,45),Color.WHITE if owned else Color(0.34,0.30,0.39,0.8))
		label(g,HordeMeta.RELIC_NAMES[i],p+Vector2(48,0),17,g.GOLD if owned else Color("98859d"),false,r.size.x*0.24-48)
		label(g,("✓ " if owned else "")+"NÍVEL "+str(HordeMeta.RELIC_LEVELS[i]),p+Vector2(48,25),16,g.MINT)
	label(g, "SELOS: " + str(HordeMeta.seals(int(g.data.player_level))) + "/3 · NÍVEIS 100 / 125 / 150", r.position + Vector2(r.size.x * 0.49, 175), 20, g.GOLD, false, r.size.x * 0.47)
	if unlocked:
		var sr = signature_rect(g)
		g.panel(sr, Color("d9c7aa"), Color("78524a"), 10, 2)
		var points: Array = g.data.book_signature if not str(g.data.book_signed_at).is_empty() else signature_points
		for i in range(1, points.size()):
			if points[i].get("new", false): continue
			g.paint_target.draw_line(sr.position + Vector2(points[i-1].x,points[i-1].y) * sr.size, sr.position + Vector2(points[i].x,points[i].y) * sr.size, Color("9d2438"), 3, true)
		if not str(g.data.book_signed_at).is_empty():
			label(g, str(g.data.book_name), r.position + Vector2(r.size.x * 0.49, 241), 29, g.GOLD)
		else: label(g, "ASSINE COM O DEDO", Vector2(sr.get_center().x, sr.end.y - 8), 15, Color("71524f"), true)
	else:
		g.pages.lines(g, "O livro está faminto. Alcance o nível 75 para receber a última relíquia e assinar seu nome.", Rect2(r.position + Vector2(r.size.x * 0.49, 215), Vector2(r.size.x * 0.45, 120)), 25, g.MINT, false, 4)
	footer(g, "ASSINAR" if unlocked and str(g.data.book_signed_at).is_empty() else "MISSÕES", "book_sign" if unlocked and str(g.data.book_signed_at).is_empty() else "missions")
	if unlocked and str(g.data.book_signed_at).is_empty(): button(g, Rect2(r.get_center().x - 90, g.full_rect().end.y - 78, 180, 58), "LIMPAR", "signature_clear")

func profile(g) -> void:
	var r = frame(g, "PERDAS DA HORDA" if profile_page == 1 else "PERFIL DA HORDA", "Monstros perdidos em cada perigo." if profile_page == 1 else "Seu recorde é medido pelas almas capturadas em uma única partida.")
	var values = [["MELHOR PARTIDA", str(g.data.best_souls) + " ALMAS"], ["DISTÂNCIA RECORDE", str(g.data.best) + " m"], ["PARTIDAS", str(g.data.runs)], ["ALMAS CAPTURADAS", str(g.data.total_souls)], ["MAIOR HORDA", str(g.data.lifetime.get("horde", 1))], ["MOEDAS RECOLHIDAS", str(g.data.lifetime.get("coins", 0))], ["VEÍCULOS VIRADOS", str(g.data.lifetime.get("cars", 0))], ["TÚNEIS ATRAVESSADOS", str(g.data.lifetime.get("tunnels", 0))], ["TEMPO JOGADO", str(int(g.data.lifetime.get("seconds", 0)) / 60) + " MIN"]]
	if profile_page == 1:
		values = []
		var names = {"fall":"BURACOS", "car":"CARROS", "bomb":"BOMBAS", "helicopter":"HELICÓPTEROS", "air_bomb":"BOMBAS AÉREAS", "bullet":"TIROS", "rocket_explosion":"EXPLOSÕES DA BAZUCA", "camera":"FICOU PARA TRÁS", "spikes":"ESPINHOS", "crate":"CAIXAS", "truck":"CAMINHÕES", "tank":"TANQUES", "bus":"ÔNIBUS", "plane":"AVIÕES", "moto":"MOTOS", "impact":"IMPACTOS"}
		var keys: Array = g.data.death_causes.keys()
		keys.sort_custom(func(a,b): return int(g.data.death_causes[a]) > int(g.data.death_causes[b]))
		for key in keys.slice(0,9): values.append([str(names.get(key,key)),str(g.data.death_causes[key])])
		if values.is_empty(): values = [["SEM PERDAS REGISTRADAS","0"]]
	for i in range(values.size()):
		var w = (r.size.x - 28) / 3;var h = (r.size.y - 30) / 3
		var box = Rect2(r.position + Vector2((i % 3) * (w + 14), int(i / 3) * (h + 10)), Vector2(w,h))
		g.panel(box, Color("2e203c"), Color("806079"), 14, 2)
		label(g, values[i][0], box.position + Vector2(18, 28), 18, g.MINT)
		label(g, values[i][1], box.position + Vector2(18, h - 21), 29, g.GOLD, false, w - 35)
	footer(g, "COPIAR RECORDE", "share_score")
	button(g, Rect2(r.get_center().x - 145, g.full_rect().end.y - 78, 290, 58), "VISÃO GERAL" if profile_page == 1 else "PERDAS POR CAUSA", "causes_open")

func settle_stats(g) -> void:
	var stats = g.runner.stats()
	for key in stats:
		if key in ["horde", "distance"]: g.data.lifetime[key] = maxi(int(g.data.lifetime.get(key, 0)), int(stats[key]))
		else: g.data.lifetime[key] = int(g.data.lifetime.get(key, 0)) + int(stats[key])
	g.data.lifetime.seconds = int(g.data.lifetime.get("seconds", 0)) + int(g.runner.elapsed)
	for cause in g.runner.loss_causes: g.data.death_causes[cause] = int(g.data.death_causes.get(cause, 0)) + int(g.runner.loss_causes[cause])

func action(g, a: String) -> bool:
	if a.begins_with("cosmetic_"):
		if HordeMeta.equip_cosmetic(g.data,a.trim_prefix("cosmetic_")): g.save_game();g.sound.play("buy")
		else: g.show_toast("FALTAM MOEDAS.");g.sound.play("ui_denied")
		return true
	if a.begins_with("evolution_"):
		detail_kind = clampi(int(a.trim_prefix("evolution_")), 0, 3);g.change_screen("evolution");return true
	if a == "evolve_commit":
		if not detail_buy_action.is_empty(): g.perform_action(detail_buy_action)
		return true
	if a == "commit_play":
		if g.screen == "prepare": g.start_run()
		return true
	if a.begins_with("select_object_"):
		var id = a.trim_prefix("select_object_")
		if id in g.selection: g.selection.erase(id)
		elif int(g.data.stock.get(id, 0)) > 0:
			if id in ["power_fly","power_mask"]:
				g.selection.erase("power_fly");g.selection.erase("power_mask")
				g.show_toast("UMA TRANSFORMAÇÃO INICIAL POR PARTIDA.")
			g.selection.append(id)
		g.sound.play("ui_confirm");return true
	if a.begins_with("object_buy_"):
		if HordeMeta.buy_object(g.data, a.trim_prefix("object_buy_")): g.save_game();g.sound.play("buy");g.show_toast("GUARDADO NO INVENTÁRIO. ESCOLHA ANTES DE JOGAR.")
		else: g.sound.play("ui_denied");g.show_toast("MOEDAS INSUFICIENTES.")
		return true
	match a:
		"objects_open": g.open_market(0)
		"book_open": book_phase = 0.0;g.change_screen("book")
		"profile_open": profile_from = g.screen;g.change_screen("profile")
		"graves_open": graves_from = g.screen;g.change_screen("graves")
		"daily_eyes":
			if HordeMeta.claim_daily(g.data, int(Time.get_unix_time_from_system())): g.save_game();g.sound.play("challenge");g.show_toast("+5 OLHOS MALDITOS! VOLTE EM 24 HORAS.")
			else: g.show_toast("O PRESENTE AINDA ESTÁ DESCANSANDO.")
		"revive_paid", "revive_free":
			if g.screen != "revive" or g.revive_used: return true
			var paid = a == "revive_paid"
			if paid and int(g.data.eyes) < 25: g.show_toast("FALTAM " + str(25 - int(g.data.eyes)) + " OLHOS MALDITOS.");return true
			if paid: g.data.eyes -= 25
			g.revive_used = true;g.runner.revive_horde(5 if paid else 1);g.end_delay = -1;g.save_game();g.change_screen("run");g.sound.play("revive");g.show_toast("DE VOLTA À NOITE! PROTEÇÃO POR 3 SEGUNDOS.")
		"revive_decline": g.finish_run()
		"graves_sell":
			if HordeMeta.sell_graves(g.data): g.save_game();g.sound.play("coin");g.show_toast("+180 MOEDAS DO COVEIRO")
		"graves_next":
			if not g.data.graves.is_empty() and g.data.graves[0].claimed[0] and g.data.graves[0].claimed[1]: g.data.graves.pop_front();g.save_game()
		"hat_toggle":
			if HordeMeta.equip_cosmetic(g.data,"coveiro"): g.save_game();g.sound.play("buy")
			else: g.show_toast("FALTAM MOEDAS.")
		"book_touch":
			book_reaction = 0.8
			if HordeMeta.relic_count(int(g.data.player_level)) >= 4: book_opened = not book_opened
			g.sound.play("ui_confirm", -15)
		"signature_clear": signature_points.clear()
		"book_sign":
			if HordeMeta.relic_count(int(g.data.player_level)) < 4: return true
			if signature_points.size() < 3 or name_edit.text.strip_edges().is_empty(): g.show_toast("ESCREVA SEU NOME E ASSINE COM O DEDO.");return true
			g.data.book_name = name_edit.text.strip_edges();g.data.book_signature = signature_points.duplicate(true)
			g.data.book_signed_at = Time.get_datetime_string_from_system();g.save_game();g.sound.play("challenge");book_reaction = 1.0
		"share_score":
			DisplayServer.clipboard_set("Minha horda capturou " + str(g.data.best_souls) + " almas em uma partida de Horda Zumbi! Recorde: " + str(g.data.best) + " m. #HordaZumbi")
			g.show_toast("RECORDE COPIADO! COLE ONDE QUISER COMPARTILHAR.")
		"causes_open": profile_page = 1 - profile_page

		"back":
			if g.screen == "revive": g.finish_run()
			elif g.screen == "evolution": g.change_screen("market")
			elif g.screen == "profile": g.change_screen(profile_from)
			elif g.screen == "graves": g.change_screen(graves_from)
			else: return false
		"home":
			if g.screen == "revive": g.finish_run();g.end_delay = -1;g.change_screen("home")
			else: return false
		_: return false
	return true

func input(g, event: InputEvent) -> bool:
	if g.screen not in ["graves", "book"]: return false
	var point = Vector2.ZERO;var pressed = false;var released = false;var moved = false;var id = -1
	if event is InputEventScreenTouch:
		point = g.to_local(event.position);pressed = event.pressed;released = not event.pressed;id = event.index
	elif event is InputEventScreenDrag: point = g.to_local(event.position);moved = true;id = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = g.to_local(event.position);pressed = event.pressed;released = not event.pressed
	elif event is InputEventMouseMotion: point = g.to_local(event.position);moved = true
	else: return false
	if g.screen == "graves":
		if pressed:
			for rect in grave_rects(g):
				if clean_rect(rect).has_point(point) and not g.data.graves.is_empty(): brush_down = true;brush_id = id;brush_last = point;brush(g, point);return true
		if moved and brush_down and id == brush_id: brush(g, point);return true
		if released and brush_down and id == brush_id: brush_down = false;g.save_game();return true
	if g.screen == "book" and HordeMeta.relic_count(int(g.data.player_level)) >= 4 and str(g.data.book_signed_at).is_empty():
		var sr = signature_rect(g)
		if pressed and sr.has_point(point): signature_down = true;signature_points.append({"x": (point.x-sr.position.x)/sr.size.x, "y": (point.y-sr.position.y)/sr.size.y, "new": true});return true
		if moved and signature_down:
			if sr.has_point(point) and signature_points.size() < 1200: signature_points.append({"x": (point.x-sr.position.x)/sr.size.x, "y": (point.y-sr.position.y)/sr.size.y, "new": false})
			return true
		if released and signature_down: signature_down = false;return true
	return false

func draw_run_notice(g) -> void:
	if progress_notice_left <= 0: return
	var v: Rect2 = g.full_rect()
	experiment(g, Rect2(v.end.x - 125, v.position.y + 142, 70, 112))
	label(g, "+ESSÊNCIA", Vector2(v.end.x - 90, v.position.y + 129), 17, g.MINT, true)

func evolution(g) -> void:
	var kind = detail_kind
	var r = frame(g, MonsterCatalog.MONSTERS[kind].name.to_upper(), "Benefícios permanentes e cumulativos. As compras anteriores foram preservadas.")
	g.panel(r, Color("261b32"), Color("92725f"), 20, 2)
	g.actor.paint(g.paint_target, kind, r.position + Vector2(r.size.x * 0.18, r.size.y - 35), minf(290, r.size.y - 80), g.ui_time * 0.7, "fly" if kind == 3 else "idle", g.ui_time, 0, Color.WHITE, false, 1, false)
	var benefits: Array[String] = []
	var next_description = "Todos os benefícios já estão ativos."
	var price = 0;detail_buy_action = ""
	if kind == 0:
		for i in range(MonsterCatalog.UPGRADES.size()):
			var item: Dictionary = MonsterCatalog.UPGRADES[i];var value = int(g.data.levels[item.id])
			if value > 0: benefits.append(str(item.name) + " · " + str(value) + "/" + str(item.max))
			if detail_buy_action.is_empty() and value < int(item.max):
				detail_buy_action = "buy_" + str(i);price = MonsterCatalog.upgrade_cost(item, value);next_description = str(item.name) + ": " + str(item.description)
	elif kind == 1:
		if 1 in g.data.owned: benefits.append("30% das capturas podem virar esqueletos.")
		else: detail_buy_action = "skin_1";price = 1000;next_description = "Libera o esqueleto para surgir nas capturas."
	else:
		var chain = HordeMeta.chain(g.data, kind)
		for item in MonsterCatalog.POWER_UPGRADES:
			if int(item.kind) == kind and int(g.data.power_levels[item.id]) > 0: benefits.append(str(item.name) + " · " + str(g.data.power_levels[item.id]) + "/" + str(item.max))
		if not chain.owned:
			detail_buy_action = "power_buy_" + str(kind);price = 2800 if kind == 2 else 0;next_description = "Libera a transformação para a sua horda."
		elif not chain.full:
			detail_buy_action = "power_upgrade_" + str(chain.next.index);price = int(chain.next.price);next_description = str(chain.next.name) + ": " + str(chain.next.description)
	var x = r.position.x + r.size.x * 0.37;var w = r.end.x - x - 25
	label(g, "BENEFÍCIOS ATIVOS", Vector2(x, r.position.y + 34), 25, g.GOLD)
	if benefits.is_empty(): benefits.append("Habilidade básica da criatura.")
	for i in range(benefits.size()): label(g, "✓ " + benefits[i], Vector2(x, r.position.y + 75 + i * 36), 22, g.MINT, false, w)
	var next = Rect2(x - 10, r.end.y - 115, w + 10, 96)
	g.panel(next, Color("38263e"), Color("ae8a5d"), 12, 2)
	g.pages.lines(g, "PRÓXIMO: " + next_description, next.grow(-15), 22, g.CREAM, false, 3)
	button(g, Rect2(r.position.x, g.full_rect().end.y - 78, 225, 58), "VOLTAR", "back")
	if not detail_buy_action.is_empty(): button(g, Rect2(r.end.x - 360, g.full_rect().end.y - 82, 360, 66), "EVOLUIR · " + str(price) + " MOEDAS", "evolve_commit", true)
	else: label(g, "EVOLUÇÃO COMPLETA", Vector2(r.end.x - 310, g.full_rect().end.y - 40), 25, g.MINT)

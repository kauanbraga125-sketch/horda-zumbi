class_name HordeMarket
extends RefCounted

const TITLES = ["OBJETOS", "MELHORIAS", "ACESSÓRIOS", "MOEDAS"]
const SHEET = preload("res://assets/art/market-art-v82.png")
var category = 0
var page = 0
var scroll = 0.0
var max_scroll = 0.0
var selected = ""
var expanded: Dictionary = {}
var sprites: Dictionary = {}

func _init() -> void :
	var regions = {"logo": Rect2(8, 82, 1520, 490), "shoe": Rect2(0, 620, 384, 350), "magnet": Rect2(390, 606, 378, 364), "potion": Rect2(768, 598, 384, 378), "church": Rect2(1152, 590, 384, 390)}
	for key in regions:
		var texture = AtlasTexture.new()
		texture.atlas = SHEET
		texture.region = regions[key]
		texture.filter_clip = true
		sprites[key] = texture

func open(tab: int = 0) -> void :
	category = clampi(tab, 0, 3)
	page = 0
	scroll = 0
	max_scroll = 0
	selected = ""
	expanded.clear()

func update(_dt: float) -> void :
	pass

func select(key: String) -> void :
	selected = key

func layout(view: Rect2) -> Dictionary:
	var margin = maxf(32, view.size.x * 0.055)
	var left = view.position.x + margin
	var right = view.end.x - margin
	var sidebar_width = clampf(view.size.x * 0.18, 214, 320)
	var top = view.position.y + 190
	var grid = Rect2(left + sidebar_width + 20, top, right - left - sidebar_width - 20, view.size.y - 238)
	var gap = 14.0
	var card_size = Vector2((grid.size.x - gap) * 0.5, (grid.size.y - gap) * 0.5)
	var title_width = minf(view.size.x * 0.3, 450)
	var title = Rect2(left - 12, view.position.y + 10, title_width, title_width * 490 / 1520)
	var tabs: Array[Rect2] = []
	for i in range(4):
		tabs.append(Rect2(left, top + i * 96, sidebar_width, 84))
	return {"view": view, "title": title, "tabs": tabs, "grid": grid, "card_size": card_size, "gap": gap, 
		"wallet": Rect2(right - 218, view.position.y + 28, 218, 72), 
		"back": Rect2(left, grid.end.y - 70, sidebar_width, 70)}

func items(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match category:
		0:
			for i in range(HordeMeta.OBJECTS.size()):
				var item: Dictionary = HordeMeta.OBJECTS[i]
				result.append({"key": item.id, "name": item.name, "description": item.description, "status": "ESTOQUE x" + str(data.stock.get(item.id, 0)), "price": item.price, "full": false, "action": "object_buy_" + item.id, "illustration": "object", "index": i, "kind": 0})
		1:
			var next = {};var done = 0;var maximum = 1
			for i in range(MonsterCatalog.UPGRADES.size()):
				var item: Dictionary = MonsterCatalog.UPGRADES[i];var level = int(data.levels.get(item.id, 0))
				done += level;maximum += int(item.max)
				if next.is_empty() and level < int(item.max): next = {"index": i, "description": item.description, "name": item.name, "price": MonsterCatalog.upgrade_cost(item, level)}
			result.append({"key": "zombie_chain", "name": "ZUMBI · NÍVEL " + str(done + 1), "description": "Todas as melhorias da horda concluídas." if next.is_empty() else "PRÓXIMO: " + str(next.name) + ". " + str(next.description), "level_value": done + 1, "level_max": maximum, "price": int(next.get("price", 0)), "full": next.is_empty(), "action": "buy_" + str(next.get("index", 0)), "illustration": "monster", "index": 0, "kind": 0})
			result.append({"key": "skeleton", "name": "ESQUELETO", "description": "Civis capturados têm 30% de chance de virar esqueleto. Visual aprovado da coleção.", "status": "NA COLEÇÃO" if 1 in data.owned else "MONSTRO DESBLOQUEÁVEL", "price": 1000, "full": 1 in data.owned, "action": "skin_1", "illustration": "monster", "index": 1, "kind": 1})
			for power in MonsterCatalog.POWERS:
				var chain = HordeMeta.chain(data, int(power.kind));var nxt: Dictionary = chain.next
				var name = "MOSCA MUTANTE" if power.kind == 3 else "MASCARADO"
				var description = str(power.description) if not chain.owned else ("TODOS OS BENEFÍCIOS: " + str(chain.benefits) if chain.full else "PRÓXIMO: " + str(nxt.name) + ". " + str(nxt.description))
				result.append({"key": "monster_chain_" + str(power.kind), "name": name + " · " + ("NÍVEL " + str(chain.level) if chain.owned else "BLOQUEADO"), "description": description, "status": "ATUAL: " + str(chain.benefits), "level_value": chain.level, "level_max": 4 if power.kind == 3 else 10, "price": power.price if not chain.owned else int(nxt.get("price", 0)), "full": chain.full, "action": "power_buy_" + str(power.kind) if not chain.owned else "power_upgrade_" + str(nxt.get("index", 0)), "illustration": "power", "index": power.kind, "kind": power.kind})
		2:
			for i in range(MonsterCatalog.AREAS.size()):
				var item: Dictionary = MonsterCatalog.AREAS[i]
				result.append({"key": "area" + str(i), "name": item.name.to_upper(), "description": item.description, "status": "NA ROTA" if i in data.areas else "CENÁRIO", "price": item.price, "full": i in data.areas, "action": "area_" + str(i), "illustration": "area", "index": i, "kind": 0})
			for item in HordeMeta.COSMETICS:
				result.append({"key":item.id,"name":item.name,"description":"Acessório para o líder zumbi. Também pode sair nas lápides.","status":"EQUIPADO" if data.equipped_hat == item.id else "NA COLEÇÃO" if item.id in data.cosmetics else "ACESSÓRIO","price":0 if item.id in data.cosmetics else item.price,"full":false,"action":"cosmetic_"+item.id,"illustration":"hat","index":item.icon,"kind":0})
		3:
			var available = HordeMeta.daily_available(data, int(Time.get_unix_time_from_system()))
			result.append({"key": "daily", "name": "PRESENTE DA MADRUGADA", "description": "5 Olhos Malditos a cada 24 horas. Toque em resgatar quando estiver disponível.", "status": "DISPONÍVEL" if available else "VOLTE EM " + str(ceili((int(data.daily_claim_at) + 86400 - Time.get_unix_time_from_system()) / 3600.0)) + " H", "price": 0, "full": not available, "action": "daily_eyes", "illustration": "eye", "index": 0, "kind": 0})
			result.append({"key": "graves", "name": "PRÊMIOS DO CEMITÉRIO", "description": "100 almas abrem duas lápides. Limpe as duas ou entregue o par fechado por 180 moedas.", "status": str(data.graves.size()) + " PARES À ESPERA", "price": 0, "full": false, "action": "graves_open", "illustration": "grave", "index": 0, "kind": 0})
	return result

func sync_scroll(entries: Array[Dictionary], d: Dictionary) -> void :
	var rows = ceili(entries.size() / 2.0)
	max_scroll = maxf(0, rows * (d.card_size.y + d.gap) - d.gap - d.grid.size.y)
	scroll = clampf(scroll, 0, max_scroll)

func card_rect(index: int, d: Dictionary) -> Rect2:
	return Rect2(d.grid.position + Vector2((index % 2) * (d.card_size.x + d.gap), floori(index / 2.0) * (d.card_size.y + d.gap) - scroll), d.card_size)

func purchase_rect(rect: Rect2) -> Rect2:
	var width = minf(226, rect.size.x * 0.43)
	return Rect2(rect.end - Vector2(width + 18, 94), Vector2(width, 76))

func scroll_by(delta: float) -> void :
	scroll = clampf(scroll + delta, 0, max_scroll)

func action_at(g, point: Vector2) -> String:
	for i in range(g.buttons.size() - 1, -1, -1):
		if g.buttons[i].rect.has_point(point):
			return str(g.buttons[i].action)
	return ""

func paint(g) -> void :
	var d = layout(g.full_rect())
	var entries = items(g.data)
	sync_scroll(entries, d)
	g.paint_target.draw_texture_rect(sprites.logo, d.title, false)
	var subtitle = ["Compre, guarde e escolha quando usar.", "Toque na arte para ver todos os benefícios.", "Visuais e regiões para sua coleção.", "Recompensas de jogo e presente diário."][category]
	g.home_menu.label(g, subtitle, Vector2(d.title.get_center().x, d.title.end.y + 17), 19, g.MINT, true, d.title.size.x + 20)
	g.hub.wallet(g, Rect2(d.wallet.end.x - 405, d.wallet.position.y, 405, 72))
	for i in range(4):
		var rect: Rect2 = d.tabs[i]
		var face = rect
		if g.pressed_button == "market_tab_" + str(i): face.position.y += 2
		if category == i:
			g.home_menu.slab(g, face.grow(2), Color("32203e"), g.GOLD, 14, 3)
		g.paint_target.draw_texture_rect(g.home_menu.panel_texture, face, false, Color.WHITE if category == i else Color(0.68, 0.64, 0.83))
		var at = face.position + Vector2(50, face.size.y * 0.5)
		match i:
			0: g.home_menu.gear(g, at, 23, g.ui_time * 0.08)
			1: g.scenery.sprite(g, g.home_menu.menu_zombie.face, at, 50)
			2: g.scenery.sprite(g, sprites.potion, at, 56)
			3: g.scenery.sprite(g, sprites.church, at, 60)
		g.home_menu.label(g, TITLES[i], Vector2(face.position.x + 89, face.get_center().y + 10), 26, g.GOLD if category == i else g.CREAM, false, face.size.x - 105)
		g.buttons.append({"rect": rect, "action": "market_tab_" + str(i)})
	var back: Rect2 = d.back
	var back_face = back
	if g.pressed_button == "back": back_face.position.y += 2
	g.paint_target.draw_texture_rect(g.home_menu.panel_texture, back_face, false, Color(0.76, 0.7, 0.89))
	var arrow = back_face.position + Vector2(50, back_face.size.y * 0.5)
	g.paint_target.draw_colored_polygon(PackedVector2Array([arrow + Vector2(9, -13), arrow + Vector2(-9, 0), arrow + Vector2(9, 13)]), g.CREAM)
	g.home_menu.label(g, "VOLTAR", back_face.get_center() + Vector2(19, 10), 27, g.CREAM, true, back_face.size.x - 80)
	g.buttons.append({"rect": back, "action": "back"})
	if max_scroll > 0:
		var rail = Rect2(d.grid.end.x + 10, d.grid.position.y + 5, 6, d.grid.size.y - 10)
		g.panel(rail, Color("24162e"), Color("65506f"), 3, 0, false)
		var thumb = maxf(42, rail.size.y * d.grid.size.y / (max_scroll + d.grid.size.y))
		g.panel(Rect2(rail.position + Vector2(0, (rail.size.y - thumb) * scroll / max_scroll), Vector2(6, thumb)), g.MINT, g.MINT, 3, 0, false)
		g.home_menu.label(g, "DESLIZE PARA VER MAIS", Vector2(d.grid.get_center().x, d.grid.end.y + 27), 15, g.MINT, true, d.grid.size.x)


	for i in range(entries.size()):
		var item = entries[i]
		if category == 1:
			var whole = card_rect(i, d)
			var details = Rect2(whole.position + Vector2(12, 12), Vector2(whole.size.x * 0.37, whole.size.y - 28)).intersection(d.grid)
			if details.size.x > 40 and details.size.y > 46: g.buttons.append({"rect": details, "action": "evolution_" + str(item.kind)})
		if bool(item.full) or bool(item.get("locked", false)): continue
		var visible = purchase_rect(card_rect(i, d)).intersection(d.grid)
		if visible.size.x > 40 and visible.size.y >= 46:
			g.buttons.append({"rect": visible, "action": item.action})

func wrapped(g, value: String, point: Vector2, width: float, size: int, lines: int = 3) -> void :
	var font: Font = g.home_menu.label_font
	var line = ""
	var row = 0
	for word in value.split(" "):
		var next = line + " " + word if not line.is_empty() else word
		if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and not line.is_empty():
			g.home_menu.label(g, line, point + Vector2(0, row * (size + 5)), size, g.MINT, false, width)
			row += 1
			if row >= lines: return
			line = word
		else: line = next
	if not line.is_empty() and row < lines:
		g.home_menu.label(g, line, point + Vector2(0, row * (size + 5)), size, g.MINT, false, width)

func gem(g, point: Vector2, filled: bool) -> void :
	var vertices = PackedVector2Array()
	for i in range(6):
		vertices.append(point + Vector2.from_angle( - PI * 0.5 + i * TAU / 6) * 9)
	g.paint_target.draw_colored_polygon(vertices, Color("8d789d"))
	var inner = PackedVector2Array()
	for p in vertices: inner.append(point + (p - point) * 0.72)
	g.paint_target.draw_colored_polygon(inner, Color("65eed5") if filled else Color("362441"))
	if filled:
		g.paint_target.draw_line(point + Vector2(-4, -2), point + Vector2(0, -5), Color("dcfff2"), 2, true)

func illustration(g, item: Dictionary, p: Vector2, height: float) -> void :
	var bob = sin(g.ui_time * 1.7 + int(item.index)) * 1.4
	match item.illustration:
		"object": g.hub.object_icon(g, int(item.index), p, height * 0.7)
		"eye": g.hub.eye(g, p, height * 0.8)
		"grave": g.scenery.sprite(g.paint_target, g.hub.grave_texture, p, height)
		"hat": g.hub.hat(g.paint_target, p, height * 0.90, str(item.key))
		"upgrade":
			if item.index == 0:
				var portrait = g.home_menu.menu_zombie.face
				g.scenery.sprite(g.paint_target, portrait, p + Vector2( - height * 0.2, - height * 0.1), height * 0.66)
				g.scenery.sprite(g.paint_target, portrait, p + Vector2( - height * 0.01, - height * 0.02), height * 0.78)
				g.scenery.sprite(g.paint_target, portrait, p + Vector2(height * 0.19, height * 0.05), height * 0.91)
			else:
				var texture = g.art.items[5] if int(item.index) == 4 else sprites[["", "shoe", "magnet", "potion"][item.index]]
				g.scenery.sprite(g.paint_target, texture, p + Vector2(0, bob), height, Color.WHITE, sin(g.ui_time * 1.2) * 0.016)
		"monster":
			g.actor.paint(g.paint_target, item.kind, p + Vector2(0, height * 0.48), height, g.ui_time * 0.7, "idle", g.ui_time, 0, Color.WHITE, false, 1, false)
		"power":
			g.actor.paint(g.paint_target, item.kind, p + Vector2(0, height * 0.48), height, g.ui_time * 0.7, "fly" if item.kind == 3 else "idle", g.ui_time, 0, Color.WHITE, false, 1, false)
		"area":
			var size = Vector2(height * 1.16, height * 0.68)
			g.panel(Rect2(p - size * 0.5 - Vector2(3, 3), size + Vector2(6, 6)), Color("23182e"), Color("92724d"), 8, 2, false)
			g.paint_target.draw_texture_rect(g.art.world_thumbnails[item.index], Rect2(p - size * 0.5, size), false)
		"power_upgrade":
			g.scenery.sprite(g.paint_target, g.art.rigs[item.kind][0], p - Vector2(7, height * 0.04), height * 0.8)
			var icon = [sprites.shoe, sprites.potion, g.art.items[7], g.art.items[2], sprites.potion, g.art.items[9]][item.index]
			g.scenery.sprite(g.paint_target, icon, p + Vector2(height * 0.25, height * 0.27), height * 0.43)

func purchase(g, item: Dictionary, rect: Rect2) -> void :
	var face = rect
	if g.pressed_button == item.action: face.position.y += 2
	var full = bool(item.full)
	var locked = bool(item.get("locked", false))
	g.paint_target.draw_texture_rect(g.home_menu.play_texture, face, false, Color(0.46, 0.43, 0.57) if full or locked else Color.WHITE)
	if full or locked:
		var state = "BLOQUEADO" if locked else ("NO MÁXIMO" if item.has("level_value") else ("RESGATADO" if item.key == "daily" else "LIBERADO"))
		g.home_menu.label(g, state, face.get_center() + Vector2(0, 8), 19, g.CREAM if locked else g.MINT, true, face.size.x - 30)
		return
	g.scenery.sprite(g.paint_target, g.art.items[1], face.position + Vector2(31, 39), 39)
	var text_center = Vector2(face.get_center().x + 18, face.position.y)
	g.home_menu.label(g, "MELHORAR" if item.has("level_value") and int(item.level_value) > 0 else ("COMPRAR" if category == 0 else "RESGATAR" if item.key == "daily" else "ABRIR" if item.key == "graves" else "EQUIPAR" if item.key == "hat" and int(item.price) == 0 else "LIBERAR"), text_center + Vector2(0, 28), 19, Color("3f211f"), true, face.size.x - 62, false, 1)
	g.home_menu.label(g, str(item.price) if int(item.price) > 0 else "GRÁTIS", text_center + Vector2(0, 59), 30, g.CREAM, true, face.size.x - 65, false, 3)

func paint_rows(g) -> void :
	var d = layout(g.full_rect())
	var entries = items(g.data)
	sync_scroll(entries, d)
	for i in range(entries.size()):
		var item = entries[i]
		var rect = card_rect(i, d)
		if not rect.intersects(d.grid): continue
		g.paint_target.draw_style_box(g.home_menu.panel_style, rect)
		var text_x = rect.position.x + rect.size.x * 0.41
		var text_width = rect.end.x - text_x - 18
		var title_size = int(clampf(rect.size.x * 0.056, 21, 29))
		g.home_menu.label(g, item.name, Vector2(text_x, rect.position.y + 42), title_size, g.CREAM, false, text_width, false, 3)
		wrapped(g, item.description, Vector2(text_x + 1, rect.position.y + 78), text_width - 2, int(clampf(rect.size.x * 0.036, 17, 20)), 3)
		var art_height = clampf(rect.size.x * 0.28, 112, 154)
		illustration(g, item, rect.position + Vector2(rect.size.x * 0.205, rect.size.y * 0.43), art_height)
		var baseline = rect.end.y - 28
		if item.has("level_value"):
			g.home_menu.label(g, "NÍVEL " + str(item.level_value) + " / " + str(item.level_max), Vector2(rect.position.x + 23, baseline), 17, g.MINT, false, 111)
			for j in range(int(item.level_max) if int(item.level_max) <= 6 else 0):
				gem(g, Vector2(rect.position.x + 140 + j * 23, baseline - 6), j < int(item.level_value))
		else:
			g.home_menu.label(g, item.status, Vector2(rect.position.x + 23, baseline), 15, g.MINT, false, rect.size.x * 0.45 - 25)
		purchase(g, item, purchase_rect(rect))

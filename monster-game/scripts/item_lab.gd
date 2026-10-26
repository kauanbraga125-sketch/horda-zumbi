extends RefCounted

# A separate preview context: never equips, purchases or writes player data.
const STATES = ["run", "idle", "rise", "fly", "fall", "landing", "push", "capture", "panic"]
const LABELS = ["CORRIDA", "PARADO", "SUBIDA", "NO AR", "QUEDA", "POUSO", "EMPURRÃO", "CAPTURA", "DANO / PÂNICO"]
const PAGE_SIZE = 6
const SPEEDS = [1.0, 0.5, 0.25]
const ZOOMS = [1.0, 1.5, 2.0]
const PREVIEWS = [Rect2(492, 238, 344, 258), Rect2(860, 238, 344, 258)]

var selected = 0
var filter_kind = -1
var page = 0
var state_index = 0
var cursor = 0.0
var paused = false
var choosing_state = false
var cycle_all = false
var compare = false
var reverse = false
var speed_index = 0
var zoom_index = 0
var clips: Array[Control] = []
var canvases: Array[Node2D] = []
var bounds_cache: Dictionary = {}

func attach(g) -> void:
	for side in range(2):
		var clip = Control.new()
		clip.position = PREVIEWS[side].position
		clip.size = PREVIEWS[side].size
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.z_index = 3
		clip.visible = false
		g.add_child(clip)
		var canvas = Node2D.new()
		clip.add_child(canvas)
		canvas.draw.connect(draw_preview.bind(g, canvas, side))
		clips.append(clip)
		canvases.append(canvas)

func set_visible(visible: bool) -> void:
	for clip in clips: clip.visible = visible

func current() -> Dictionary:
	return HordeCosmeticCatalog.ITEMS[selected]

func entries() -> Array[int]:
	var result: Array[int] = []
	for i in range(HordeCosmeticCatalog.ITEMS.size()):
		if filter_kind < 0 or int(HordeCosmeticCatalog.ITEMS[i].kind) == filter_kind: result.append(i)
	return result

func spec(kind: int = -1, state: int = -1) -> Vector2:
	if kind < 0: kind = int(current().kind)
	if state < 0: state = state_index
	# Number of playable frames and native playback rate for each renderer.
	var zombie = [Vector2(16, 22.4), Vector2(24, 10), Vector2(4, 4.0 / .14), Vector2(6, 10), Vector2(4, 12), Vector2(4, 20), Vector2(8, 14), Vector2(8, 12), Vector2(24, 24)]
	var skeleton = [Vector2(36, 20.16), Vector2(15, 8), Vector2(12, 35), Vector2(6, 9), Vector2(6, 18), Vector2(6, 30), Vector2(36, 20), Vector2(35, 22), Vector2(15, 14)]
	return zombie[state] if kind == 0 else skeleton[state]

func frame() -> int:
	return posmod(int(floor(cursor + .00001)), int(spec().x))

func update(dt: float) -> void:
	if paused or choosing_state: return
	cursor += maxf(0.0,dt)*spec().y*SPEEDS[speed_index]
	while cursor >= spec().x:
		cursor -= spec().x
		if cycle_all: state_index = (state_index+1)%STATES.size()

func sample(kind: int = -1, state: int = -1, index: int = -1) -> Dictionary:
	if kind < 0: kind = int(current().kind)
	if state < 0: state = state_index
	if index < 0: index = frame()
	var rate = spec(kind, state)
	var tick = float(index) + .1
	var pose = {"state": STATES[state], "phase": tick / rate.x, "time": tick / rate.y, "landing": 0.0, "air_age": -1.0, "vertical_speed": 0.0}
	if kind == 1 and state == 0: pose.phase = tick / (36.0 * HordeSkeletonApprovedSprite.RUN_PHASE_SPEED)
	match STATES[state]:
		"rise": pose.air_age = tick * .14 / 4.0 if kind == 0 else tick / 35.0
		"fall": pose.vertical_speed = tick * (150.0 if kind == 0 else 85.0)
		"landing":
			pose.state = "run"
			pose.landing = .2 * (1.0 - tick / rate.x)
	if kind == 0:
		pose.key = "z_run_" + str(index) if state == 0 else "z_other_" + str(HordeZombieSprite.frame_index(pose.state, pose.phase, pose.time, pose.landing, pose.air_age, pose.vertical_speed))
	else:
		var clip = HordeSkeletonApprovedSprite.clip_for(pose.state, pose.landing)
		pose.key = "s_" + clip + "_" + str(HordeSkeletonApprovedSprite.frame_for(pose.state, pose.phase, pose.time, pose.landing, pose.air_age, pose.vertical_speed))
	return pose

func action(g, value: String) -> bool:
	if value == "item_lab_open" and g.screen == "developer":
		g.change_screen("item_lab")
		return true
	if g.screen != "item_lab": return false
	if value == "back":
		if choosing_state:
			choosing_state = false
			return true
		g.change_screen("developer")
		return true
	if not value.begins_with("item_lab_"): return false
	if value.begins_with("item_lab_state_select_"):
		state_index = clampi(int(value.trim_prefix("item_lab_state_select_")),0,STATES.size()-1)
		cursor = 0.0
		cycle_all = false
		choosing_state = false
		paused = false
	elif value.begins_with("item_lab_select_"):
		var id = value.trim_prefix("item_lab_select_")
		for i in range(HordeCosmeticCatalog.ITEMS.size()):
			if HordeCosmeticCatalog.ITEMS[i].id == id:
				selected = i
				cursor = fposmod(cursor, spec().x)
				break
	elif value.begins_with("item_lab_filter_"):
		filter_kind = clampi(int(value.trim_prefix("item_lab_filter_")), -1, 1)
		var list = entries()
		if selected not in list: selected = list[0]
		page = int(list.find(selected) / PAGE_SIZE)
		cursor = fposmod(cursor, spec().x)
	else:
		match value:
			"item_lab_prev", "item_lab_next":
				var pages = ceili(entries().size() / float(PAGE_SIZE))
				page = posmod(page + (-1 if value == "item_lab_prev" else 1), pages)
			"item_lab_state":
				choosing_state = true
			"item_lab_cycle":
				cycle_all = true
				state_index = 0
				cursor = 0.0
				paused = false
				choosing_state = false
			"item_lab_pause": paused = not paused
			"item_lab_frame_prev", "item_lab_frame_next":
				cursor = float(posmod(frame() + (-1 if value == "item_lab_frame_prev" else 1), int(spec().x)))
				paused = true
			"item_lab_compare": compare = not compare
			"item_lab_reverse": reverse = not reverse
			"item_lab_zoom": zoom_index = (zoom_index + 1) % ZOOMS.size()
			"item_lab_speed": speed_index = (speed_index + 1) % SPEEDS.size()
			"item_lab_copy":
				paused = true
				DisplayServer.clipboard_set(report())
				g.show_toast("ITEM E QUADRO COPIADOS. Envie junto com o print.", 3.0)
	return true

func report() -> String:
	var entry = current()
	return "Horda Zumbi v%s\nItem %d/%d: %s\nID: %s\nPersonagem: %s\nAnimação: %s | quadro %d/%d\nSprite: %s\nVista: %s | invertida: %s\nDescreva o ajuste: " % [str(ProjectSettings.get_setting("application/config/version")), selected + 1, HordeCosmeticCatalog.ITEMS.size(), entry.name, entry.id, "Zumbi" if int(entry.kind) == 0 else "Esqueleto", LABELS[state_index], frame() + 1, int(spec().x), sample().key, "comparação sem/com item" if compare else "dois lados", "sim" if reverse else "não"]

func anchor_for(f: Dictionary, pose: Dictionary, kind: int) -> Vector2:
	if kind == 0: return HordeCosmetics.vector(f.anchor)
	var clip = HordeSkeletonApprovedSprite.clip_for(pose.state, pose.landing)
	var index = HordeSkeletonApprovedSprite.frame_for(pose.state, pose.phase, pose.time, pose.landing, pose.air_age, pose.vertical_speed)
	return Vector2(f.anchor[0], HordeSkeletonApprovedSprite.foot_anchor_for(clip, index, pose.landing > 0.0))

func bounds_for(cosmetics: HordeCosmetics) -> Rect2:
	var entry = current()
	if bounds_cache.has(entry.id): return bounds_cache[entry.id]
	cosmetics.ensure_data()
	var graphic: Dictionary = cosmetics.graphics[entry.id]
	var values: Array = graphic.bounds
	var accessory = Rect2(values[0], values[1], values[2], values[3])
	var result = Rect2()
	var first = true
	for state in range(STATES.size()):
		for index in range(int(spec(entry.kind, state).x)):
			var pose = sample(entry.kind, state, index)
			var f: Dictionary = cosmetics.frames[pose.key]
			var body: Array = f.bounds
			var bounds = Rect2(body[0], body[1], body[2], body[3])
			bounds = bounds.merge(cosmetics.posed_bounds(entry.id,f))
			bounds = Rect2((bounds.position - anchor_for(f, pose, entry.kind)) / float(f.height), bounds.size / float(f.height))
			result = bounds if first else result.merge(bounds)
			first = false
	# Accommodate the renderer's breathing, foot lift and small body rotation.
	result = result.grow(.10)
	bounds_cache[entry.id] = result
	return result

func draw_preview(g, canvas: Node2D, side: int) -> void:
	if g.screen != "item_lab": return
	var area = Rect2(Vector2.ZERO, PREVIEWS[side].size)
	canvas.draw_rect(area, Color("1c192a"))
	for x in range(0, int(area.size.x), 32): canvas.draw_line(Vector2(x, 0), Vector2(x, area.size.y), Color(1, 1, 1, .035), 1)
	for y in range(0, int(area.size.y), 32): canvas.draw_line(Vector2(0, y), Vector2(area.size.x, y), Color(1, 1, 1, .035), 1)
	var mirrored = reverse if compare or side == 0 else not reverse
	var bounds = bounds_for(g.actor.cosmetics)
	if mirrored: bounds.position.x = -bounds.end.x
	var height = minf((area.size.x - 24) / bounds.size.x, (area.size.y - 20) / bounds.size.y)
	var center = area.get_center()
	if zoom_index > 0:
		# Focus the enlarged preview on this item's attachment, inside the clip.
		var pose = sample()
		var f: Dictionary = g.actor.cosmetics.frames[pose.key]
		var focus = g.actor.cosmetics.posed_bounds(current().id,f).get_center()
		focus = (focus - anchor_for(f, pose, current().kind)) / float(f.height)
		if mirrored: focus.x *= -1
		bounds.position = bounds.position.lerp(focus - bounds.size * .5, .75)
	height *= ZOOMS[zoom_index]
	var foot = center - bounds.get_center() * height
	canvas.draw_line(Vector2(0, foot.y + 2), Vector2(area.size.x, foot.y + 2), Color("566b67"), 1)
	var pose = sample()
	g.actor.paint(canvas, current().kind, foot, height, pose.phase, pose.state, pose.time, pose.landing, Color.WHITE, mirrored, 1.0, true, pose.air_age, pose.vertical_speed, [] if compare and side == 0 else [current().id])

func paint(g) -> void:
	for clip in clips: clip.visible = not choosing_state
	if choosing_state:
		paint_state_picker(g)
		return
	g.home_menu.label(g, "BANCADA DE ITENS", Vector2(58, 78), 34, g.GOLD, false, -1, true, 4)
	g.text("Revise um acessório por vez, nos dois lados e em cada animação.", Vector2(60, 112), 19, g.CREAM)
	g.button(Rect2(1064, 54, 160, 52), "VOLTAR", "back", Color("513c67"), -2, 21)
	g.panel(Rect2(56, 132, 400, 538), Color("291e38"), Color("785b83"))
	for i in range(3):
		g.button(Rect2(70 + i * 128, 148, 116, 48), ["TODOS", "ZUMBI", "OSSOS"][i], "item_lab_filter_" + str(i - 1), Color("4c786a") if filter_kind == i - 1 else Color("513c67"), -2, 17)
	var list = entries()
	var start = page * PAGE_SIZE
	g.text("%d ACESSÓRIOS  •  %d–%d" % [list.size(), start + 1, mini(start + PAGE_SIZE, list.size())], Vector2(74, 221), 17, g.MINT)
	for row in range(mini(PAGE_SIZE, list.size() - start)):
		var index = list[start + row]
		var entry: Dictionary = HordeCosmeticCatalog.ITEMS[index]
		var label = "%02d  %s" % [index + 1, entry.name]
		var size = 19
		while size > 13 and g.art.title_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > 344: size -= 1
		g.button(Rect2(70, 236 + row * 58, 372, 52), label, "item_lab_select_" + entry.id, Color("4c786a") if selected == index else Color("473550"), -2, size)
	g.button(Rect2(70, 604, 120, 52), "ANTERIOR", "item_lab_prev", Color("513c67"), -2, 16)
	g.text("%d / %d" % [page + 1, ceili(list.size() / float(PAGE_SIZE))], Vector2(256, 637), 21, g.CREAM, false, true)
	g.button(Rect2(322, 604, 120, 52), "PRÓXIMA", "item_lab_next", Color("513c67"), -2, 17)
	g.panel(Rect2(476, 132, 748, 400), Color("291e38"), Color("785b83"))
	g.text(current().name, Vector2(496, 167), 23, g.GOLD)
	g.text("ID: %s  •  %s  •  ITEM %d/%d" % [current().id, "ZUMBI" if int(current().kind) == 0 else "ESQUELETO", selected + 1, HordeCosmeticCatalog.ITEMS.size()], Vector2(496, 196), 16, g.MINT)
	g.button(Rect2(1090, 148, 118, 48), "COPIAR", "item_lab_copy", Color("513c67"), -2, 18)
	for side in range(2):
		var label = ("SEM ITEM" if side == 0 else "COM ITEM") if compare else ("ESQUERDA" if (reverse if side == 0 else not reverse) else "DIREITA")
		g.text(label, Vector2(PREVIEWS[side].get_center().x, 226), 17, g.CREAM, false, true)
		canvases[side].queue_redraw()
	g.text("%s  •  QUADRO %d / %d  •  %s" % [LABELS[state_index], frame() + 1, int(spec().x), "PAUSADO" if paused else ("SEQUÊNCIA" if cycle_all else "REPRODUZINDO")], Vector2(850, 520), 16, g.MINT, false, true)
	g.button(Rect2(476, 548, 230, 54), "ANIMAÇÕES  >", "item_lab_state", Color("4c786a") if cycle_all else Color("513c67"), -2, 20)
	g.button(Rect2(718, 548, 134, 54), "RETOMAR" if paused else "PAUSAR", "item_lab_pause", Color("4c786a"), -2, 18)
	g.button(Rect2(864, 548, 174, 54), "–1 QUADRO", "item_lab_frame_prev", Color("513c67"), -2, 18)
	g.button(Rect2(1050, 548, 174, 54), "+1 QUADRO", "item_lab_frame_next", Color("513c67"), -2, 18)
	g.button(Rect2(476, 616, 220, 54), "MODO: COMPARAR" if compare else "MODO: DOIS LADOS", "item_lab_compare", Color("4c786a"), -2, 17)
	g.button(Rect2(708, 616, 154, 54), "INVERTER", "item_lab_reverse", Color("513c67"), -2, 18)
	g.button(Rect2(874, 616, 154, 54), "ZOOM: %sx" % str(ZOOMS[zoom_index]), "item_lab_zoom", Color("513c67"), -2, 18)
	g.button(Rect2(1040, 616, 184, 54), "VELOC.: %sx" % str(SPEEDS[speed_index]), "item_lab_speed", Color("513c67"), -2, 18)
	g.text("Itens liberados só no teste. Sua coleção e seu progresso são preservados.", Vector2(60, 703), 17, g.MINT)

func paint_state_picker(g) -> void:
	g.home_menu.label(g,"ANIMAÇÕES DO ITEM",Vector2(70,95),36,g.GOLD,false,-1,true,4)
	g.text(current().name,Vector2(72,133),22,g.CREAM)
	g.text("Escolha uma animação. Você também pode ver todas em sequência.",Vector2(72,166),18,g.MINT)
	for i in range(STATES.size()):
		var rect = Rect2(70+(i%3)*386,197+int(i/3)*100,369,82)
		g.button(rect,LABELS[i],"item_lab_state_select_"+str(i),Color("4c786a") if state_index==i and not cycle_all else Color("513c67"),-2,24)
		g.text("%d QUADROS"%int(spec(-1,i).x),Vector2(rect.get_center().x,rect.end.y-9),13,g.MINT,false,true)
	g.button(Rect2(70,550,755,62),"REPRODUZIR TODAS EM SEQUÊNCIA","item_lab_cycle",Color("4c786a"),-2,23)
	g.button(Rect2(842,550,369,62),"VOLTAR AO ITEM","back",Color("513c67"),-2,22)
	g.text("Pausa, quadro a quadro, zoom, velocidade e comparação continuam na bancada.",Vector2(72,663),18,g.MINT)

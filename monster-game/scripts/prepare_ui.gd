extends RefCounted

# The preparation is a moving view of the game, without advancing a real run.
# Never start/advance this runner: those methods generate encounters and rewards.
const CAMERA_MULTIPLIER = 1.12
const PAGE_SIZE = 5
const ORDER = ["coin_magnet","power_harvester","power_spectral","civil_pack", "coin_bombs", "coin_cars", "double_coins", "double_horde",
	"bonus_time", "power_fly", "power_mask", "power_shield", "power_boost"]
const TITLES = {"coin_magnet":"ÍMÃ NESTA PARTIDA","power_harvester":"CHAMADO DA COLHEITA","power_spectral":"MANTO DE EMERGÊNCIA","civil_pack":"CIVIS EXTRAS", "coin_bombs":"BOMBAS DE OURO", "coin_cars":"SUCATA VALIOSA",
	"double_coins":"MOEDAS EM DOBRO", "double_horde":"HORDA EM DOBRO", "bonus_time":"MAIS 15 SEGUNDOS",
	"power_fly":"MOSCA DE EMERGÊNCIA", "power_mask":"MÁSCARA DE EMERGÊNCIA",
	"power_shield":"PROTEÇÃO DO ALÉM", "power_boost":"ARRANCADA MALDITA"}
var preview = HordeRun.new()
var clock = 0.0
var page = 0
var feedback = preload("res://scripts/prepare_effects.gd").new()
var header_gradient = GradientTexture2D.new()

func _init() -> void:
	preview.terrain.segments.assign([{"start":-INF, "end":INF, "height":0.0, "state":HordeTerrain.State.NORMAL}])
	var fade = Gradient.new()
	fade.colors = PackedColorArray([Color(0.065, 0.025, 0.11, 0.72), Color(0.065, 0.025, 0.11, 0)])
	header_gradient.gradient = fade;header_gradient.width = 1;header_gradient.height = 160
	header_gradient.fill_from = Vector2(0.5, 0);header_gradient.fill_to = Vector2(0.5, 1)

func enter(g, returning: bool = false) -> void:
	feedback.ritual.attach(g)
	if not returning:
		clock = 0.0;preview.world_px = 0.0;page = 0
		feedback.clear()
	sync_horde(g)

static func selected(g, id: String) -> bool:
	return id in g.data.prepared_items

static func initial_count(g) -> int:
	var count = 1 + int(g.data.levels.get("horde", 0))
	return mini(HordeRun.MAX_HORDE, count * (2 if selected(g, "double_horde") else 1))

func camera_zoom(g) -> float:
	var extent = 112.0
	if selected(g, "power_mask") and int(g.data.power_levels.get("mask_size", 0)) > 0: extent *= 1.4
	if selected(g, "power_fly"): extent += 33.0
	# Keep the giant mask upgrade below the cards, with the same ground anchor.
	var safe_top: float = layout(g.full_rect()).cards[0].end.y + 12.0
	return minf(g.CAMERA_BASE_ZOOM * CAMERA_MULTIPLIER, (g.CAMERA_ANCHOR.y - safe_top) / extent)

func sync_horde(g) -> void:
	var count = initial_count(g)
	if preview.members.size() == count: return
	preview.members.clear();preview.cached_active = -1;preview.next_member_id = 0
	for i in range(count):
		preview.add_member(1 if i > 0 and i % 3 == 0 and 1 in g.data.owned else 0, false)

func update(g, dt: float) -> void:
	clock += dt
	var summon = feedback.event_for("double_horde")
	var old_age = float(summon.age) if not summon.is_empty() else -1.0
	feedback.advance(dt)
	if old_age >= 0:
		if old_age < 0.70 and old_age + dt >= 0.70: g.sound.play("soul_capture", -20)
		if old_age < 1.75 and old_age + dt >= 1.75: g.sound.play("land", -22)
	preview.world_px += 305.0 * dt
	sync_horde(g)

func paint_world(g) -> void:
	g.scenery.paint_outside(g.paint_target, preview, clock, 0, g.scenery.view_left, g.scenery.view_right)

func paint_foreground(g) -> void:
	preview.view_left = g.scenery.view_left;preview.view_right = g.scenery.view_right
	g.gameplay_ui.ground(g, preview.world_px, preview)
	sync_horde(g)
	feedback.paint_world(g, self, false)
	var power = 3 if selected(g, "power_fly") else (2 if selected(g, "power_mask") else -1)
	for i in range(preview.members.size() - 1, -1, -1):
		var foot = Vector2(preview.slot_x(i), HordeRun.FLOOR - preview.member_depth(i))
		var kind = power if power >= 0 else int(preview.members[i].kind)
		var height = 112.0
		var duplicate = feedback.event_for("double_horde")
		var pose: Dictionary = feedback.ritual.spawn_pose(duplicate, i)
		if duplicate.is_empty() or i < int(duplicate.old_count): pose = feedback.ritual.reaction_pose(feedback.dominant_event(), i)
		var alpha: float = pose.alpha
		foot += Vector2(pose.offset)
		if power == 2 and int(g.data.power_levels.get("mask_size", 0)) > 0: height *= 1.4
		if power == 3: foot.y -= 30.0 + sin(clock * 7.0 + i) * 3.0
		g.paint_target.draw_set_transform(Vector2(foot.x, HordeRun.FLOOR + 4), 0, Vector2(23, 4))
		g.paint_target.draw_circle(Vector2.ZERO, 1, Color(0.02, 0.01, 0.05, 0.28 * alpha))
		g.paint_target.draw_set_transform(Vector2.ZERO)
		if selected(g, "power_shield"):
			var radius = height * (0.57 + sin(clock * 2.5 + i) * 0.012) * feedback.appearance("power_shield", 0)
			g.paint_target.draw_circle(foot - Vector2(0, height * 0.5), radius, Color(0.3, 0.8, 1, 0.035))
			g.paint_target.draw_arc(foot - Vector2(0, height * 0.5), radius, 0, TAU, 48, Color(0.5, 0.9, 1, 0.45 * alpha), 2.5, true)
		var transform_blend = feedback.appearance("power_fly" if power == 3 else "power_mask", i) if power >= 0 else 1.0
		if transform_blend < 1.0:
			g.actor.paint(g.paint_target, int(preview.members[i].kind), Vector2(foot.x, HordeRun.FLOOR), 112, clock * 1.35 + i * 0.19, "run", clock, 0, Color(1, 1, 1, alpha * (1.0 - transform_blend)))
		var tint = feedback.character_tint(i);tint.a = alpha * transform_blend
		var state: String = "fly" if power == 3 else str(pose.state)
		if float(pose.echo) > 0:
			for side in [-1, 1]:
				g.actor.paint(g.paint_target, kind, foot + Vector2(side * 6 * (1.0 - alpha), 0), height, clock * 1.35 + i * 0.19, state, clock, float(pose.landing), Color(0.43, 1, 0.76, float(pose.echo) * transform_blend), false, 1.0, true, float(pose.air_age), float(pose.speed))
		g.actor.paint(g.paint_target, kind, foot, height, clock * 1.35 + i * 0.19, state, clock + i * 0.071, float(pose.landing), tint, false, 1.0, true, float(pose.air_age), float(pose.speed))
		if i == 0 and kind == 0 and not str(g.data.equipped_hat).is_empty():
			g.hub.hat(g.paint_target, foot - Vector2(0, height * 0.9), height * 0.64, str(g.data.equipped_hat))
	feedback.paint_world(g, self, true)

func configure_layers(g) -> void:
	feedback.ritual.configure(g, self)

static func layout(view: Rect2) -> Dictionary:
	var margin = minf(100.0, view.size.x * 0.07)
	var gap = 12.0
	var width = (view.size.x - margin * 2 - gap * 4) / PAGE_SIZE
	var cards: Array[Rect2] = []
	for i in range(PAGE_SIZE):
		cards.append(Rect2(view.position + Vector2(margin + i * (width + gap), 166), Vector2(width, 211)))
	var footer = HordeProfileUI.footer_layout(view)
	footer[1] = Rect2(view.end.x - 60 - footer[2].size.x - 24 - minf(240, view.size.x * 0.23), view.end.y - 78, minf(240, view.size.x * 0.23), 58)
	return {"cards":cards, "previous":Rect2(cards[0].position + Vector2(-50, 73), Vector2(40, 64)),
		"next":Rect2(cards[-1].end.x + 10, cards[-1].position.y + 73, 40, 64), "footer":footer}

func paint(g) -> void:
	var view: Rect2 = g.full_rect()
	var d = layout(view)
	# A short gradient keeps the title readable while leaving the game view open.
	g.paint_target.draw_texture_rect(header_gradient, Rect2(view.position, Vector2(view.size.x, 160)), false)
	g.hub.label(g, "PREPARAR A HORDA", view.position + Vector2(60, 70), 39, g.GOLD, false, view.size.x - 480)
	g.hub.label(g, "Toque para usar. O bônus fica ativado para a próxima partida.", view.position + Vector2(60, 117), 20, g.MINT, false, view.size.x - 120)
	g.hub.wallet(g, Rect2(view.end.x - 430, view.position.y + 24, 370, 62))
	var badge_width = minf(235, view.size.x * 0.185)
	var badge = Rect2(view.position + Vector2(view.size.x * 0.48 - badge_width * 0.5, 26), Vector2(badge_width, 56))
	# On narrower displays the horde badge sits below the subtitle.
	if view.size.x < 1450: badge = Rect2(view.get_center().x - 109, view.position.y + 130, 218, 28)
	g.home_menu.slab(g, badge, Color("21172e"), Color("9c7a53"), 9, 2)
	g.hub.label(g, "HORDA INICIAL  ×" + str(initial_count(g)), Vector2(badge.get_center().x, badge.get_center().y + 7), 18, g.GOLD, true, badge.size.x - 12)
	for i in range(PAGE_SIZE):
		if page * PAGE_SIZE + i >= ORDER.size(): continue
		var id: String = ORDER[page * PAGE_SIZE + i]
		var item: Dictionary = HordeMeta.OBJECTS.filter(func(entry): return entry.id == id)[0]
		var box: Rect2 = d.cards[i]
		var active = selected(g, id)
		var stock = int(g.data.stock.get(id, 0))
		var blocked = id in ["power_fly", "power_mask"] and not active and (selected(g, "power_fly") or selected(g, "power_mask"))
		if id in ["power_harvester","power_spectral"] and not active and (selected(g,"power_harvester") or selected(g,"power_spectral")): blocked = true
		g.paint_target.draw_style_box(g.hub.profile_ui.featured if active else g.hub.profile_ui.panel, box)
		g.hub.object_icon(g, int(item.icon), Vector2(box.get_center().x, box.position.y + 84 + sin(clock * 2.2 + i) * (2 if stock > 0 else 0)), minf(99, box.size.x * 0.62))
		g.pages.lines(g, TITLES[id], Rect2(box.position + Vector2(12, 126), Vector2(box.size.x - 24, 45)), 17, g.CREAM, true, 2)
		if (stock <= 0 or blocked) and not active: g.paint_target.draw_rect(box.grow(-10), Color(0.085, 0.04, 0.12, 0.32))
		g.hub.label(g, "×" + str(stock), Vector2(box.get_center().x, box.end.y - 18), 29, g.GOLD if stock > 0 else Color("b5a6bd"), true, box.size.x - 20)
		if active:
			var tag = Rect2(box.position + Vector2(14, 9), Vector2(box.size.x - 28, 24))
			g.home_menu.slab(g, tag, Color("315b46"), g.MINT, 6, 1)
			g.hub.label(g, "ATIVADO", Vector2(tag.get_center().x, tag.end.y - 6), 12, g.MINT, true, tag.size.x - 8)
			var event = feedback.event_for(id)
			if not event.is_empty(): g.paint_target.draw_rect(box.grow(-6), Color(1, 0.85, 0.4, maxf(0, 1.0 - float(event.age)) * 0.7), false, 3)
		elif blocked:
			g.hub.label(g, "PODER JÁ DEFINIDO", Vector2(box.get_center().x, box.position.y + 27), 11, Color("b5a6bd"), true, box.size.x - 28)
		g.buttons.append({"rect":box, "action":"select_object_" + id})
	if page > 0: g.hub.button(g, d.previous, "‹", "prepare_previous")
	if page < ceili(ORDER.size()/float(PAGE_SIZE))-1: g.hub.button(g, d.next, "›", "prepare_next")
	g.hub.label(g, "OBJETOS  " + str(page + 1) + " / " + str(ceili(ORDER.size()/float(PAGE_SIZE))), Vector2(view.get_center().x, view.position.y + 402), 15, g.MINT, true)
	g.hub.button(g, d.footer[0], "VOLTAR", "back")
	g.hub.button(g, d.footer[1], "VER OBJETOS", "objects_open")
	g.hub.button(g, d.footer[2], "COMEÇAR", "commit_play", true)
	var note = Rect2(d.footer[0].end.x + 24, view.end.y - 70, d.footer[1].position.x - d.footer[0].end.x - 48, 48)
	if note.size.x >= 180:
		g.pages.lines(g, "Uso definitivo: 1 unidade ao ativar.", note, 15, g.MINT, true, 2)
	feedback.paint_ui(g, self)

func activate(g, id: String) -> void:
	var old_count = initial_count(g)
	var stock: Dictionary = g.data.stock.duplicate(true)
	var prepared: Array = g.data.prepared_items.duplicate()
	var status = HordeMeta.activate_preparation(g.data, id)
	if status == "activated":
		if not g.save_game():
			g.data.stock = stock;g.data.prepared_items = prepared
			g.sound.play("ui_denied");g.show_toast("NÃO FOI POSSÍVEL SALVAR. TENTE NOVAMENTE.");return
		var slot = ORDER.find(id) % PAGE_SIZE
		var source: Vector2 = layout(g.full_rect()).cards[slot].get_center() - Vector2(0, 22)
		feedback.trigger(id, source, old_count);sync_horde(g)
		g.sound.play("transform_fly" if id == "power_fly" else ("transform_mask" if id == "power_mask" else "perk"), -18)
	else:
		g.sound.play("ui_denied")
		g.show_toast("JÁ ATIVADO PARA A PRÓXIMA PARTIDA." if status == "active" else ("A TRANSFORMAÇÃO DESTA PARTIDA JÁ FOI ATIVADA." if status == "conflict" else "SEM ESTOQUE. TOQUE EM VER OBJETOS PARA COMPRAR."))

func action(g, value: String) -> bool:
	if value not in ["prepare_next", "prepare_previous"]: return false
	if g.screen == "prepare":
		page = clampi(page + (1 if value == "prepare_next" else -1), 0, ceili(ORDER.size() / float(PAGE_SIZE)) - 1)
		g.sound.play("ui_confirm")
	return true

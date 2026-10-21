class_name HordeProfileUI
extends RefCounted

const ROOT = "res://assets/art/profile_v104/"
const CAUSES = [
	["fall", "BURACOS E QUEDAS"], ["camera", "FICOU PARA TRÁS"],
	["air_bomb", "BOMBAS AÉREAS"], ["rushing_car", "ATROPELAMENTOS"],
	["bullet", "TIROS DO SOLDADO"], ["rocket_explosion", "FOGUETES DO SOLDADO"],
	["bomb", "BOMBAS NO CHÃO"], ["helicopter", "HELICÓPTEROS"],
	["spikes", "ESPINHOS"], ["crate", "CAIXAS"],
	["hump", "LOMBADAS"], ["vehicle", "COLISÕES COM VEÍCULOS"],
]
const ALIASES = {"car":"vehicle", "truck":"vehicle", "bus":"vehicle", "tank":"vehicle", "plane":"vehicle", "moto":"vehicle", "gap":"fall", "collapse":"fall"}
var icons: Dictionary = {}
var panel: StyleBoxTexture
var featured: StyleBoxTexture

func _init() -> void:
	panel = style("panel.png")
	featured = style("featured.png")
	for id in ["record", "distance", "runs", "souls", "horde", "coins", "vehicles", "tunnels", "time"]:
		icons["profile_" + id] = load(ROOT + "profile_" + id + ".png")
	for entry in CAUSES: icons["loss_" + entry[0]] = load(ROOT + "loss_" + entry[0] + ".png")

func style(file: String) -> StyleBoxTexture:
	var box = StyleBoxTexture.new()
	box.texture = load(ROOT + file)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: box.set_texture_margin(side, 26.0)
	return box

static func count_text(value) -> String:
	return str(maxi(0, int(value)))

static func loss_entries(raw: Dictionary) -> Array[Dictionary]:
	var counts = {}
	for entry in CAUSES: counts[entry[0]] = 0
	var other = 0
	for key in raw:
		var id = str(ALIASES.get(str(key), str(key)))
		var amount = maxi(0, int(raw[key]))
		if counts.has(id): counts[id] += amount
		else: other += amount
	var result: Array[Dictionary] = []
	for entry in CAUSES:
		result.append({"id":entry[0], "title":entry[1], "count":counts[entry[0]]})
	# Preserve totals from older saves, including their generic 'impact' entry.
	if other > 0: result.append({"id":"other", "title":"OUTRAS PERDAS", "count":other})
	return result

static func overview_layout(body: Rect2) -> Dictionary:
	var gap = 12.0
	var hero = Rect2(body.position, Vector2(body.size.x * 0.27, body.size.y))
	var start = hero.end.x + gap
	var size = Vector2((body.end.x - start - gap * 3) / 4, (body.size.y - gap) / 2)
	var cards: Array[Rect2] = []
	for i in range(8): cards.append(Rect2(Vector2(start + (i % 4) * (size.x + gap), body.position.y + int(i / 4) * (size.y + gap)), size))
	return {"hero":hero, "cards":cards}

static func losses_layout(body: Rect2, count: int = 12) -> Dictionary:
	var gap = 10.0
	var summary = Rect2(body.position + Vector2(body.size.x * 0.12, 0), Vector2(body.size.x * 0.76, 55))
	var rows = ceili(count / 4.0)
	var size = Vector2((body.size.x - gap * 3) / 4.0, (body.size.y - 79.0 - gap * (rows - 1)) / rows)
	var cards: Array[Rect2] = []
	for i in range(count): cards.append(Rect2(body.position + Vector2((i % 4) * (size.x + gap), 65 + int(i / 4) * (size.y + gap)), size))
	return {"summary":summary, "cards":cards}

static func footer_layout(view: Rect2) -> Array[Rect2]:
	var left = view.position.x + 60
	var width = view.size.x - 120
	var back_width = minf(225, width * 0.22)
	var middle_width = minf(290, width * 0.31)
	var right_width = minf(300, width * 0.32)
	return [Rect2(left, view.end.y - 78, back_width, 58),
		Rect2(view.get_center().x - middle_width * 0.5, view.end.y - 78, middle_width, 58),
		Rect2(view.end.x - 60 - right_width, view.end.y - 82, right_width, 66)]

func icon(g, id: String, box: Rect2) -> void:
	var texture = icons.get(id) as Texture2D
	if texture == null: return
	var size = texture.get_size() * minf(box.size.x / texture.get_width(), box.size.y / texture.get_height())
	g.paint_target.draw_texture_rect(texture, Rect2(box.get_center() - size * 0.5, size), false)

func paint(g, page: int) -> void:
	var body: Rect2 = g.hub.frame(g, "PERDAS DA HORDA" if page == 1 else "PERFIL DA HORDA",
		"Monstros perdidos por tipo de perigo." if page == 1 else "Seu recorde é medido pelas almas capturadas em uma única partida.")
	if page == 1: losses(g, body)
	else: overview(g, body)
	var buttons = footer_layout(g.full_rect())
	g.hub.button(g, buttons[0], "VOLTAR", "back")
	g.hub.button(g, buttons[1], "VISÃO GERAL" if page == 1 else "PERDAS POR CAUSA", "causes_open")
	g.hub.button(g, buttons[2], "COPIAR RECORDE", "share_score", true)

func overview(g, body: Rect2) -> void:
	var d = overview_layout(body)
	var hero: Rect2 = d.hero
	g.paint_target.draw_style_box(featured, hero)
	g.pages.lines(g, "MELHOR PARTIDA", Rect2(hero.position + Vector2(18, 19), Vector2(hero.size.x - 36, 42)), 26, g.MINT)
	icon(g, "profile_record", Rect2(hero.position + Vector2(24, 65), Vector2(hero.size.x - 48, hero.size.y * 0.48)))
	var number_y = hero.position.y + hero.size.y * 0.76
	g.home_menu.label(g, count_text(g.data.best_souls), Vector2(hero.get_center().x, number_y), 82, g.GOLD, true, hero.size.x - 40, true, 3)
	g.home_menu.label(g, "ALMAS", Vector2(hero.get_center().x, number_y + 38), 35, g.GOLD, true, hero.size.x - 40, true, 2)
	g.pages.lines(g, "RECORDE EM UMA PARTIDA", Rect2(hero.position.x + 22, hero.end.y - 48, hero.size.x - 44, 32), 16, Color("e5b0ff"))
	var values = [
		["distance", "DISTÂNCIA RECORDE", count_text(g.data.best) + " m"],
		["runs", "PARTIDAS", count_text(g.data.runs)],
		["souls", "ALMAS CAPTURADAS", count_text(g.data.total_souls)],
		["horde", "MAIOR HORDA", count_text(g.data.lifetime.get("horde", 1))],
		["coins", "MOEDAS RECOLHIDAS", count_text(g.data.lifetime.get("coins", 0))],
		["vehicles", "VEÍCULOS VIRADOS", count_text(g.data.lifetime.get("cars", 0))],
		["tunnels", "TÚNEIS ATRAVESSADOS", count_text(g.data.lifetime.get("tunnels", 0))],
		["time", "TEMPO JOGADO", str(floori(float(g.data.lifetime.get("seconds", 0)) / 60.0)) + " MIN"],
	]
	for i in range(values.size()):
		var box: Rect2 = d.cards[i]
		g.paint_target.draw_style_box(panel, box)
		g.pages.lines(g, values[i][1], Rect2(box.position + Vector2(13, 13), Vector2(box.size.x - 26, 40)), 19, g.MINT)
		icon(g, "profile_" + values[i][0], Rect2(box.position + Vector2(15, 51), Vector2(box.size.x - 30, box.size.y - 101)))
		g.home_menu.label(g, values[i][2], Vector2(box.get_center().x, box.end.y - 17), 39, g.GOLD, true, box.size.x - 32, true, 2)

func losses(g, body: Rect2) -> void:
	var entries = loss_entries(g.data.death_causes)
	var d = losses_layout(body, entries.size())
	var summary: Rect2 = d.summary
	var total = 0
	var biggest = {"title":"NENHUMA PERDA", "count":0}
	for entry in entries:
		total += int(entry.count)
		if int(entry.count) > int(biggest.count): biggest = entry
	g.paint_target.draw_style_box(panel, summary)
	icon(g, "profile_souls", Rect2(summary.position + Vector2(13, 2), Vector2(52, 51)))
	g.home_menu.label(g, "TOTAL DE PERDAS", summary.position + Vector2(72, 34), 18, g.MINT, false, summary.size.x * 0.28)
	g.home_menu.label(g, count_text(total), Vector2(summary.position.x + summary.size.x * 0.42, summary.position.y + 40), 39, g.GOLD, true, summary.size.x * 0.13, true, 2)
	g.pages.lines(g, "MAIOR CAUSA: " + str(biggest.title), Rect2(summary.position.x + summary.size.x * 0.51, summary.position.y + 8, summary.size.x * 0.46, 38), 18, g.GOLD)
	for i in range(entries.size()):
		var entry = entries[i]
		var box: Rect2 = d.cards[i]
		g.paint_target.draw_style_box(panel, box)
		g.pages.lines(g, entry.title, Rect2(box.position + Vector2(12, 10), Vector2(box.size.x - 24, 35)), 20, g.MINT)
		icon(g, "loss_" + ("fall" if entry.id == "other" else str(entry.id)), Rect2(box.position + Vector2(12, 36), Vector2(box.size.x * 0.7 - 12, box.size.y - 42)))
		g.home_menu.label(g, count_text(entry.count), Vector2(box.position.x + box.size.x * 0.83, box.position.y + box.size.y * 0.77), 45, g.GOLD, true, box.size.x * 0.26, true, 2)
	g.home_menu.label(g, "Quedas incluem buracos e chão que cede.", Vector2(body.get_center().x, body.end.y + 3), 14, Color("d8bedf"), true, body.size.x)

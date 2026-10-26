class_name HordeMeta
extends RefCounted
const EYE_RUN_CHANCE = 1.0 / 45.0
const ALTAR_TARGET = 100
const RELIC_LEVELS = [10, 25, 50, 75]
const SEAL_LEVELS = [100, 125, 150]
const RELIC_NAMES = ["DENTE INFECTADO", "MÁSCARA RACHADA", "CRÂNIO MALDITO", "CORAÇÃO DA HORDA"]
const EXPERIMENTS = ["SORO DO ACAMPAMENTO 13", "PLASMA DA FITA PERDIDA", "EXTRATO DO PORÃO", "ESSÊNCIA DO HOSPEDEIRO"]
const COSMETICS = HordeCosmeticCatalog.ITEMS
const OBJECTS = [
	{"id":"coin_magnet","name":"ÍMÃ DE EXPEDIÇÃO","price":220,"icon":10,"description":"Atrai moedas só nesta partida. Compre e escolha antes de jogar."},
	{"id":"power_harvester","name":"CHAMADO DA COLHEITA","price":400,"icon":11,"description":"Inicie uma partida com o caçador alado trazendo civis."},
	{"id":"power_spectral","name":"MANTO DE EMERGÊNCIA","price":350,"icon":12,"description":"Comece com duas proteções do espectro. Buracos continuam perigosos."},
	{"id": "coin_bombs", "name": "BOMBAS DE OURO", "price": 180, "icon": 0, "description": "25% das bombas terrestres viram 12 moedas nesta partida."},
	{"id": "coin_cars", "name": "SUCATA VALIOSA", "price": 220, "icon": 1, "description": "25% dos veículos virados dão 25 moedas extras. Mantém passageiros e almas."},
	{"id": "bonus_time", "name": "MAIS 15 SEGUNDOS", "price": 260, "icon": 2, "description": "+15 s em cada transformação desta partida."},
	{"id": "double_horde", "name": "HORDA EM DOBRO", "price": 200, "icon": 3, "description": "Dobra apenas a horda inicial. Não duplica capturas."},
	{"id": "civil_pack", "name": "ENCONTRO MARCADO", "price": 150, "icon": 4, "description": "Grupo de 3 civis no começo, em terreno seguro."},
	{"id": "double_coins", "name": "NOITE DOURADA", "price": 300, "icon": 5, "description": "Dobra moedas coletadas na partida. Com Frenesi, vale x4."},
	{"id": "power_fly", "name": "MOSCA DE EMERGÊNCIA", "price": 400, "icon": 6, "description": "Transformação da Mosca no início. Escolha uma transformação inicial."},
	{"id": "power_mask", "name": "MÁSCARA DE EMERGÊNCIA", "price": 450, "icon": 7, "description": "Transformação do Mascarado no início. Escolha uma transformação inicial."},
	{"id": "power_shield", "name": "PROTEÇÃO DO ALÉM", "price": 180, "icon": 8, "description": "Comece com um escudo. Absorve um impacto."},
	{"id": "power_boost", "name": "ARRANCADA MALDITA", "price": 240, "icon": 9, "description": "Comece com um impulso. Usa suas melhorias de Frenesi."}
]

static func defaults() -> Dictionary:
	return {"codex_section":0, "codex_spread":0, "codex_seen":{}, "eyes": 0, "stock": {}, "prepared_items": [], "altar_souls": 0, "graves": [], "grave_serial": 0, "daily_claim_at": 0,
		"dose_reset_at": 0, "doses": 3, "level_rewards": [], "lifetime": {}, "death_causes": {},
		"book_name": "", "book_signature": [], "book_signed_at": "", "cosmetics": [], "active_cosmetics": [], "equipped_hat": ""}

static func migrate(result: Dictionary, raw: Dictionary) -> void:
	for key in defaults(): result[key] = raw.get(key, defaults()[key])
	for key in ["eyes", "altar_souls", "daily_claim_at", "dose_reset_at", "grave_serial"]: result[key] = clampi(int(result[key]), 0, 2147483647)
	result.codex_section = clampi(int(result.codex_section),0,3)
	result.codex_spread = clampi(int(result.codex_spread),0,100)
	var seen: Dictionary = {}
	if result.codex_seen is Dictionary:
		for key in result.codex_seen.keys().slice(0,128):
			if key is String and not key.is_empty() and result.codex_seen[key] is bool and result.codex_seen[key]: seen[key.left(64)] = true
	result.codex_seen = seen
	result.eyes = mini(9999999, result.eyes);result.altar_souls = posmod(result.altar_souls, 100)
	result.doses = clampi(int(result.doses), 0, 3)
	for key in ["stock", "lifetime", "death_causes"]:
		if not result[key] is Dictionary: result[key] = {}
	for item in OBJECTS: result.stock[item.id] = clampi(int(result.stock.get(item.id, 0)), 0, 9999)
	var prepared: Array = []
	if result.prepared_items is Array:
		for id in result.prepared_items.slice(0, 64):
			if not id is String or id in prepared: continue
			if id in ["power_fly", "power_mask"] and ("power_fly" in prepared or "power_mask" in prepared): continue
			for item in OBJECTS:
				if item.id == id: prepared.append(id);break
	result.prepared_items = prepared
	for key in ["graves", "level_rewards", "book_signature", "cosmetics", "active_cosmetics"]:
		if not result[key] is Array: result[key] = []
	var valid_owned: Array = []
	for id in result.cosmetics:
		if id is String and not HordeCosmetics.item(id).is_empty() and id not in valid_owned: valid_owned.append(id)
	result.cosmetics = valid_owned
	var valid_active: Array = []
	for id in result.active_cosmetics:
		if id in valid_owned and id not in valid_active: valid_active.append(id)
	if not raw.has("active_cosmetics") and str(result.equipped_hat) in valid_owned: valid_active.append(str(result.equipped_hat))
	result.active_cosmetics = valid_active
	var pairs: Array = []
	for pair in result.graves.slice(0, 500):
		if not pair is Dictionary or not pair.get("rewards", null) is Array or pair.rewards.size() != 2: continue
		if not pair.get("clean", null) is Array or pair.clean.size() != 2 or not pair.get("claimed", null) is Array or pair.claimed.size() != 2: continue
		var safe = {"id": maxi(0, int(pair.get("id", 0))), "rewards": [], "clean": [[], []], "claimed": [false, false], "started": bool(pair.get("started", false))}
		for side in range(2):
			var reward = pair.rewards[side]
			if not reward is Dictionary or str(reward.get("type", "")) not in ["empty", "coins", "eyes", "object", "cosmetic"]: reward = {"type": "empty", "label": "DESCANSE EM PAZ", "amount": 0}
			var normalized = {"type": str(reward.type), "amount": clampi(int(reward.get("amount", 0)), 0, 100000), "label": str(reward.get("label", "DESCANSE EM PAZ")).left(100)}
			if normalized.type in ["object", "cosmetic"]:
				normalized.id = str(reward.get("id", ""))
				var valid = false
				for cosmetic in COSMETICS:
					if normalized.type == "cosmetic" and normalized.id == cosmetic.id: valid = true
				for item in OBJECTS:
					if normalized.type == "object" and normalized.id == item.id: valid = true
				if not valid: normalized = {"type": "empty", "amount": 0, "label": "DESCANSE EM PAZ"}
			safe.rewards.append(normalized)
			if pair.clean[side] is Array:
				for cell in pair.clean[side]:
					if cell is int or cell is float:
						if int(cell) >= 0 and int(cell) < 192 and int(cell) not in safe.clean[side]: safe.clean[side].append(int(cell))
			safe.claimed[side] = bool(pair.claimed[side])
			if safe.claimed[side] or not safe.clean[side].is_empty(): safe.started = true
		pairs.append(safe)
	result.graves = pairs
	var signature: Array = []
	for point in result.book_signature.slice(0, 1200):
		if point is Dictionary and point.has("x") and point.has("y"): signature.append({"x": clampf(float(point.x), 0, 1), "y": clampf(float(point.y), 0, 1), "new": bool(point.get("new", false))})
	result.book_signature = signature
	result.book_name = str(result.book_name).left(24);result.book_signed_at = str(result.book_signed_at).left(40)
	result.equipped_hat = str(result.equipped_hat) if str(result.equipped_hat) in result.cosmetics else ""
	if int(raw.get("version", 6)) < 7:
		var n = int(result.player_level) - 1
		result.level_souls = floori(float(raw.get("level_souls", 0)) / maxf(1, 20 + 12 * n + 4 * n * n) * HordeProgress.level_target(int(result.player_level)))
		result.altar_souls = posmod(int(result.total_souls), 100)
		for level in range(2, int(result.player_level) + 1): result.level_rewards.append(level)
		var legacy_essence = floori(float(raw.get("ritual_progress", 0)) / 100.0 * HordeProgress.level_target(int(result.player_level)))
		if legacy_essence > 0: result.ritual_pending.append({"key":"migration-v100", "title":"Essência preservada", "points":legacy_essence})
		if not result.ritual_pending.is_empty(): result.ritual_ready = true
	result.version = 7

static func buy_object(data: Dictionary, id: String) -> bool:
	for item in OBJECTS:
		if item.id == id and int(data.wallet) >= int(item.price) and int(data.stock.get(id, 0)) < 9999:
			data.wallet -= int(item.price);data.stock[id] = int(data.stock.get(id, 0)) + 1
			return true
	return false

static func activate_preparation(data: Dictionary, id: String) -> String:
	var known = false
	for item in OBJECTS:
		if item.id == id: known = true;break
	if not known: return "unknown"
	if id in data.prepared_items: return "active"
	if id in ["power_fly", "power_mask"] and ("power_fly" in data.prepared_items or "power_mask" in data.prepared_items): return "conflict"
	if int(data.stock.get(id, 0)) <= 0: return "empty"
	data.stock[id] = int(data.stock[id]) - 1
	data.prepared_items.append(id)
	return "activated"

static func prepared_inventory(data: Dictionary) -> Dictionary:
	var active = {}
	for id in data.get("prepared_items", []): active[id] = true
	return active

static func take_prepared_inventory(data: Dictionary) -> Dictionary:
	var active = prepared_inventory(data)
	data.prepared_items.clear()
	return active

static func cosmetic_index(id: String) -> int:
	for i in range(COSMETICS.size()):
		if COSMETICS[i].id == id: return i
	return 0

static func equip_cosmetic(data: Dictionary, id: String) -> bool:
	for item in COSMETICS:
		if item.id != id: continue
		if id not in data.cosmetics:
			var currency = "eyes" if item.currency == "eyes" else "wallet"
			if int(data[currency]) < int(item.price): return false
			data[currency] -= int(item.price);data.cosmetics.append(id)
		if not data.has("active_cosmetics"): data.active_cosmetics = []
		if id in data.active_cosmetics: data.active_cosmetics.erase(id)
		else: data.active_cosmetics.append(id)
		data.equipped_hat = id if item.kind == 0 and item.slot == "head" and id in data.active_cosmetics else ""
		return true
	return false

static func daily_available(data: Dictionary, now: int) -> bool:
	return now >= int(data.daily_claim_at) + 86400

static func claim_daily(data: Dictionary, now: int) -> bool:
	if not daily_available(data, now): return false
	data.daily_claim_at = now;data.eyes = mini(9999999, int(data.eyes) + 5)
	return true

static func mission_points(data: Dictionary, base: int, now: int) -> int:
	if now >= int(data.dose_reset_at) + 86400: data.dose_reset_at = now;data.doses = 3
	if int(data.doses) > 0: data.doses -= 1;return ceili(base * 1.5)
	return base

static func level_eyes(level: int) -> int:
	if level == 2: return 3
	if level % 10 == 0: return mini(50, level)
	return 0

static func reward(rng: RandomNumberGenerator) -> Dictionary:
	var roll = rng.randf()
	if roll < 0.10: return {"type": "empty", "amount": 0, "label": "DESCANSE EM PAZ... TENTE DE NOVO!"}
	if roll < 0.58:
		var amount = [100, 150, 200, 300, 500][rng.randi_range(0, 4)]
		return {"type": "coins", "amount": amount, "label": str(amount) + " MOEDAS"}
	if roll < 0.88:
		var item = OBJECTS[rng.randi_range(0, OBJECTS.size() - 1)]
		return {"type": "object", "id": item.id, "amount": 1, "label": item.name + " x1"}
	if roll < 0.945:
		var amount = rng.randi_range(1, 3)
		return {"type": "eyes", "amount": amount, "label": str(amount) + " OLHOS MALDITOS"}
	if roll < 0.99:
		var available = COSMETICS.filter(func(entry): return entry.currency == "coins")
		var item = available[rng.randi_range(0,available.size()-1)]
		return {"type":"cosmetic","id":item.id,"amount":1,"label":item.name}
	var jackpot = [2000,5000,10000][rng.randi_range(0,2)]
	return {"type":"coins","amount":jackpot,"label":"TESOURO DO COVEIRO! " + str(jackpot) + " MOEDAS"}

static func add_grave_pair(data: Dictionary, rng: RandomNumberGenerator) -> void:
	data.grave_serial += 1
	data.graves.append({"id": data.grave_serial, "rewards": [reward(rng), reward(rng)], "clean": [[], []], "claimed": [false, false], "started": false})

static func claim_grave(data: Dictionary, side: int) -> String:
	if data.graves.is_empty() or side not in [0, 1]: return ""
	var pair: Dictionary = data.graves[0]
	if bool(pair.claimed[side]) or pair.clean[side].size() < 106: return ""
	pair.claimed[side] = true
	var prize: Dictionary = pair.rewards[side]
	match prize.type:
		"coins": data.wallet = mini(9999999, int(data.wallet) + int(prize.amount))
		"eyes": data.eyes = mini(9999999, int(data.eyes) + int(prize.amount))
		"object": data.stock[prize.id] = mini(9999,int(data.stock.get(prize.id, 0)) + maxi(1,int(prize.amount)))
		"cosmetic":
			if prize.id in data.cosmetics: data.wallet += 350;return "JÁ TEM! +350 MOEDAS"
			data.cosmetics.append(prize.id)
	return str(prize.label)

static func sell_graves(data: Dictionary) -> bool:
	if data.graves.is_empty() or bool(data.graves[0].started) or bool(data.graves[0].claimed[0]) or bool(data.graves[0].claimed[1]): return false
	data.graves.pop_front();data.wallet += 180
	return true

static func chain(data: Dictionary, kind: int) -> Dictionary:
	var steps: Array[Dictionary] = []
	var completed = 0
	var benefits: Array[String] = []
	for i in range(MonsterCatalog.POWER_UPGRADES.size()):
		var item: Dictionary = MonsterCatalog.POWER_UPGRADES[i]
		if int(item.kind) != kind: continue
		var value = int(data.power_levels.get(item.id, 0));completed += value
		if value > 0: benefits.append(str(item.name) + " " + str(value))
		for n in range(int(item.max)):
			if n >= value: steps.append({"index": i, "step": n, "name": item.name, "description": item.description, "price": MonsterCatalog.upgrade_cost(item, n)})
	var owned = kind in data.power_owned
	return {"owned": owned, "level": 1 + completed if owned else 0, "next": steps[0] if not steps.is_empty() else {}, "benefits": ", ".join(benefits) if not benefits.is_empty() else "Habilidade básica", "full": owned and steps.is_empty()}

static func relic_count(level: int) -> int:
	var n = 0
	for threshold in RELIC_LEVELS:
		if level >= threshold: n += 1
	return n

static func seals(level: int) -> int:
	var n = 0
	for threshold in SEAL_LEVELS:
		if level >= threshold: n += 1
	return n

extends SceneTree
var checks = 0
var failures = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1;push_error("V113_FAIL " + message)
func _initialize() -> void: call_deferred("run_tests")
func run_tests() -> void:
	check(HordeMeta.COSMETICS.size() == 35, "35 restored cosmetics")
	var premium = HordeMeta.COSMETICS.filter(func(i): return i.currency == "eyes")
	check(premium.size() == 7, "seven exclusive eye purchases")
	var data = MonsterCatalog.defaults();data.wallet = 100000;data.eyes = 1000
	for entry in HordeMeta.COSMETICS:
		var before = int(data.eyes if entry.currency == "eyes" else data.wallet)
		check(HordeMeta.equip_cosmetic(data, entry.id), "purchase " + entry.id)
		check(int(data.eyes if entry.currency == "eyes" else data.wallet) == before - int(entry.price), "correct currency " + entry.id)
		check(entry.id in data.active_cosmetics, "purchase activates " + entry.id)
		var wallet = data.wallet;var eyes = data.eyes
		HordeMeta.equip_cosmetic(data, entry.id);HordeMeta.equip_cosmetic(data, entry.id)
		check(data.wallet == wallet and data.eyes == eyes, "owned toggles are free " + entry.id)
	var random = RandomNumberGenerator.new();random.seed = 113
	for _i in range(6000):
		var reward = HordeMeta.reward(random)
		if reward.type == "cosmetic": check(HordeCosmetics.item(reward.id).currency == "coins", "premium never drops free")
	for kind in [0,1,2,3]:
		var wearing = 0
		for id in range(1200):
			var selected = HordeCosmetics.choose(113,id,kind,data.active_cosmetics)
			check(selected == HordeCosmetics.choose(113,id,kind,data.active_cosmetics), "deterministic assignment")
			var slots = []
			for value in selected:
				var item = HordeCosmetics.item(value)
				check(item.kind == kind and item.slot not in slots, "species and slot exclusion")
				slots.append(item.slot)
			if not selected.is_empty(): wearing += 1
		check(wearing > 600 and wearing < 800 if kind < 2 else wearing == 0, "wear probability or transformation exclusion")
	var legacy = MonsterCatalog.defaults();var raw = legacy.duplicate(true)
	raw.cosmetics = ["bruxa", "unknown", "bruxa"];raw.equipped_hat = "bruxa";raw.erase("active_cosmetics")
	HordeMeta.migrate(legacy,raw)
	check(legacy.cosmetics == ["bruxa"] and legacy.active_cosmetics == ["bruxa"], "migrates legacy ownership and equipped hat")
	var market = HordeMarket.new();market.open(2)
	for filter in range(3):
		market.accessory_filter = filter;var entries = market.items(data)
		check(entries.size() == [19,16,MonsterCatalog.AREAS.size()][filter], "filter count")
		for entry in entries: check(entry.illustration == "area" if filter == 2 else entry.kind == filter, "filtered entries")
	print("V113_COLLECTION checks=",checks," failures=",failures)
	quit(1 if failures else 0)

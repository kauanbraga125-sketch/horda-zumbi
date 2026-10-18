class_name HordeAnalytics
extends RefCounted

# Local playtest telemetry; no server, no account, no network connection.
const SAVE_PATH = "user://horda-analytics.json"
const MAX_RUNS = 60
const MAX_EVENTS = 240
const DETAIL_EVENTS = ["hit", "tunnel_enter", "tunnel_exit", "smash", "perk", "perk_end", "boost", "air_warning", "car_warning", "collapse", "recovery", "surge_warning", "weak_vehicle", "revive", "explosion"]
var history: Array = []
var current: Dictionary = {}
var sample_bucket: int = -1
var end_override: String = ""

func _init() -> void:
	read_history()

func read_history() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary): return
	if parsed.get("runs", null) is Array:
		for item in parsed["runs"]:
			if item is Dictionary: history.append(item)
	while history.size() > MAX_RUNS: history.pop_front()
	if parsed.get("active", null) is Dictionary and not parsed["active"].is_empty():
		var interrupted: Dictionary = parsed["active"]
		interrupted["status"] = "interrupted"
		history.append(interrupted)
		while history.size() > MAX_RUNS: history.pop_front()
		flush()

func begin_run(run: HordeRun, upgrades: Dictionary) -> void:
	if not current.is_empty():
		current["status"] = "interrupted"
		history.append(current)
	current = {
		"id": str(Time.get_unix_time_from_system()) + "-" + str(Time.get_ticks_msec()),
		"date": Time.get_datetime_string_from_system(),
		"version": "0.8.13-mosca-playtest",
		"seed": str(run.run_seed),
		"status": "running",
		"elapsed_seconds": 0.0,
		"distance_m": 0,
		"tunnel": 0,
		"max_horde": run.max_horde,
		"losses": 0,
		"last_cause": "",
		"upgrades": upgrades.duplicate(true),
		"events": [],
		"event_counts": {}
	}
	sample_bucket = -1
	end_override = ""
	flush()

func sample(run: HordeRun) -> void:
	if current.is_empty(): return
	var bucket: int = int(run.elapsed / 5.0)
	if bucket == sample_bucket: return
	sample_bucket = bucket
	var threats: Dictionary = {}
	var danger_right: float = HordeRun.ANCHOR + run.speed * 2.5
	for entity in run.entities:
		if entity.taken or float(entity.x) < HordeRun.ANCHOR or float(entity.x) > danger_right: continue
		var kind: String = str(entity.kind)
		if kind in ["bomb", "air_bomb", "helicopter", "gap", "car", "bus", "truck", "plane", "tank", "bullet", "collapse"]:
			threats[kind] = int(threats.get(kind, 0)) + 1
	append_event({"type": "sample", "t": snappedf(run.elapsed, 0.1), "speed": roundi(run.speed), "horde": run.active_count(), "tunnel": run.tunnel_number(), "threats": threats})
	# Persist active runs periodically so closing the Android app preserves evidence.
	if bucket % 3 == 0: flush()

func record_event(run: HordeRun, event: Dictionary) -> void:
	if current.is_empty(): return
	var kind: String = str(event.get("type", ""))
	if kind.is_empty(): return
	var counts: Dictionary = current["event_counts"]
	counts[kind] = int(counts.get(kind, 0)) + 1
	if kind == "hit": current["last_cause"] = str(event.get("cause", "impact"))
	if kind not in DETAIL_EVENTS: return
	var detail := {"type": kind, "t": snappedf(run.elapsed, 0.01), "distance": run.distance(), "tunnel": run.tunnel_number(), "horde": run.active_count(), "speed": roundi(run.speed)}
	if event.has("cause"): detail["cause"] = str(event["cause"])
	if event.has("kind"): detail["kind"] = str(event["kind"])
	if event.has("object"): detail["object"] = str(event["object"])
	if event.has("rescued_count"): detail["rescued_count"] = int(event["rescued_count"])
	append_event(detail)

func append_event(detail: Dictionary) -> void:
	if current.is_empty(): return
	var items: Array = current["events"]
	items.append(detail)
	while items.size() > MAX_EVENTS: items.pop_front()

func end_run(run: HordeRun) -> void:
	if current.is_empty(): return
	current["status"] = end_override if not end_override.is_empty() else "dead"
	current["elapsed_seconds"] = snappedf(run.elapsed, 0.01)
	current["distance_m"] = run.distance()
	current["tunnel"] = run.tunnel_number()
	current["max_horde"] = run.max_horde
	current["losses"] = run.losses
	current["stats"] = run.stats()
	current["seed"] = str(run.run_seed)
	history.append(current)
	while history.size() > MAX_RUNS: history.pop_front()
	current = {}
	end_override = ""
	flush()

func flush() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"format": "HORDA-ANALYTICS-1", "runs": history, "active": current}))
	file.flush()
	file.close()

func export_report(count: int = 1) -> String:
	var selected: Array = []
	var begin_at: int = maxi(0, history.size() - count)
	for i in range(begin_at, history.size()): selected.append(history[i])
	if not current.is_empty(): selected.append(current)
	return JSON.stringify({"format": "HORDA-ANALYTICS-1", "exported": Time.get_datetime_string_from_system(), "total_saved": history.size(), "runs": selected}, "  ")

func paint(g) -> void:
	g.home_menu.label(g, "DIÁRIO DE PARTIDAS", Vector2(70, 108), 43, g.GOLD, false, -1, true, 5)
	g.home_menu.label(g, "Horda Analytics — salvo no dispositivo, sem internet", Vector2(73, 147), 20, g.MINT, false)
	g.panel(Rect2(68, 170, 1143, 400), Color("2b203c"), Color("826b87"), 19, 2)
	g.home_menu.label(g, "PARTIDAS SALVAS: " + str(history.size()), Vector2(92, 204), 24, g.GOLD, false)
	if history.is_empty():
		g.home_menu.label(g, "Jogue uma partida para começar a coletar dados.", Vector2(95, 282), 23, g.CREAM, false)
	else:
		for i in range(mini(6, history.size())):
			var record: Dictionary = history[history.size() - 1 - i]
			var t: int = roundi(float(record.get("elapsed_seconds", 0.0)))
			var time_text: String = "%02d:%02d" % [int(t / 60), t % 60]
			var description: String = "#%d  %s   %dm   T%d   MAX %d   %s" % [history.size() - i, time_text, int(record.get("distance_m", 0)), int(record.get("tunnel", 0)), int(record.get("max_horde", 0)), str(record.get("last_cause", record.get("status", "")))]
			g.home_menu.label(g, description, Vector2(95, 243 + i * 48), 20, g.CREAM, false, 1080)
	g.button(Rect2(70, 617, 214, 67), "VOLTAR", "analytics_back", Color("58416d"), -2, 23)
	g.button(Rect2(309, 617, 379, 67), "COPIAR ÚLTIMA", "analytics_copy_last", Color("427a72"), -2, 22)
	g.button(Rect2(710, 617, 500, 67), "COPIAR 20 PARTIDAS", "analytics_copy_20", Color("735a92"), -2, 22)

class_name HordeProgress
extends RefCounted
const RITUAL_TARGET = 100

static func level_target(level: int) -> int:
	return 66 + mini(834, maxi(0, level - 1) * 9)

static func board(level: int, progress: int, added: int) -> Dictionary:
	var current = clampi(level, 1, 500)
	var xp = maxi(0, progress) + maxi(0, added)
	while current < 500 and xp >= level_target(current): xp -= level_target(current);current += 1
	return {"level": current, "progress": mini(xp, level_target(current) - 1), "target": level_target(current)}

static func settle(data: Dictionary, souls: int, rng: RandomNumberGenerator) -> Dictionary:
	var report = {"old_level": int(data.player_level), "old_progress": int(data.level_souls), "old_altar": int(data.get("altar_souls", 0)), "souls": maxi(0, souls), "coins": 0, "rewards": [], "levels": 0, "graves": 0}
	data.best_souls = maxi(int(data.best_souls), maxi(0, souls));data.total_souls = mini(9999999, int(data.total_souls) + maxi(0, souls))
	data.altar_souls = int(data.get("altar_souls", 0)) + maxi(0, souls)
	while int(data.altar_souls) >= 100:
		data.altar_souls -= 100;HordeMeta.add_grave_pair(data, rng);report.graves += 1
	data.active_souls = 0;data.ritual_ready = true
	return report

static func queue_mission(data: Dictionary, mission: Dictionary) -> void:
	for item in data.ritual_pending:
		if item.key == mission.key: return
	data.ritual_pending.append({"key": mission.key, "title": mission.title, "points": HordeMeta.mission_points(data, int(mission.ritual), int(Time.get_unix_time_from_system()))})
	data.ritual_ready = true

static func ritual(data: Dictionary, _rng: RandomNumberGenerator) -> Dictionary:
	var result = {"old_progress": int(data.level_souls), "old_level": int(data.player_level), "points": 0, "coins": 0, "bonuses": 0, "eyes": 0, "steps": []}
	if not bool(data.ritual_ready): return result
	for item in data.ritual_pending: result.points += int(item.points)
	data.level_souls += int(result.points)
	while int(data.player_level) < 500 and int(data.level_souls) >= level_target(int(data.player_level)):
		data.level_souls -= level_target(int(data.player_level));data.player_level += 1
		var level = int(data.player_level);var coins = 100 + mini(50, level) * 10
		var before = clampi(int(data.wallet),0,9999999);var eyes_paid = 0
		data.wallet = mini(9999999, int(data.wallet) + coins);coins=int(data.wallet)-before;result.coins += coins;result.bonuses += 1
		if level not in data.level_rewards:
			data.level_rewards.append(level);var eyes = HordeMeta.level_eyes(level)
			var old_eyes = int(data.eyes)
			data.eyes = mini(9999999, int(data.eyes) + eyes);eyes_paid=int(data.eyes)-old_eyes;result.eyes += eyes_paid
		result.steps.append({"level":level,"coins":coins,"eyes":eyes_paid})
	data.level_souls = mini(int(data.level_souls), level_target(int(data.player_level)) - 1)
	data.ritual_progress = int(data.level_souls) % 100;data.ritual_pending.clear();data.ritual_ready = false
	return result

extends SceneTree

var checks = 0
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message);push_error(message)

func course(level: int = 0, count: int = 6):
	var r = HordeRun.new()
	r.start({},130330 + level,0,[0,1],[0,1],[3,4],{"space_time":level})
	while r.members.size() < count: r.add_member(r.members.size() % 2,false)
	r.active_cosmetics = ["s_silver","s_bat","s_goth","s_hourglass","s_punk"]
	return r

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for level in range(4):
		var r = course(level)
		check(r.space.seconds(level) == [30.0,40.0,50.0,60.0][level],"duration level " + str(level))
		r.ensure_tunnels(160000)
		r.world_px = float(r.tunnels[1].entry) + 500
		for i in range(3): r.update_tunnels()
		var before = r.world_px;var previous_tunnel = r.completed_tunnels
		var ids = r.members.map(func(m): return m.id)
		var kinds = r.members.map(func(m): return m.kind)
		var worn = []
		for m in r.members: worn.append(r.cosmetics_for(m,int(m.kind)).duplicate())
		check(r.space.begin(r),"start level " + str(level))
		r.space.next_group = 1000000
		var ticks = 0
		while r.space.active and ticks < 5000:
			r.advance(1.0/60.0, true)
			check(not r.dead and r.members.size() == ids.size(),"party survives level " + str(level))
			check(r.world_px > before,"road advances in space")
			for m in r.members: check(is_finite(float(m.x)) and is_finite(float(m.y)),"finite member pose")
			ticks += 1
		check(not r.space.active,"power returns at level " + str(level))
		check(r.completed_tunnels > previous_tunnel,"real tunnel progress level " + str(level))
		check(r.world_px - before > 14000,"travel covers real world distance")
		check(r.members.map(func(m): return m.id) == ids,"member identities preserved")
		check(r.members.map(func(m): return m.kind) == kinds,"native monsters preserved")
		for i in range(r.members.size()):
			check(r.cosmetics_for(r.members[i],int(r.members[i].kind)) == worn[i],"cosmetics preserved on return")
		check(r.hit_grace > 1.5,"landing protection")
		for i in range(90): r.advance(1.0/60.0,false)
		check(not r.dead and r.members.size() == ids.size(),"safe landing continuation")
		if level == 3: check(r.space.max_altitude >= 3100,"highest upgrade reaches black hole")
	var r = course(1)
	r.perk_left = 8;r.perk_kind = 3
	check(not r.space.begin(r),"space does not stack with transformations")
	r.perk_left = 0;r.perk_kind = -1
	check(r.space.begin(r),"start after power expires")
	r.space.phase = "flight";r.space.phase_age = 0;r.space.next_group = 1000000
	r.space.y = 420
	for i in range(5): r.advance(1.0/60.0,false)
	var lead = r.members[r.leader_index()]
	var centre = Vector2(lead.x,lead.y - 57)
	var party = r.members.size();var time_before = r.space.left
	r.space.add_object("meteor",centre.x,centre.y,{"speed":0.0,"seed":0.0})
	r.advance(1.0/60.0,false)
	check(r.space.left < time_before - 2.4,"meteor costs time")
	check(r.members.size() == party,"meteor preserves party")
	check(r.space.hits == 1,"one impact recorded")
	r.space.add_object("astronaut",centre.x,centre.y,{"speed":0.0,"seed":0.0})
	for i in range(70): r.advance(1.0/60.0,false)
	check(r.souls == 1 and r.recruits == 1,"astronaut rewards once")
	check(r.members.size() == party + 1,"astronaut joins horde")
	var total = r.souls
	for i in range(50): r.advance(1.0/60.0,false)
	check(r.souls == total,"capture does not duplicate")
	r.space.left = 2;r.space.flight_age = 3
	lead = r.members[r.leader_index()];centre = Vector2(lead.x,lead.y - 57)
	r.space.add_object("energy",centre.x,centre.y,{"speed":0.0,"seed":0.0})
	r.advance(1.0/60.0,false)
	check(r.space.left > 3.4,"energy extends remaining flight")
	var pending_capture = course()
	pending_capture.space.begin(pending_capture);pending_capture.space.phase = "flight"
	pending_capture.space.left = 0.04;pending_capture.space.next_group = 1000000
	var capturer = pending_capture.members[pending_capture.leader_index()]
	pending_capture.space.add_object("astronaut",capturer.x,capturer.y - 57,{"speed":0.0,"seed":0.0})
	for i in range(160): pending_capture.advance(1.0/60.0,false)
	check(not pending_capture.space.active and pending_capture.souls == 1,"capture at expiry completes on landing")
	check(int(pending_capture.mission_stats.get("civilians",0)) == 1 and int(pending_capture.mission_stats.get("space_captures",0)) == 1,"last capture advances missions once")
	var early = course()
	early.elapsed = 8
	early.space.offer_test_pickup(early)
	check(early.entities.filter(func(e):return e.kind == "space_brain").size() == 1,"early test pickup offered")
	early.space.offer_test_pickup(early)
	check(early.entities.filter(func(e):return e.kind == "space_brain").size() == 1,"early pickup unique")
	for e in early.entities:
		if e.kind == "space_brain": e.x = early.members[0].x;e.y = early.members[0].y - 48
	early.advance(1.0/60.0,false)
	check(early.space.active,"real collectible activates power")
	# Load the actual game scene, purchases, migration and pause behavior.
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false);game.set_physics_process(false)
	game.data.wallet = 50000
	var old_data = MonsterCatalog.defaults();old_data.power_owned = [3];old_data.power_levels.erase("space_time")
	var migrated = game.validate_save(old_data)
	check(4 in migrated.power_owned and migrated.power_levels.space_time == 0,"old save migration")
	var upgrade_index = -1
	for i in range(MonsterCatalog.POWER_UPGRADES.size()):
		if MonsterCatalog.POWER_UPGRADES[i].id == "space_time": upgrade_index = i
	for level in range(3): check(game.buy_power_upgrade(upgrade_index),"duration purchase " + str(level))
	check(game.data.power_levels.space_time == 3,"duration upgrade stored")
	var money = game.data.wallet
	check(not game.buy_power_upgrade(upgrade_index) and game.data.wallet == money,"max level purchase protected")
	game.market.category = 1
	var card = game.market.items(game.data).filter(func(item):return item.key == "monster_chain_4")
	check(card.size() == 1 and card[0].description.contains("60 s"),"market reflects real duration")
	game.start_lab("space")
	check(game.runner.space.active,"developer launches space")
	var player_data = JSON.stringify(game.data)
	game.perform_action("lab_space_time")
	check(game.runner.space.duration == 40,"developer duration cycling")
	game.perform_action("lab_space_zone")
	check(game.runner.space.altitude >= 850,"developer altitude cycling")
	check(JSON.stringify(game.data) == player_data,"developer preserves player data")
	game.change_screen("pause")
	var frozen_time = game.runner.space.left
	game._physics_process(1)
	check(game.runner.space.left == frozen_time,"pause freezes actual power timer")
	game.change_screen("run");game.runner.advance(.1,false)
	check(game.runner.space.left < frozen_time,"resume continues power timer")
	game.leave_lab();game.sound.set_enabled(false);game.queue_free()
	game = null;r = null;early = null;pending_capture = null
	for i in range(8): await process_frame
	var report = {"version":"0.10.30","checks":checks,"failures":failures,"physical_device_tested":false}
	var path = OS.get_environment("HORDA_VALIDATION_DIR")
	if not path.is_empty():
		DirAccess.make_dir_recursive_absolute(path)
		var f = FileAccess.open(path + "/space-validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
	print("SPACE_INTEGRATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

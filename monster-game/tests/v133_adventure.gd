extends SceneTree
## Real runner tests: world-space input replay, encounters, losses and purchases.
var checks = 0
var failures: Array[String] = []
var observations: Array = []
const STEP = 1.0/60.0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)

func _initialize() -> void: call_deferred("run")

func road(count: int = 4, stage: int = 0):
	var r = HordeRun.new();r.start_developer("gap",count,stage,132042)
	r.developer_kind = "validation";r.next_pattern_world = 1e12;r.tunnels.clear()
	r.power_owned = [2,3,4,5,6,7,8];r.events.clear()
	return r

func flight(count: int = 6):
	var r = road(count);r.space.begin(r,true);r.space.phase = "flight";r.space.phase_age = 0;r.space.next_group = 1e6
	r.space.manual_control = true;r.space.aim_y = 420;r.space.y = 420
	for i in range(30): r.advance(STEP,false)
	r.space.objects.clear();r.events.clear();return r

func ticks(r, total: int, held: bool = false) -> void:
	for i in range(total): r.advance(STEP,held)

func run() -> void:
	for count in [1,4,8,16,24]:
		for stage in [0,4,9]:
			var r = road(count,stage);var speed = r.speed
			var start = r.world_px+HordeRun.ANCHOR
			var gap = r.add_entity("gap",HordeRun.ANCHOR+65,HordeRun.FLOOR,0,speed*.68)
			r.rebuild_surfaces();r.jump()
			var launch_points: Dictionary = {}
			for frame in range(210):
				r.advance(STEP,frame<65)
				for m in r.members:
					if float(m.last_jump_at)>=0 and not launch_points.has(m.id): launch_points[m.id] = r.world_px+float(m.x)
			observations.append({"horde":count,"stage":stage,"speed":speed,"survived":r.active_count(),"launch_points":launch_points.values()})
			if count<=16:
				check(r.active_count()==count,"small horde clears pit %d stage %d survivors %d" % [count,stage,r.active_count()])
				check(launch_points.size()==count,"all members receive jump %d stage %d" % [count,stage])
				for point in launch_points.values(): check(absf(point-start)<speed*STEP+10,"followers use same world launch point")
			check(r.loss_causes.get("camera",0)==0,"no camera loss on canonical pit")
	var small = road(4);check(small.follower_delay(15)==0 and small.follower_delay(20)>.07,"reaction delay begins only in large hordes")
	var first = {};var old = {};HordeBalance.launch(first,0);HordeBalance.launch(old,3)
	check(first.vy==old.vy,"legacy jump level cannot change height")
	small.jump();ticks(small,10,true);var sequence = small.jump_sequence;small.jump()
	check(small.jump_sequence==sequence,"air press does not grant double jump")
	# A released buffered tap must remain a tap after landing.
	var buffer = road(1);buffer.jump();ticks(buffer,18,false)
	for i in range(45):
		if float(buffer.members[0].vy)>0 and float(buffer.members[0].y)>HordeRun.FLOOR-18: break
		buffer.advance(STEP,false)
	buffer.jump();buffer.advance(STEP,false);ticks(buffer,12,false)
	check(buffer.jump_sequence==2,"landing input buffer launches a new jump")
	check(float(buffer.wave_durations.get(2,99))<=.09,"released buffer preserves short hold")
	# A complete formation triggers once; a missed member suppresses it.
	var coins = road();var row = coins.new_coin_row(4)
	for i in range(4): coins.collect_coin_row({"coin_row":row,"x":350,"y":500})
	check(coins.events.filter(func(e):return e.type=="perfect").size()==1,"perfect fires once for entire row")
	coins.collect_coin_row({"coin_row":row,"x":350,"y":500})
	check(coins.events.filter(func(e):return e.type=="perfect").size()==1,"perfect cannot repeat")
	row = coins.new_coin_row(4);coins.miss_coin_row({"coin_row":row})
	for i in range(4): coins.collect_coin_row({"coin_row":row,"x":350,"y":500})
	check(coins.events.filter(func(e):return e.type=="perfect").size()==1,"missed row never gives perfect")
	# One creature, real NPC delivery, and normal capture completes recruitment.
	for level in [0,3]:
		var r = road();r.power_levels.creeper_rate = level;r.power_levels.creeper_time = level;r.blessings.begin(r,5)
		check(is_equal_approx(r.blessings.interval,6.0-level*.75),"bounded helper cadence")
		var drop_times = [];var previous = 0
		for i in range(1900):
			r.advance(STEP,false)
			if r.blessings.deliveries>previous: drop_times.append(r.elapsed);previous = r.blessings.deliveries
		check(drop_times.size()>=3 and drop_times.size()<9,"helper balanced number of passes")
		for i in range(1,drop_times.size()): check(float(drop_times[i])-float(drop_times[i-1])>3.6,"helper passes never overlap")
		check(r.souls==r.blessings.deliveries and r.recruits==r.souls,"every delivered civilian captured exactly once")
		check(r.active_count()==4+r.souls,"helper adds real captures to party")
	var specter = road();specter.blessings.begin(specter,6)
	var capped = road();capped.developer_kind = "";capped.souls = capped.early_soul_limit();var capped_souls = capped.souls
	capped.blessings.begin(capped,5);capped.blessings.drop_civilian(capped)
	check(capped.entities.any(func(e):return e.get("rescued_civil",false) and not e.taken),"helper delivery bypasses ordinary road population budget")
	ticks(capped,120)
	check(capped.souls>capped_souls and capped.active_count()>4,"helper remains useful after road soul limit")
	for i in range(2): specter.hit_grace = 0;specter.damage(0,"bomb")
	check(specter.active_count()==4 and specter.blessings.charges==0,"specter absorbs exactly two impacts")
	specter.hit_grace = 0;specter.damage(0,"bomb");check(specter.active_count()==3,"third impact costs member")
	var pit = road(1);pit.blessings.begin(pit,6);pit.add_entity("gap",0,HordeRun.FLOOR,0,1500);ticks(pit,120)
	check(pit.dead,"spectral power does not protect from pits")
	# Space damage and end conditions use the same actual party.
	var r = flight();var party = r.active_count();var lead = r.members[r.leader_index()]
	r.space.add_object("meteor",lead.x,lead.y-55,{"speed":0.0,"seed":0.0});r.advance(STEP,false)
	check(r.active_count()==party-1 and r.space.hits==1,"meteor removes a real member")
	r.space.battle.give_power(r.space,r,8);party = r.active_count()
	for i in range(3):
		r.space.age += .6;r.hit_grace = 0;r.space.battle.hurt(r.space,r,0,"space_laser",Vector2.ZERO)
	check(r.active_count()==party and r.space.battle.shield_charges==0,"orbital shield has exactly three charges")
	r.space.age += .6;r.hit_grace = 0;r.space.battle.hurt(r.space,r,0,"space_laser",Vector2.ZERO)
	check(r.active_count()==party-1,"shield exhaustion restores danger")
	var doomed = flight(1);doomed.space.battle.hurt(doomed.space,doomed,0,"space_laser",Vector2.ZERO)
	check(doomed.dead and doomed.active_count()==0,"space can end the run")
	var capture = flight();lead = capture.members[capture.leader_index()]
	capture.space.add_object("astronaut",lead.x,lead.y-55,{"speed":0.0,"seed":0.0});ticks(capture,90)
	check(capture.souls==1 and capture.active_count()==7,"astronaut capture recruits once")
	ticks(capture,90);check(capture.souls==1,"astronaut cannot duplicate rewards")
	var dash = flight();check(dash.space.dash(),"space dash activates");check(not dash.space.dash(),"dash cooldown enforced")
	party = dash.active_count();dash.space.battle.hurt(dash.space,dash,0,"space_ship",Vector2.ZERO)
	check(dash.active_count()==party,"dash protects during attack window")
	var fleet = flight(20)
	var families = {}
	for i in range(35):
		fleet.space.altitude = [0.0,1100.0,2150.0,3400.0][int(i/8)%4];fleet.space.battle.spawn(fleet.space,fleet)
		for e in fleet.space.objects: families[e.kind] = true
		fleet.space.objects.clear()
	for family in ["tour_bus","cargo","fighter","saucer","ghost_frigate","meteor","parasite","drone","beam"]: check(families.has(family),"encounter deck contains "+family)
	for family in fleet.space.battle.SHIPS:
		var ship = fleet.space.battle.spawn_ship(fleet.space,fleet,family,650,365)
		fleet.space.battle.hit_ship(fleet.space,fleet,ship,10)
		check(ship.taken,"ship can be destroyed "+family)
	check(fleet.space.battle.pilot_left>0 and fleet.space.battle.pilot_hp==3,"boarding grants timed vulnerable piloting")
	var ascent = flight();ascent.space.charge = 100;ticks(ascent,1)
	check(ascent.space.phase=="boost","full charge starts impulse animation")
	ticks(ascent,80);check(ascent.space.altitude>=1100 and ascent.space.wave_number==2,"impulse reaches next layer")
	for i in range(2): ascent.space.charge = 100;ticks(ascent,90)
	check(ascent.space.zone()==3 and ascent.space.max_altitude>=3100,"successive impulses reach black hole layer")
	# Large party lands safely with its IDs and cosmetics, then resumes the course.
	var landing = flight(41);landing.active_cosmetics = ["s_bat","s_silver","s_goth"]
	var ids = landing.members.map(func(m):return m.id);landing.space.left = .01;ticks(landing,150)
	check(not landing.space.active and not landing.dead and landing.active_count()==41,"41-member reentry lands safely")
	check(landing.members.map(func(m):return m.id)==ids,"reentry preserves party identities")
	check(landing.hit_grace>.2,"reentry protects the next ground seconds")
	# Real UI, migrated saves, ownership, preparation, and sounds.
	var g = load("res://main.tscn").instantiate();root.add_child(g);await process_frame;g.set_process(false);g.set_physics_process(false)
	var legacy = MonsterCatalog.defaults();legacy.erase("balance_v132");legacy.wallet = 123;legacy.best = 8756;legacy.runs = 22;legacy.levels.jump = 3;legacy.levels.magnet = 3;legacy.power_owned = [2,3,4,5,6,7,8]
	var migrated = g.validate_save(legacy)
	check(migrated.wallet==11043 and migrated.levels.jump==0 and migrated.levels.magnet==0,"removed upgrades refunded in full")
	check(g.validate_save(migrated).wallet==migrated.wallet,"refund is idempotent")
	check(migrated.best==8756 and migrated.runs==22 and 8 in migrated.power_owned,"migration preserves progress and new ownership")
	for entry in MonsterCatalog.UPGRADES: check(entry.id not in ["jump","magnet"],"challenge-removing upgrades absent")
	g.data = MonsterCatalog.defaults();g.data.wallet = 100000
	for kind in [5,6,7,8]: check(g.buy_power(kind),"new power purchase "+str(kind))
	check(HordeMeta.buy_object(g.data,"coin_magnet"),"magnet purchased as consumable")
	check(HordeMeta.activate_preparation(g.data,"coin_magnet")=="activated","magnet selected for one run")
	var active = HordeMeta.take_prepared_inventory(g.data);check(active.has("coin_magnet") and not HordeMeta.take_prepared_inventory(g.data).has("coin_magnet"),"magnet consumed by exactly one run")
	for name in ["perfect","space_boost","space_dash","creeper_wing","space_smash"]: check(g.sound.clips.has(name) and g.sound.clips[name].get_length()>.1,"new audible cue "+name)
	g.market.category = 0
	for card in g.market.items(g.data):
		for entry in HordeMeta.OBJECTS:
			if entry.id==card.key: check(int(card.index)==int(entry.icon),"consumable uses its own correct icon "+str(card.key))
	g.data.stock.power_harvester = 1;g.data.stock.power_spectral = 1
	check(HordeMeta.activate_preparation(g.data,"power_harvester")=="activated","helper selected for next run")
	check(HordeMeta.activate_preparation(g.data,"power_spectral")=="conflict" and g.data.stock.power_spectral==1,"support conflict never wastes another consumable")
	var eggs = flight();eggs.space.add_object("egg",900,300,{"speed":0.0});ticks(eggs,165)
	check(eggs.space.objects.any(func(e):return e.kind=="parasite"),"alien nest egg hatches an animated threat")
	g.start_lab("space");g.perform_action("lab_space_power");check(g.runner.space.battle.power_kind==7,"developer can preview space power")
	g.perform_action("lab_space_power");check(g.runner.space.battle.power_kind==8,"developer cycles exclusive powers")
	g.leave_lab();g.sound.set_enabled(false);g.queue_free();g = null
	for i in range(8): await process_frame
	var report = {"version":str(ProjectSettings.get_setting("application/config/version")),"checks":checks,"failures":failures,"ground_cases":observations,"physical_device_tested":false}
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder);var f = FileAccess.open(folder+"/adventure.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("V133_ADVENTURE_INTEGRATION checks=",checks," failures=",failures," version=",report.version);quit(0 if failures.is_empty() else 1)

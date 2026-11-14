extends SceneTree
const Power = preload("res://scripts/ferrugem_power.gd")
const Art = preload("res://scripts/bird_art.gd")
const Catalog = preload("res://scripts/bird_catalog.gd")
var checks = 0
var failures: Array[String] = []
var game
var folder = ""

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:failures.append(message);push_error(message)

func fixture(level: int = 3) -> Dictionary:
	var d = MonsterCatalog.defaults();d.bird_copies = {"ferrugem":level};d.bird_discovered = {"ferrugem":true}
	d.bird_equipped_slots = ["ferrugem",""];d.bird_equipped = "ferrugem";return d

func model(level: int = 3):
	var r = HordeRun.new();r.start_developer("bomb",4,0,175);r.entities.clear();r.events.clear();r.next_pattern_world = 1e12
	r.bird.configure(fixture(level));r.view_right = 1900;return r

func step(r,seconds: float,dt: float = 1.0/60) -> void:
	for i in range(roundi(seconds/dt)):r.bird.advance(r,dt)

func ready(r) -> void:r.bird.ferrugem.until_shot = 0
func vehicle(r,kind: String = "tank",x: float = 1050) -> Dictionary:return r.add_entity(kind,x,r.FLOOR)

func game_step(seconds: float) -> void:
	for i in range(roundi(seconds*30)):
		game._physics_process(1.0/30);game._process(1.0/30);await process_frame

func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game._process(0);await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"Native capture "+name)

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if folder.is_empty():folder = "user://ferrugem-v175"
	DirAccess.make_dir_recursive_absolute(folder)
	for lv in [1,2,3]:
		var r = model(lv);var e = vehicle(r);var p = r.bird.ferrugem
		check(p.until_shot==[60.0,50.0,40.0][lv-1],"Initial recharge is the full interval at level "+str(lv))
		step(r,Power.interval(lv)-.1)
		check(p.shots==0 and not e.taken and p.phase=="idle","No early starter shot at level "+str(lv))
		step(r,1)
		check(p.shots==1 and e.taken and p.until_shot>Power.interval(lv)-1,"First complete shot resets full recharge")
		var second = vehicle(r,"car",1220);step(r,Power.interval(lv)-2)
		check(p.shots==1 and not second.taken,"No second shot before the long recharge ends")
		step(r,3)
		check(p.shots==2 and second.taken,"Second shot after a complete recharge")
	var r = model();ready(r);step(r,5)
	check(r.bird.ferrugem.until_shot==0 and r.bird.ferrugem.phase=="idle","Ready charge is held without a target")
	for kind in ["civilian","coin","gap","collapse","eye","power","pipe","gate"]:r.add_entity(kind,950,r.FLOOR)
	var protected = r.entities.duplicate(true);step(r,1)
	check(r.entities==protected and r.bird.ferrugem.shots==0,"NPCs, currency, terrain and structural gates are untouched")
	var e = vehicle(r);var second = vehicle(r,"bus",1250);var need = e.required_count;var crew = e.passengers.size();var hp_before = r.active_count()
	step(r,1)
	check(e.taken and not second.taken and e.required_count==need and not e.get("bird_weakened",false),"One entire tank destroyed; the adjacent bus and its strength are unchanged")
	check(r.cars==1 and r.coins==MonsterCatalog.VEHICLES.tank.reward and r.souls==crew and r.active_count()==hp_before+crew,"Normal vehicle coins, crew and mission rewards occur once")
	var smash = r.events.filter(func(v):return v.type=="smash")
	check(smash.size()==1 and smash[0].laser_destroyed and smash[0].join_ids.size()==crew,"Existing wreck and passenger presentation is retained")
	step(r,2)
	check(r.cars==1 and r.souls==crew and r.bird.ferrugem.shots==1,"Recovery cannot duplicate destruction or rewards")
	for kind in MonsterCatalog.VEHICLES:
		r = model();e = vehicle(r,kind);ready(r);step(r,1)
		check(e.taken and r.cars==1,"Full destruction also supports "+kind)
	for kind in Power.GROUND:
		r = model();e = r.add_entity(kind,1000,r.FLOOR);ready(r);step(r,1)
		check(e.taken and r.bird.ferrugem.shots==1,"One ground hazard destroyed: "+kind)
	r = model();e = vehicle(r);ready(r);step(r,.1);e.taken = true;step(r,1)
	check(r.bird.ferrugem.shots==0 and r.bird.ferrugem.until_shot==0 and r.cars==0,"A target removed during charging consumes no shot or rewards")
	r = model();e = vehicle(r);ready(r);step(r,.1);r.entities.clear();step(r,1)
	check(not e.taken and r.bird.ferrugem.shots==0,"A detached target is never hit")
	r = model();e = vehicle(r);ready(r);step(r,.1);e.x = 390;step(r,1)
	check(not e.taken and r.bird.ferrugem.shots==0,"An overtaken target is released safely")
	r = model();e = vehicle(r);ready(r);step(r,.1);r.space.active = true;r.space.phase = "ascent";step(r,3)
	check(not e.taken and r.bird.ferrugem.shots==0 and r.bird.ferrugem.until_shot==0,"Covered transitions cancel the lock while retaining charge")
	r = model();step(r,5);var remaining = r.bird.ferrugem.until_shot;r.transform_left = 2;step(r,2)
	check(is_equal_approx(remaining,r.bird.ferrugem.until_shot),"Transformation pauses the power timer")
	r = model();e = vehicle(r);ready(r);step(r,.1);r.dead = true;step(r,60)
	check(not e.taken and r.bird.ferrugem.shots==0,"Death prevents delayed fire")
	for dt in [1.0/15,1.0/30,1.0/60]:
		r = model();e = vehicle(r);ready(r);step(r,2,dt)
		check(e.taken and r.bird.ferrugem.shots==1,"Low frame rate still gives exactly one shot: "+str(dt))
	r = model();r.space.active = true;r.space.phase = "flight"
	e = r.space.battle.spawn_ship(r.space,r,"ghost_frigate",1100,390);var neighbor = r.space.battle.spawn_ship(r.space,r,"cargo",1250,470)
	ready(r);step(r,1)
	check(e.taken and int(e.hp)<=0 and not neighbor.taken and neighbor.hp==3,"One laser destroys all five HP of a frigate without area damage")
	check(r.space.battle.destroyed==1 and r.coins==8 and r.space.objects.filter(func(v):return v.kind=="astronaut").size()==4,"Normal ship wreck, coins and surviving crew are created once")
	for kind in Power.WATER:
		r = model();r.sewer.active = true;r.sewer.phase = "ride"
		e = r.sewer.add_object(kind,1100,420);var pipe = r.sewer.add_object("pipe",950,420);var gate = r.sewer.add_object("gate",960,420)
		ready(r);step(r,1)
		check(e.taken and not pipe.taken and not gate.taken and r.sewer.splashes.size()==1,"Water obstacle destroyed with splash, structures remain: "+kind)
	for activity in ["space","sewer"]:
		var full = model()
		if activity=="space":full.space.begin(full,true)
		else:full.sewer.begin(full,true)
		for i in range(600):
			full.advance(1.0/60,false)
			if (full.space.active and full.space.phase=="flight") or (full.sewer.active and full.sewer.phase=="ride"):break
		full.space.objects.clear();full.sewer.objects.clear();full.space.next_group = 1e9;full.sewer.next_encounter = 1e9
		var obstacle = full.space.battle.spawn_ship(full.space,full,"cargo",1100,400) if activity=="space" else full.sewer.add_object("rubble",1630,420)
		full.bird.ferrugem.until_shot = .1
		for i in range(120):full.advance(1.0/60,false)
		check(not full.dead and obstacle.taken and full.bird.ferrugem.shots==1,"Full moving "+activity+" physics accepts the targeted destruction")
		full = null
	var d = fixture();d.bird_pending = {"id":"ferrugem","new":true,"source":"draw","taps":0};d.bird_discovered = {};r = model();r.bird.configure(d)
	check(r.bird.id.is_empty(),"An unrevealed bird cannot enter the run")
	d = fixture();d.bird_copies.pipoco = 3;d.bird_discovered.pipoco = true;d.bird_equipped = "pipoco";d.bird_equipped_slots = ["pipoco","ferrugem"]
	r = model();r.bird.configure(d);e = vehicle(r);r.bird.companion.ferrugem.until_shot = 0;r.bird.pipoco.until_spit = 0;step(r,2)
	check(e.taken and r.bird.companion.ferrugem.shots==1 and r.bird.pipoco.cycles==1,"Second nest fires independently while Pipoco spits")
	d = fixture();d.bird_equipped_slots = ["ferrugem","ferrugem"];r.bird.configure(d)
	check(r.bird.companion==null,"Duplicate species cannot create a second laser")
	check(Art.laser_texture().get_size()==Vector2(1024,512) and Art.laser_eyes.size()==8,"Eight compact poses loaded once")
	for eye in Art.laser_eyes:check(eye.x>0 and eye.x<256 and eye.y>0 and eye.y<256,"Lens anchor lies inside its cell")
	r = null;e = {};second = {};neighbor = {};d = {}
	var boot = load("res://boot.tscn").instantiate();root.add_child(boot);current_scene = boot
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):game = current_scene;break
	check(is_instance_valid(game),"Full game boots through updated audit")
	if not is_instance_valid(game):quit(1);return
	await process_frame;await process_frame;await process_frame
	game.test_mode = true;game.set_process(false);game.set_physics_process(false);game.sound.set_enabled(true)
	game.data = fixture();root.size = Vector2i(1600,720);game.start_run();game.intro_left = 0
	game.runner.start_developer("bomb",4,0,175);game.runner.entities.clear();game.runner.next_pattern_world = 1e12;game.runner.bird.configure(game.data)
	e = vehicle(game.runner);game.runner.bird.ferrugem.until_shot = .1
	await game_step(.3);await snap("01_aim_charge")
	var age_before = game.runner.bird.ferrugem.age;game.change_screen("pause")
	for i in range(90):game._physics_process(1.0/30)
	check(game.runner.bird.ferrugem.age==age_before and not e.taken,"Pause freezes charge and damage")
	game.change_screen("run");await game_step(.3);await snap("02_full_charge")
	for i in range(30):
		if game.runner.bird.ferrugem.phase=="fire":break
		await game_step(1.0/30)
	await snap("03_laser_impact")
	check(e.taken and game.runner.cars==1 and game.runner.bird.ferrugem.shots==1,"Actual scrolling gameplay destroys a tank at laser impact")
	check(game.toast.begins_with("FERRUGEM DESTRUIU!"),"HUD identifies the actual laser destruction")
	check(game.effects.wrecks.size()==1 and game.effects.wrecks[0].laser and game.effects.particles.filter(func(v):return v.kind=="vehicle_shard").size()==6,"A laser breaks the vehicle into six bounded pieces and leaves a burnt wreck")
	await game_step(.3);await snap("04_recoil_wreck_passengers")
	await game_step(1);await snap("05_recovered_hover")
	check(game.runner.bird.ferrugem.phase=="idle" and game.runner.bird.ferrugem.until_shot>38,"Recovery finishes with long cooldown retained")
	var report = {"checks":checks,"failures":failures,"rendered":DisplayServer.get_name()!="headless","physical_device_tested":false,"cooldown_seconds":[60,50,40],"max_targets_per_shot":1,"new_pose_count":8,"atlas_rgba_bytes":2097152}
	print("V175_FERRUGEM ",JSON.stringify(report));game.sound.set_enabled(false);game.sound.set_process(false)
	for player in game.sound.get_children():
		if player is AudioStreamPlayer:player.stop();player.stream = null
	game.queue_free();game = null;current_scene = null
	await process_frame;await process_frame;await create_timer(.25).timeout;quit(0 if failures.is_empty() else 1)

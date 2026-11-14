extends SceneTree
const Catalog = preload("res://scripts/bird_catalog.gd")
const Art = preload("res://scripts/bird_art.gd")
var checks = 0
var failures: Array[String] = []
var game
var folder = ""

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:failures.append(message);push_error(message)

func fixture(level: int = 3,second: bool = false) -> Dictionary:
	var d = MonsterCatalog.defaults();d.bird_copies = {"agourinho":level,"pipoco":3};d.bird_discovered = {"agourinho":true,"pipoco":true}
	d.bird_equipped_slots = ["pipoco","agourinho"] if second else ["agourinho",""];d.bird_equipped = d.bird_equipped_slots[0];return d

func model(count: int = 4,level: int = 3,second: bool = false):
	var r = HordeRun.new();r.start_developer("bomb",count,0,177);r.entities.clear();r.events.clear();r.next_pattern_world = 1e12
	r.bird.configure(fixture(level,second));return r

func owl(r):return r.bird.companion if r.bird.id!="agourinho" else r.bird

func game_step(seconds: float) -> void:
	for i in range(roundi(seconds*30)):
		game._physics_process(1.0/30);game._process(1.0/30);await process_frame

func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game._process(0);await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"Native capture "+name)

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if folder.is_empty():folder = "user://agourinho-v177"
	DirAccess.make_dir_recursive_absolute(folder)
	var atlas = Art.texture("agourinho").get_image()
	for i in range(6):
		var used = atlas.get_region(Rect2i(i%3*384,int(i/3)*384,384,384)).get_used_rect()
		check(used.has_area() and used.position.x>=12 and used.position.y>=12 and used.end.x<=372 and used.end.y<=372,"All owl feathers and ribbons stay inside padded pose "+str(i))
	for count in [2,4,12]:
		for second in [false,true]:
			var r = model(count,3,second);var bird = owl(r)
			while r.members.size()>1:
				var before = r.active_count();r.hit_grace = 0;r.damage(0,"impact")
				check(r.active_count()==before-1 and not bird.rescued and bird.agourinho.age<0,"Partial losses retain the charge: count "+str(count)+", second nest "+str(second))
			var last_id = int(r.members[0].id);var losses = r.losses;var coins = r.coins;var souls = r.souls
			r.hit_grace = 0;r.damage(0,"impact")
			check(not r.dead and r.active_count()==1 and int(r.members[0].id)==last_id and bird.rescued,"Only the final creature is retained, with its original identity")
			check(r.losses==losses and r.coins==coins and r.souls==souls and r.recruits==0,"Last chance creates no replacement, coins, souls or capture rewards")
			check(r.events.filter(func(e):return e.type=="bird_rescue").size()==1 and not r.events.any(func(e):return e.type=="finish"),"Exactly one rescue event and no premature game over")
			r.add_member(0,false);r.hit_grace = 0;r.remove_member(1,"impact");r.hit_grace = 0;r.damage(0,"impact")
			check(r.dead and r.members.is_empty() and r.events.filter(func(e):return e.type=="bird_rescue").size()==1,"Regrowing the horde cannot replenish the once-per-run rescue")
	for lv in [1,2,3]:
		var r = model(1,lv);var before = r.members[0];r.damage(0,"impact")
		check(r.members.size()==1 and is_same(r.members[0],before) and is_equal_approx(r.hit_grace,1.0+(lv-1)*.5),"Each bar preserves its brief protection duration")
	var r = model(3);r.members[0].falling = true;r.cached_active = 0;r.remove_member(0,"fall")
	check(not owl(r).rescued and r.members.size()==2,"A falling member cannot spend the charge while two others survive, even with a stale cache")
	r = model(2);r.members[0].falling = true;r.remove_member(0,"fall")
	check(not owl(r).rescued and r.members.size()==1,"A fallen member cannot spend the charge while one other creature survives")
	r = model(4);var ids = r.members.map(func(m):return int(m.id))
	for m in r.members:m.falling = true;m.y = r.FLOOR+190
	r.cached_active = 4;r.remove_member(3,"fall")
	check(owl(r).rescued and r.active_count()==1 and not r.members[3].falling,"A simultaneous full-horde fall rescues one doomed member")
	for i in range(2,-1,-1):r.remove_member(i,"fall")
	check(r.members.size()==1 and int(r.members[0].id) in ids and not r.dead,"The rest of a doomed wave is still removed normally")
	r = model(1);r.shields = 1;r.damage(0,"impact")
	check(not owl(r).rescued and r.shields==0,"An ordinary shield blocks the hit without consuming last chance")
	r.hit_grace = 0;r.damage(0,"impact");r.damage(0,"impact")
	check(owl(r).rescued and not r.dead,"The rescued final creature is protected from another immediate hit")
	r = model(1);var m = r.members[0];m.jump_queue.append({"delay":.2});m.jump_at = 9;m.jump_delay = .2;m.vy = 600;m.falling = true;r.cached_active = -1;r.remove_member(0,"fall")
	check(m.jump_queue.is_empty() and m.jump_at<0 and m.jump_delay<0 and m.vy==0 and not m.falling,"Fatal fall motion and queued jumps are cleared on return")
	r = model(4);r.add_entity("gap",r.ANCHOR-120,r.FLOOR,0,520)
	for i in range(300):r.advance(1.0/60,false)
	check(owl(r).rescued and not r.dead and r.active_count()==1 and r.losses==3,"Real pit physics saves only one member from a complete horde fall")
	for mode in ["space","sewer","sky"]:
		r = model(2)
		if mode=="space":r.space.active = true;r.space.phase = "flight"
		elif mode=="sewer":r.sewer.active = true;r.sewer.phase = "ride"
		else:r.sky.active = true
		r.damage(0,"impact")
		check(r.active_count()==1 and not owl(r).rescued,"No early rescue in "+mode)
		r.hit_grace = 0;r.damage(0,"impact")
		check(r.active_count()==1 and owl(r).rescued and not r.dead,"Final-member rescue works in "+mode)
	r = model(1);var locked = fixture();locked.bird_discovered = {};locked.bird_pending = {"id":"agourinho","new":true,"source":"draw","taps":0};r.bird.configure(locked);r.damage(0,"impact")
	check(r.dead and not r.bird.rescued,"An unrevealed owl grants no last chance")
	r = model(1);r.damage(0,"impact");r.hit_grace = 0;r.damage(0,"impact");r.revive_horde(1);r.hit_grace = 0;r.damage(0,"impact")
	check(r.dead and owl(r).rescued,"Continuing a finished run does not refill the owl")
	r = model(1);r.damage(0,"impact");r.start_developer("bomb",1,0,178);r.entities.clear();r.bird.configure(fixture());r.damage(0,"impact")
	check(not r.dead and owl(r).rescued,"A genuinely new match receives a new single charge")
	r = null;m = {};locked = {}
	var boot = load("res://boot.tscn").instantiate();root.add_child(boot);current_scene = boot
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):game = current_scene;break
	check(is_instance_valid(game),"Full game boots through the startup audit")
	if not is_instance_valid(game):quit(1);return
	await process_frame;await process_frame;await process_frame
	game.test_mode = true;game.set_process(false);game.set_physics_process(false);game.sound.set_enabled(true)
	game.data = fixture();root.size = Vector2i(1600,720);game.start_run();game.intro_left = 0
	game.runner.start_developer("bomb",4,0,177);game.runner.entities.clear();game.runner.next_pattern_world = 1e12;game.runner.bird.configure(game.data)
	game.runner.damage(0,"impact");await game_step(.7);await snap("01_partial_loss_no_portal")
	check(not game.runner.bird.rescued and game.runner.active_count()==3,"Actual gameplay loses an ordinary member without the portal")
	while game.runner.members.size()>1:
		game.runner.remove_member(0,"impact");await game_step(1.0)
	game.runner.hit_grace = 0;game.runner.damage(0,"impact");await game_step(.22);await snap("02_last_chance_portal")
	check(game.runner.active_count()==1 and game.runner.bird.rescued and game.toast.contains("ÚLTIMA CHANCE"),"Last chance is presented only for the final creature")
	var age = game.runner.bird.agourinho.age;game.change_screen("pause")
	for i in range(60):game._physics_process(1.0/30)
	check(game.runner.bird.agourinho.age==age,"Pause freezes the rescue presentation")
	game.change_screen("run");await game_step(.5);await snap("03_feathers_and_protection")
	await game_step(1.5);await snap("04_back_to_running")
	check(game.runner.bird.agourinho.age<0 and game.runner.active_count()==1,"The portal closes with one playable survivor")
	var report = {"checks":checks,"failures":failures,"rendered":DisplayServer.get_name()!="headless","physical_device_tested":false,"trigger":"final_member_only","max_rescues_per_run":1,"max_saved_members":1,"max_feather_motes":10,"new_textures":1,"atlas_rgba_bytes":3538944}
	print("V177_AGOURINHO ",JSON.stringify(report));game.sound.set_enabled(false);game.sound.set_process(false)
	for player in game.sound.get_children():
		if player is AudioStreamPlayer:player.stop();player.stream = null
	game.queue_free();game = null;current_scene = null
	await process_frame;await process_frame;await create_timer(.25).timeout;quit(0 if failures.is_empty() else 1)

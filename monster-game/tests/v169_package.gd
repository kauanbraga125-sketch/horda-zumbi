extends SceneTree
const Catalog = preload("res://scripts/bird_catalog.gd")
var checks = 0
var failures: Array[String] = []
var folder = ""
var game
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"Screenshot "+name)
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if folder.is_empty():folder = "user://v169"
	DirAccess.make_dir_recursive_absolute(folder)
	var data = MonsterCatalog.defaults();data.eyes = 1000;var rng = RandomNumberGenerator.new();rng.seed = 169
	var first = Catalog.roll(data,rng)
	check(data.eyes==970 and not first.is_empty(),"Every egg costs exactly 30 diamonds, including first")
	var before = data.duplicate(true)
	check(Catalog.roll(data,rng).is_empty() and data==before,"Pending egg blocks repeat charge and reroll")
	data.bird_pending = {};data.bird_copies = {};data.bird_equipped = "";data.bird_equipped_slots = ["",""]
	for i in range(3):Catalog.add_copy(data,"pipoco","draw");data.bird_pending = {}
	check(Catalog.level(data,"pipoco")==3 and Catalog.fuse(data,"pipoco").is_empty(),"Three draws fill one bird, not enough for fusion")
	for i in range(3):Catalog.add_copy(data,"pipoco","draw");data.bird_pending = {}
	check(Catalog.copies(data,"pipoco")==6,"Six draws represent two complete copies")
	data.bird_equipped_slots = ["",""];data.bird_equipped = ""
	check(Catalog.equip(data,"pipoco",0) and Catalog.equip(data,"pipoco",1),"Two separate copies may occupy two equipment slots")
	var fusion = Catalog.fuse(data,"pipoco")
	check(fusion.id=="fiapo" and Catalog.copies(data,"pipoco")==0,"Fusion consumes exactly six source draws")
	check(data.bird_equipped_slots[1]=="" and data.bird_equipped_slots[0]=="fiapo","Fusion removes spent equipment and equips new bird safely")
	before = data.duplicate(true)
	check(Catalog.fuse(data,"pipoco").is_empty() and data==before,"Repeated fusion action cannot spend twice")
	data.bird_pending = {};data.bird_copies.barao = 6
	check(Catalog.fuse(data,"barao").is_empty(),"Highest tier cannot fuse")
	var migrated = Catalog.migrate(data)
	check(Catalog.IDS.all(func(id):return Catalog.copies(migrated,id)==Catalog.copies(data,id)) and migrated.bird_equipped_slots.size()==2,"Save migration preserves collection and two slots")
	var r = HordeRun.new();r.start_developer("bomb",4,0,169);r.entities.clear();r.events.clear()
	var row = r.new_coin_row(3)
	var coins = []
	for i in range(3):coins.append({"kind":"coin","coin_row":row,"x":100+i*76,"y":400,"taken":true})
	r.collect_coin_row(coins[0]);r.miss_coin_row(coins[0]);r.collect_coin_row(coins[1]);r.collect_coin_row(coins[2])
	check(r.events.filter(func(e):return e.type=="perfect").size()==1,"Retiring a collected coin no longer cancels PERFECT")
	r.collect_coin_row(coins[2])
	check(r.events.filter(func(e):return e.type=="perfect").size()==1,"One formation grants one PERFECT")
	row = r.new_coin_row(3);r.events.clear()
	r.miss_coin_row({"coin_row":row,"taken":false})
	for i in range(3):r.collect_coin_row({"coin_row":row,"x":100,"y":400})
	check(r.events.is_empty(),"A genuinely missed coin still invalidates PERFECT")
	var boot = load("res://boot.tscn").instantiate();root.add_child(boot);current_scene = boot
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):game = current_scene;break
	check(is_instance_valid(game),"Game boots through 0.10.69 integrity audit")
	if not is_instance_valid(game):quit(1);return
	game.data = MonsterCatalog.defaults();game.data.wallet = 1000000;game.data.eyes = 10000
	game.set_physics_process(false);game.sound.set_enabled(true)
	check(game.sound.distant_players.size()==6 and game.sound.players.size()==10,"Bounded audio pools with six background channels")
	var last_pitch = 0.0
	for i in range(8):
		game.sound.play_coin();var index = posmod(game.sound.coin_index-1,4);var pitch = game.sound.coin_players[index].pitch_scale
		check(pitch>last_pitch,"Ascending coin piano note "+str(i));last_pitch = pitch
	var view = Rect2(0,0,1280,720)
	for i in range(6):game.sound.play_distant_at("dragon",-17,view.get_center(),view)
	check(game.sound.distant_players.filter(func(p):return p.playing).size()==6,"Six scene events can play together")
	game.sound.play_distant_at("impact",-12,view.get_center(),view)
	check(game.sound.distant_players.filter(func(p):return p.playing).size()==6 and game.sound.distant_players.any(func(p):return p.stream==game.sound.score.effect_cache.get("impact_1.bin")),"A stronger event replaces a quiet background cue within fixed pool")
	check(game.sound.clips.civil_new_4.get_length()<.9,"Late civilian voice has its near-silent lead removed")
	check(game.sound.clips.ending_warning!=game.sound.clips.power_warning,"Power-ending cue is separate from hazard warnings")
	for p in game.sound.distant_players:p.stop()
	game.sound.play_ui_restart("egg_crack")
	check(game.sound.ui_player.stream.get_length()<.21,"Egg tap uses owner's cropped short sound")
	var variants: Array = []
	for i in range(4):game.sound.play_perfect();variants.append(game.sound.perfect_index)
	check(variants==[0,1,2,3],"Four PERFECT voice takes alternate without repeats")
	game.runner.events.append({"type":"perfect","x":200,"y":400,"count":3});game.consume_run_events()
	check(game.perfect_left>0 and game.sound.voice_players.any(func(p):return p.stream==game.sound.clips.perfect_1),"Completed formation drives HUD and owner PERFECT voice")
	game.sound.play("transform_fly");check(game.sound.voice_players.any(func(p):return p.stream==game.sound.clips.transform_fly),"Owner Super Fly cue is used")
	game.sound.play("transform_mask");check(game.sound.voice_players.any(func(p):return p.stream==game.sound.clips.transform_mask),"Owner Mask cue is used")
	game.runner.events.append({"type":"power_warning"});game.consume_run_events()
	check(game.sound.voice_players.any(func(p):return p.stream==game.sound.clips.ending_warning),"Ending event uses owner's warning cue")
	game.perform_action("market");game.market.open(2)
	await snap("01_accessories")
	if DisplayServer.get_name()!="headless":check(game.market.thumbnails.size()>0 and game.actor.cosmetics.frames.is_empty(),"Market uses small art without loading fitting meshes")
	game.market.open(0)
	var stock = int(game.data.stock.get("coin_magnet",0));var wallet = int(game.data.wallet)
	game.perform_action("object_buy_coin_magnet")
	check(game.shop_dialog.is_open() and int(game.data.wallet)==wallet,"Selecting purchase opens confirmation without spending")
	await snap("02_purchase_confirmation")
	game.perform_action("shop_cancel")
	check(game.data.stock.get("coin_magnet",0)==stock and int(game.data.wallet)==wallet,"Cancel has no purchase side effects")
	game.perform_action("object_buy_coin_magnet");game.perform_action("shop_confirm");game.perform_action("shop_confirm")
	check(int(game.data.stock.get("coin_magnet",0))==stock+1 and int(game.data.wallet)==wallet-220,"Confirm purchases once, even repeated immediately")
	await snap("03_purchase_success")
	game.shop_dialog.update(1.1)
	check(game.shop_dialog.success_left<=0,"Purchase celebration ends before further navigation")
	game.data.merge(Catalog.defaults(),true);game.data.bird_copies = {"pipoco":7,"fiapo":3,"ferrugem":1};game.data.bird_equipped_slots = ["pipoco","fiapo"];game.data.bird_equipped = "pipoco"
	game.perform_action("market_tab_4")
	check(game.screen=="birds","Bird collection is available in market tab")
	await snap("04_bird_collection")
	game.birds_ui.page = "fusion";await snap("05_bird_fusion")
	game.data.bird_pending = {};var diamonds = int(game.data.eyes);game.perform_action("bird_draw")
	check(int(game.data.eyes)==diamonds-30 and game.data.bird_pending.taps==0,"Purchased egg waits for physical taps")
	await snap("06_egg")
	await create_timer(1.3).timeout
	for i in range(3):
		game.perform_action("bird_tap")
		check(game.data.bird_pending.taps==i+1 and game.sound.ui_player.playing,"Egg tap and restart "+str(i+1))
		check(Catalog.migrate(game.data).bird_pending.taps==i+1,"Egg taps persist through reload "+str(i+1))
		if i<2:await snap("07_egg_crack_"+str(i+1))
	await create_timer(.8).timeout
	await snap("08_revealed")
	check(game.birds_ui.reveal_sound,"Third tap triggers hatch cue once")
	game.perform_action("bird_done");check(game.data.bird_pending.is_empty(),"Receipt completes without another charge")
	game.runner.bird.configure(game.data)
	check(game.runner.bird.companion!=null,"Two equipped birds both enter actual run simulation")
	game.change_screen("home");game.start_run();game.runner.members[0].kind = 1
	check(game.perfect_left==0,"New race clears previous PERFECT announcement")
	var elapsed = game.runner.elapsed;game._physics_process(.1)
	check(game.intro_left>0 and game.runner.elapsed==elapsed,"Opening freezes race physics and hazards")
	game.intro_left = .85;await snap("09_skeleton_emerging")
	game.runner.members[0].kind = 0;game.intro_left = .65;await snap("10_zombie_emerging")
	game.intro_left = 0;await snap("11_ready_to_run")
	game.sound.set_enabled(false)
	check(game.sound.coin_players.all(func(p):return not p.playing) and game.sound.voice_players.all(func(p):return not p.playing),"Mute also stops reserved coin and voice channels")
	var report = {"version":"0.10.69","checks":checks,"failures":failures,"physical_device_tested":false,"rendered":DisplayServer.get_name()!="headless"}
	var f = FileAccess.open(folder+"/v169.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("V169_PACKAGE ",JSON.stringify(report));game.set_process(false);game.queue_free();current_scene = null
	for i in range(8):await process_frame
	quit(0 if failures.is_empty() else 1)

extends SceneTree
const Catalog = preload("res://scripts/bird_catalog.gd")
var checks = 0
var failures: Array[String] = []
var game
var folder = ""

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:failures.append(message);push_error(message)

func _initialize() -> void:call_deferred("run")

func advance(seconds: float) -> void:
	for i in range(ceili(seconds*30)):
		game._process(1.0/30);await process_frame

func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game._process(0);await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"Native image "+name)

func fixture() -> Dictionary:
	var data = MonsterCatalog.defaults();data.wallet = 1000000;data.eyes = 10000;return data

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if folder.is_empty():folder = "user://aviary-v170"
	DirAccess.make_dir_recursive_absolute(folder)
	var data = fixture();var r = HordeRun.new();r.start_developer("gap",1,0,170)
	check(Catalog.IDS.all(func(id):return not Catalog.available(data,id) and not Catalog.discovered(data,id)),"Fresh player has no unlocked birds")
	data.bird_equipped_slots = ["pipoco","fiapo"];data.bird_equipped = "pipoco";r.bird.configure(data)
	check(r.bird.id.is_empty() and r.bird.companion==null,"Forged or stale unowned equipment cannot spawn a bird")
	check(Catalog.migrate(data).bird_equipped_slots==["",""],"Migration removes both unowned equipped slots")
	data.bird_copies.pipoco = 3;data.bird_pending = {}
	var migrated = Catalog.migrate(data)
	check(Catalog.discovered(migrated,"pipoco") and Catalog.available(migrated,"pipoco"),"Existing 0.10.69 owned birds migrate as discovered")
	data = fixture();var rng = RandomNumberGenerator.new();rng.seed = 170
	var receipt = Catalog.roll(data,rng);var chosen = str(receipt.id);var money = int(data.eyes)
	check(receipt.stage=="crate" and money==9970,"Thirty diamonds purchase exactly one persisted crate")
	check(not Catalog.discovered(data,chosen) and not Catalog.equip(data,chosen,0),"First paid egg does not reveal or equip its bird early")
	var before = data.duplicate(true)
	check(Catalog.roll(data,rng).is_empty() and data==before,"Pending crate prevents a duplicate purchase or reroll")
	check(Catalog.migrate(data).bird_pending.stage=="crate","Opening stage survives migration")
	data.bird_pending.erase("stage")
	check(Catalog.migrate(data).bird_pending.stage=="egg","Legacy paid eggs resume directly at the egg")
	data = fixture();data.bird_copies.pipoco = 6;data.bird_discovered.pipoco = true
	receipt = Catalog.fuse(data,"pipoco")
	check(receipt.stage=="fusion" and receipt.input=="pipoco" and Catalog.copies(data,"pipoco")==0,"Fusion consumes six draws and keeps an animation receipt")
	check(Catalog.discovered(data,"pipoco") and not Catalog.available(data,"pipoco"),"Spent source remains known but cannot be equipped")
	check(Catalog.discovered(data,"fiapo") and Catalog.copies(data,"fiapo")==1,"Fusion grants one real next-rarity copy")
	before = data.duplicate(true)
	check(Catalog.fuse(data,"pipoco").is_empty() and data==before,"Repeated fusion cannot consume copies twice")
	data.bird_pending = {};data.bird_copies.barao = 6
	check(Catalog.fuse(data,"barao").is_empty(),"Legendary birds have no invalid next-tier fusion")
	var boot = load("res://boot.tscn").instantiate();root.add_child(boot);current_scene = boot
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):game = current_scene;break
	check(is_instance_valid(game),"Full game boots through current integrity audit")
	if not is_instance_valid(game):quit(1);return
	game.set_process(false);game.set_physics_process(false);game.test_mode = true;game.sound.set_enabled(true)
	game.data = fixture();game.perform_action("birds_open");await advance(.10)
	await snap("01_locked_collection")
	check(game.birds_ui.art.textures.keys().all(func(k):return not str(k).begins_with("portrait/")),"Locked collection never loads any real bird portrait")
	game.runner.bird.configure(game.data)
	check(game.runner.bird.id.is_empty() and game.runner.bird.companion==null,"Fresh aviary does not introduce a companion into the race")
	game.data.bird_copies = {"pipoco":7,"fiapo":3,"ferrugem":1};game.data.bird_discovered = {"pipoco":true,"fiapo":true,"ferrugem":true}
	game.data.bird_equipped_slots = ["pipoco","fiapo"];game.data.bird_equipped = "pipoco"
	await snap("02_unlocked_laboratory")
	game.perform_action("bird_fusion");await snap("03_fusion_collection")
	check(game.birds_ui.page=="fusion","Fusion control opens the eligible-copy collection")
	game.perform_action("bird_collection");game.data = fixture();game.birds_ui.selected = 0
	game.perform_action("bird_draw");money = int(game.data.eyes);chosen = str(game.data.bird_pending.id)
	await snap("04_crate_closed")
	game.perform_action("bird_tap")
	check(game.data.bird_pending.taps==0,"Touches during opening cannot crack an invisible egg")
	await advance(.65);await snap("05_crate_opening")
	await advance(.60)
	check(game.birds_ui.stage(game)=="egg" and int(game.data.eyes)==money,"Crate opening reveals egg without another charge")
	await snap("06_egg_ready")
	game.perform_action("bird_tap")
	check(game.data.bird_pending.taps==1 and game.sound.ui_player.playing,"First physical tap immediately restarts short cracking cue")
	await snap("07_egg_tap_one")
	check(game.save_game("user://v170-persistence.json"),"Pending egg writes through real save code")
	var restored = game.read_save("user://v170-persistence.json")
	check(restored.bird_pending.taps==1 and restored.bird_pending.stage=="egg" and restored.eyes==money,"Real disk reload preserves paid egg, currency and tap count")
	check(not Catalog.discovered(restored,chosen),"Reloading a first incomplete egg does not reveal the bird")
	game.data = restored;game.perform_action("back");game.perform_action("birds_open")
	check(game.data.bird_pending.taps==1 and game.birds_ui.stage(game)=="egg","Leaving and reopening resumes the same egg")
	game.perform_action("bird_tap");await snap("08_egg_tap_two")
	game.perform_action("bird_tap")
	check(game.data.bird_pending.taps==3 and Catalog.discovered(game.data,chosen),"Only the third physical tap reveals the first bird")
	check(int(game.data.eyes)==money and Catalog.copies(game.data,chosen)==1,"Three taps never reroll, duplicate or charge the reward")
	await advance(.25);await snap("09_egg_reveal_burst")
	await advance(.60);await snap("10_bird_revealed")
	check(game.birds_ui.reveal_sound,"Opening voice/sound follows the third crack")
	game.perform_action("bird_done");check(game.data.bird_pending.is_empty(),"Reveal receipt clears after acknowledgement")
	check(Catalog.available(game.data,chosen),"Revealed first copy can now be equipped")
	game.data.bird_copies.pipoco = 6;game.data.bird_discovered.pipoco = true
	game.birds_ui.selected = 0;game.perform_action("bird_fuse");var after_fusion = game.data.duplicate(true)
	game.perform_action("bird_fuse")
	check(game.data==after_fusion and game.birds_ui.stage(game)=="fusion","Fusion animation blocks a duplicate transaction")
	await advance(.75);await snap("11_fusion_charge")
	check(game.save_game("user://v170-fusion.json") and game.read_save("user://v170-fusion.json").bird_pending.stage=="fusion","Fusion animation also resumes from a durable receipt")
	await advance(1.1);await advance(.8);await snap("12_fusion_revealed")
	check(game.birds_ui.stage(game)=="reveal" and Catalog.available(game.data,"fiapo"),"Machine completes into the actual next-rarity bird")
	game.perform_action("bird_done");game.birds_ui.selected = 1;game.perform_action("bird_equip_1")
	await snap("13_equipment_nests")
	check(game.data.bird_equipped_slots[1]=="fiapo" or game.data.bird_equipped_slots[0]=="fiapo","Owned bird can occupy a real equipment machine")
	for i in range(5):
		game.data.bird_pending = {};Catalog.add_copy(game.data,Catalog.IDS[i],"draw");game.data.bird_pending.stage = "egg";game.birds_ui.age = 1
		await snap("14_rarity_"+str(i))
		var original = game.birds_ui.art.texture("egg_"+str(i))
		check(original!=null and original.get_width()>150 and original.get_height()>250,"Distinct readable egg sprite for rarity "+str(i))
	game.data = fixture();game.codex.open(game,4);await advance(.8);await snap("15_book_birds_locked")
	check(game.codex.total_pages()==22 and game.codex.chapters.size()==5,"Expanded book has 22 numbered pages and a bird chapter")
	check(not game.codex.unlocked(game,game.codex.record(4,0,0)) and not game.codex.leaves[0].portrait.visible,"Unreleased bird book entry has no visible illustration")
	game.data.bird_copies.pipoco = 1;game.data.bird_discovered.pipoco = true
	await advance(.65);await snap("16_book_bird_fragments")
	check(not bool(game.data.codex_seen.get("bird_pipoco",false)),"Book waits for fragment assembly before persisting discovery")
	await advance(1.5);await snap("17_book_bird_restored")
	check(bool(game.data.codex_seen.get("bird_pipoco",false)) and game.codex.leaves[0].portrait.visible,"Owned bird illustration assembles and remains restored")
	game.data.power_owned = [2,3,5,6,7,8];game.codex.turn_to(game,1,1);await advance(2.7);await snap("18_book_new_powers")
	check(bool(game.data.codex_seen.get("harvester",false)) and bool(game.data.codex_seen.get("spectral",false)),"New power illustrations use the same fragment reveal")
	game.perform_action("back");await advance(1);game.perform_action("birds_open")
	for size in [Vector2i(1600,720),Vector2i(1280,960)]:
		root.size = size;await advance(.1);var d = game.birds_ui.layout(game.full_rect())
		check(game.full_rect().encloses(d.collection) and game.full_rect().encloses(d.eggs) and game.full_rect().encloses(d.fusion) and game.full_rect().encloses(d.crate),"Aviary panels fit aspect "+str(size))
		check(not d.collection.intersects(d.fusion) and not d.eggs.intersects(d.crate),"Collection and machines do not overlap "+str(size))
		await snap("19_aspect_"+str(size.x)+"x"+str(size.y))
	check(game.birds_ui.art.textures.size()<=24,"Aviary texture cache stays bounded without preloading book art")
	game.sound.set_enabled(false);game.set_process(false);game.queue_free();current_scene = null;game = null;boot = null
	for i in range(8):await process_frame
	var report = {"version":"0.10.70","checks":checks,"failures":failures,"rendered":DisplayServer.get_name()!="headless","physical_device_tested":false}
	var f = FileAccess.open(folder+"/v170.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("V170_AVIARY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

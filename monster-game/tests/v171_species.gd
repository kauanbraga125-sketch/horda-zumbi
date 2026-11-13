extends SceneTree
const Catalog = preload("res://scripts/bird_catalog.gd")
var checks = 0
var failures: Array[String] = []
var game
var folder = ""

class FailedSave:
	extends RefCounted
	var data: Dictionary
	var messages: Array = []
	func save_game() -> bool:return false
	func show_toast(value: String,_seconds: float = 2) -> void:messages.append(value)

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:failures.append(message);push_error(message)

func fixture() -> Dictionary:
	var data = MonsterCatalog.defaults();data.wallet = 1000000;data.eyes = 10000;return data

func advance(seconds: float) -> void:
	for i in range(ceili(seconds*30)):
		game._process(1.0/30);await process_frame

func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await advance(.10);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"Native capture "+name)

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if folder.is_empty():folder = "user://species-v171"
	DirAccess.make_dir_recursive_absolute(folder)
	var data = fixture();data.bird_copies = {"pipoco":99,"fiapo":3}
	var before = data.duplicate(true)
	check(Catalog.fuse(data,"pipoco","pipoco").is_empty() and data==before,"Identical species cannot fuse even with 99 draws")
	check(Catalog.fuse(data,"pipoco").is_empty() and data==before,"Single-species legacy call cannot consume anything")
	check(Catalog.fuse(data,"pipoco","missing").is_empty() and data==before,"Unknown second species cannot fuse")
	data.bird_copies.fiapo = 2;before = data.duplicate(true)
	check(Catalog.fuse(data,"pipoco","fiapo").is_empty() and data==before,"Both distinct species need all three bars")
	data.bird_copies.barao = 9;before = data.duplicate(true)
	check(Catalog.fuse(data,"pipoco","barao").is_empty() and Catalog.fuse(data,"barao","pipoco").is_empty() and data==before,"Legendary input is excluded in either position")
	var combinations = [["pipoco","fiapo","ferrugem"],["pipoco","ferrugem","agourinho"],["pipoco","agourinho","barao"],["fiapo","ferrugem","agourinho"],["fiapo","agourinho","barao"],["ferrugem","agourinho","barao"]]
	for pair in combinations:
		for reverse in [false,true]:
			var first = str(pair[1] if reverse else pair[0]);var second = str(pair[0] if reverse else pair[1])
			data = fixture();data.bird_copies = {first:3,second:3};data.bird_equipped_slots = [first,second];data.bird_equipped = first
			var receipt = Catalog.fuse(data,first,second)
			check(receipt.get("id","")==pair[2] and receipt.get("inputs",[])==[first,second],"Correct higher reward and two saved inputs: "+first+" + "+second)
			check(Catalog.copies(data,first)==0 and Catalog.copies(data,second)==0 and Catalog.copies(data,pair[2])==1 and data.wallet==1000000 and data.eyes==10000,"Only three bars per input are consumed: "+first+" + "+second)
			var migrated = Catalog.migrate(data)
			check(migrated.bird_pending.stage=="fusion" and migrated.bird_pending.inputs==[first,second] and migrated.bird_equipped_slots==[pair[2],""],"Fusion resumes and equips one actual result: "+first+" + "+second)
			before = data.duplicate(true)
			check(Catalog.fuse(data,first,second).is_empty() and data==before,"Pending transaction cannot fuse twice: "+first+" + "+second)
	data = fixture();data.bird_copies = {"pipoco":9,"fiapo":6};data.bird_equipped_slots = ["pipoco","fiapo"];data.bird_equipped = "pipoco"
	Catalog.fuse(data,"pipoco","fiapo")
	check(Catalog.copies(data,"pipoco")==6 and Catalog.copies(data,"fiapo")==3 and Catalog.equipped_slots(data)==["pipoco","fiapo"],"Extra copies and still-owned equipment are preserved")
	data = fixture();data.bird_copies.pipoco = 9
	check(Catalog.equip(data,"pipoco",0),"An owned species can occupy its first nest")
	before = data.duplicate(true)
	check(not Catalog.equip(data,"pipoco",1) and data==before,"A second full copy never permits duplicate equipment")
	data.bird_equipped_slots = ["pipoco","pipoco"]
	var migrated = Catalog.migrate(data)
	check(migrated.bird_equipped_slots==["pipoco",""] and Catalog.copies(migrated,"pipoco")==9,"Old duplicate equipment is cleared without deleting inventory")
	var run_model = HordeRun.new();run_model.start_developer("gap",1,0,171);run_model.bird.configure(data)
	check(run_model.bird.id=="pipoco" and run_model.bird.companion==null,"Runtime rejects duplicate companions even before migration")
	var coins = run_model.coins;run_model.bird.on_perfect(run_model)
	check(run_model.coins==coins+3,"Duplicate saved slots cannot double the Perfect bonus")
	data.bird_equipped_slots = ["","pipoco"];data.bird_equipped = ""
	Catalog.add_copy(data,"pipoco","draw");data.bird_pending.taps = 3;Catalog.unlock_receipt(data)
	check(data.bird_equipped_slots==["","pipoco"],"Revealing another copy never auto-equips the same species twice")
	var legacy = fixture();legacy.bird_copies.fiapo = 1;legacy.bird_pending = {"id":"fiapo","source":"fusion","stage":"fusion","taps":3,"input":"pipoco"}
	migrated = Catalog.migrate(legacy)
	check(migrated.bird_pending.stage=="reveal" and Catalog.copies(migrated,"fiapo")==1,"Already-awarded old fusion keeps its reward and skips the obsolete matching-species animation")
	var fake = FailedSave.new();fake.data = fixture();fake.data.bird_copies = {"pipoco":3,"fiapo":3}
	var ui = preload("res://scripts/birds_ui.gd").new();ui.fusion_inputs = ["pipoco","fiapo"];before = fake.data.duplicate(true);ui.transaction(fake,true)
	check(fake.data==before and fake.messages.size()==1,"Save failure rolls back both inputs and the reward together")
	run_model = null;ui = null;fake = null
	var boot = load("res://boot.tscn").instantiate();root.add_child(boot);current_scene = boot
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):game = current_scene;break
	check(is_instance_valid(game),"Updated full game boots through its integrity audit")
	if not is_instance_valid(game):quit(1);return
	game.test_mode = true;game.set_process(false);game.set_physics_process(false);game.sound.set_enabled(false)
	root.size = Vector2i(1600,720);game.data = fixture();game.perform_action("birds_open")
	game.data.bird_copies = {"pipoco":9,"fiapo":3};game.data.bird_discovered = {"pipoco":true,"fiapo":true}
	game.data.bird_equipped_slots = ["pipoco","pipoco"];game.data.bird_equipped = "pipoco"
	check(game.save_game("user://v171-old-slots.json") and game.read_save("user://v171-old-slots.json").bird_equipped_slots==["pipoco",""],"Actual save reload clears duplicate slots and preserves all nine copies")
	await snap("01_duplicate_nest_blocked")
	if DisplayServer.get_name()!="headless":check(not game.buttons.any(func(b):return b.action=="bird_equip_1"),"Duplicate nest has no actionable equip button")
	before = game.data.duplicate(true);game.perform_action("bird_equip_1")
	check(game.data==before,"Direct UI dispatch cannot bypass the unique-species equipment rule")
	game.data = fixture();game.data.bird_copies = {"pipoco":3,"fiapo":3,"agourinho":3};game.data.bird_discovered = {"pipoco":true,"fiapo":true,"agourinho":true}
	game.data.bird_equipped_slots = ["pipoco","fiapo"];game.data.bird_equipped = "pipoco"
	before = game.data.duplicate(true);game.perform_action("bird_fuse")
	check(game.birds_ui.page=="fusion" and game.data==before and game.birds_ui.fusion_inputs==["pipoco","fiapo"],"First fusion click opens two-species selection without spending")
	await snap("02_two_species_selected")
	game.perform_action("bird_select_0");game.perform_action("bird_select_3")
	check(game.birds_ui.fusion_inputs==["agourinho","fiapo"],"Choosing another eligible species changes one independent input")
	game.perform_action("bird_select_3");game.perform_action("bird_select_0")
	check(game.birds_ui.fusion_inputs==["pipoco","fiapo"],"Inputs can be changed back without introducing a duplicate")
	await snap("03_confirm_distinct_inputs")
	game.perform_action("bird_fuse");var spent = game.data.duplicate(true)
	game.perform_action("bird_fuse")
	check(game.data==spent and game.data.bird_pending.inputs==["pipoco","fiapo"] and Catalog.copies(game.data,"pipoco")==0 and Catalog.copies(game.data,"fiapo")==0,"UI confirmation spends exactly one full copy of each chosen species")
	await advance(.7);await snap("04_distinct_fusion_in_progress")
	check(game.save_game("user://v171-fusion.json"),"New fusion persists through the actual save writer")
	var restored = game.read_save("user://v171-fusion.json")
	check(restored.bird_pending.inputs==["pipoco","fiapo"] and Catalog.copies(restored,"ferrugem")==1,"Both animation inputs and the already-awarded result survive disk reload")
	game.data = restored;game.perform_action("back");game.perform_action("birds_open")
	check(game.data.bird_pending.inputs==["pipoco","fiapo"] and game.data.bird_copies==restored.bird_copies,"Leaving and reopening cannot reroll or spend either source again")
	await advance(2.6);await snap("05_fusion_result")
	game.perform_action("bird_done")
	check(game.data.bird_pending.is_empty() and Catalog.equipped_slots(game.data)==["ferrugem",""] and Catalog.available(game.data,"ferrugem"),"Completed fusion reveals and equips a single earned species")
	game.birds_ui.selected = 2;before = game.data.duplicate(true);game.perform_action("bird_equip_1")
	check(game.data==before,"New fusion result also cannot be equipped into both nests")
	await snap("06_result_equipped_once")
	game.data.bird_copies = {"pipoco":3,"fiapo":3,"ferrugem":3,"agourinho":3}
	game.data.bird_discovered = {"pipoco":true,"fiapo":true,"ferrugem":true,"agourinho":true};game.birds_ui.open_fusion(game)
	await snap("07_four_eligible_species")
	root.size = Vector2i(1280,960);await snap("08_four_by_three")
	game.sound.set_enabled(false);game.queue_free();game = null;current_scene = null;boot = null
	for i in range(8):await process_frame
	var report = {"version":"0.10.71","checks":checks,"failures":failures,"rendered":DisplayServer.get_name()!="headless","physical_device_tested":false}
	var f = FileAccess.open(folder+"/v171.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("V171_SPECIES ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

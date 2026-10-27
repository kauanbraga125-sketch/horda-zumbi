extends SceneTree
const Birds = preload("res://scripts/bird_catalog.gd")
var checks = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures.append(message);push_error(message)
func run() -> void:
	root.size = Vector2i(1280,720)
	var game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_physics_process(false);game.capture_freeze = true;game.sound.set_enabled(false)
	check(not game.test_mode and not game.capture_mode,"real persistence without test save bypass")
	game.data = MonsterCatalog.defaults();game.data.wallet = 1000000;game.data.eyes = 10000
	check(game.save_game(),"initial real save")
	game.perform_action("birds_open");game.perform_action("bird_draw")
	var receipt: Dictionary = game.data.bird_pending.duplicate(true)
	check(not receipt.is_empty() and game.data.eyes==10000 and game.data.bird_draws==1,"first free egg through real UI")
	game.perform_action("bird_draw")
	check(game.data.bird_serial==receipt.serial and game.data.bird_draws==1,"UI rejects another purchase during reveal")
	var disk: Dictionary = game.read_save()
	check(disk.bird_pending==receipt and disk.bird_draws==1,"award receipt persisted before animation")
	game.set_process(false);game.queue_free();game = null
	for i in range(4): await process_frame
	game = load("res://main.tscn").instantiate();root.add_child(game)
	for i in range(4): await process_frame
	game.set_physics_process(false);game.capture_freeze = true;game.sound.set_enabled(false)
	check(game.screen=="birds" and game.data.bird_pending==receipt and game.data.bird_draws==1,"normal relaunch resumes exact pending egg without reroll")
	game.birds_ui.age = 3.2;game.perform_action("bird_done")
	check(game.data.bird_pending.is_empty() and game.read_save().bird_pending.is_empty(),"acknowledgement persists once")
	game.perform_action("bird_draw")
	check(game.data.eyes==9970 and game.read_save().eyes==9970 and game.data.bird_draws==2,"paid egg charges exactly30eyes on disk")
	game.birds_ui.age = 3.2;game.perform_action("bird_done")
	game.data.bird_copies.pipoco = 9;game.data.bird_essence.pipoco = 6;game.data.bird_equipped = ""
	game.save_game();var coins = int(game.data.wallet)
	game.birds_ui.selected = 0;game.perform_action("bird_fusion");game.perform_action("bird_fuse")
	check(game.data.bird_pending.id=="fiapo" and game.data.wallet==coins-500 and game.data.bird_essence.pipoco==0,"real fusion consumes reserves and coins once")
	check(Birds.level(game.read_save(),"pipoco")==3,"fusion retains source bird power on disk")
	game.birds_ui.age = 3.2;game.perform_action("bird_done")
	if game.data.bird_equipped=="fiapo": game.perform_action("bird_equip")
	game.perform_action("bird_equip")
	check(game.data.bird_equipped=="fiapo" and game.read_save().bird_equipped=="fiapo","equip survives real save round trip")
	game.perform_action("back");game.start_run()
	check(game.runner.bird.id=="fiapo" and game.runner.bird.level>=1,"ordinary run uses selected owned companion")
	game.lab_count = 4;game.start_lab("sewer");game.capture_freeze = false
	game._physics_process(.1);var age = float(game.runner.sewer.age)
	game.perform_action("pause");game._physics_process(.5)
	check(game.screen=="pause" and game.runner.sewer.age==age,"pause freezes the sewer simulation")
	game.perform_action("resume");game._physics_process(.1)
	check(game.runner.sewer.age>age,"resume advances the same sewer trip")
	while game.runner.sewer.phase=="entry": game.runner.advance(1.0/60,false)
	game.configure_layout();game.press_at(Vector2(900,350),81);game.runner.advance(1.0/60,true);game.release_touch(81)
	check(float(game.runner.sewer.boats[0].vy)<0,"real touch routing jumps leading jet-ski")
	game.perform_action("birds_open")
	check(not game.lab_active and game.screen=="birds" and game.data.bird_equipped=="fiapo","opening birds exits lab and preserves ordinary collection")
	var r = HordeRun.new();r.start_developer("bomb",4,0,13622);r.developer_kind = "";r.power_owned = [9];r.entities.clear();r.events.clear()
	var m = r.members[0];r.add_entity("sewer_key",m.x,m.y-50)
	for i in range(5): r.advance(1.0/60,false)
	check(r.sewer.active and r.bonuses==1,"real ground pickup starts sewer chapter")
	game.set_process(false);game.queue_free();game = null
	for i in range(8): await process_frame
	preload("res://scripts/bird_art.gd").textures.clear()
	preload("res://scripts/sewer_art.gd").textures.clear()
	var report = {"checks":checks,"failures":failures,"real_disk_persistence":true,"physical_device_tested":false}
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		var file = FileAccess.open(folder+"/transactions.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("V136_TRANSACTIONS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

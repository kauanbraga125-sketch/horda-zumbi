extends SceneTree
var game
var frames = 0
var start_frame = 0
var folder = ""
var markers: Array = []
func _initialize() -> void:call_deferred("run")

func hold(seconds: float) -> void:
	for i in range(roundi(seconds*30)):
		game._physics_process(1.0/30);game._process(1.0/30);frames += 1;await process_frame

func mark(title: String,description: String,closeup: bool = false) -> void:
	markers.append({"start":frames/30.0,"title":title,"description":description,"closeup":closeup})

func street(kind: int = 0) -> void:
	game.data = MonsterCatalog.defaults();game.data.wallet = 1000000;game.data.eyes = 10000
	game.data.bird_copies = {"agourinho":3};game.data.bird_discovered = {"agourinho":true};game.data.bird_equipped_slots = ["agourinho",""];game.data.bird_equipped = "agourinho"
	game.start_run();game.intro_left = 0
	game.runner.start_developer("bomb",4,0,177);game.runner.entities.clear();game.runner.bird.configure(game.data);game.runner.next_pattern_world = 1e12
	for m in game.runner.members:m.kind = kind

func run() -> void:
	folder = OS.get_environment("HORDA_VIDEO_OUTPUT")
	if folder.is_empty():push_error("HORDA_VIDEO_OUTPUT missing");quit(1);return
	DirAccess.make_dir_recursive_absolute(folder);root.size = Vector2i(1600,720)
	var boot = load("res://boot.tscn").instantiate();root.add_child(boot);current_scene = boot
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):game = current_scene;break
	if not is_instance_valid(game):push_error("Preview game did not boot");quit(1);return
	await process_frame;await process_frame;await process_frame
	game.set_process(false);game.set_physics_process(false);game.test_mode = true;game.sound.set_enabled(true);game.sound.set_mix(game.data.audio_levels)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN);street();game._process(0);await process_frame;start_frame = Engine.get_process_frames()
	mark("Agourinho espera · a horda ainda sobrevive","Perder criaturas isoladas não ativa nem gasta o resgate.")
	await hold(.8)
	for i in range(3):
		game.runner.hit_grace = 0;game.runner.damage(0,"impact");await hold(1.1)
		if game.runner.bird.rescued:push_error("An ordinary loss consumed the rescue");quit(1);return
	mark("Última chance · só quando a última seria perdida","O portal salva a mesma criatura e aplica uma proteção breve.",true)
	game.runner.hit_grace = 0;var saved_id = int(game.runner.members[0].id);game.runner.damage(0,"impact")
	await hold(2.8)
	if game.runner.dead or game.runner.active_count()!=1 or not game.runner.bird.rescued or int(game.runner.members[0].id)!=saved_id:push_error("Final member rescue failed");quit(1);return
	street(1);game.runner.add_entity("gap",game.runner.ANCHOR-120,game.runner.FLOOR,0,520)
	mark("Queda da horda inteira · uma criatura volta","Também funciona com esqueletos, preservando um único sobrevivente.")
	await hold(6)
	if game.runner.dead or game.runner.active_count()!=1 or not game.runner.bird.rescued or game.runner.losses!=3:push_error("Whole horde pit rescue failed");quit(1);return
	var report = {"version":"0.10.77","fps":30,"native_frames":frames,"trim_start":start_frame/30.0,"duration":frames/30.0,"markers":markers,"actual_game_capture":true,"trigger":"final_member_only","max_saved_members":1,"max_rescues_per_run":1,"physical_device_tested":false}
	var file = FileAccess.open(folder+"/capture.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("VIDEO_PREVIEW ",JSON.stringify(report));game.sound.set_enabled(false);game.sound.set_process(false)
	for player in game.sound.get_children():
		if player is AudioStreamPlayer:player.stop();player.stream = null
	game.queue_free();game = null;current_scene = null
	await process_frame;await process_frame;await create_timer(.25).timeout;quit(0)

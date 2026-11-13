extends SceneTree
const Catalog = preload("res://scripts/bird_catalog.gd")
var game
var frames = 0
var start_frame = 0
var folder = ""
var markers: Array = []

func _initialize() -> void:call_deferred("run")

func hold(seconds: float) -> void:
	for i in range(roundi(seconds*30)):
		game._physics_process(1.0/30);game._process(1.0/30)
		frames += 1;await process_frame

func mark(title: String,description: String,closeup: bool = false) -> void:
	markers.append({"start":frames/30.0,"title":title,"description":description,"closeup":closeup})

func street(skeletons: bool = false,second: bool = false) -> void:
	game.data = MonsterCatalog.defaults();game.data.wallet = 1000000;game.data.eyes = 10000
	game.data.bird_copies = {"pipoco":3,"fiapo":1};game.data.bird_discovered = {"pipoco":true,"fiapo":true}
	game.data.bird_equipped_slots = ["fiapo","pipoco"] if second else ["pipoco",""]
	game.data.bird_equipped = game.data.bird_equipped_slots[0]
	game.start_run();game.intro_left = 0
	game.runner.start_developer("bomb",4,0,172);game.runner.bird.configure(game.data)
	game.runner.next_pattern_world = 1e12
	for member in game.runner.members:member.kind = 1 if skeletons else 0
	var power = game.runner.bird.companion.pipoco if second else game.runner.bird.pipoco
	power.until_spit = .8

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
	game.set_process(false);game.set_physics_process(false);game.test_mode = true
	game.sound.set_enabled(true);game.sound.set_mix(game.data.audio_levels)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	street();game._process(0);await process_frame
	start_frame = Engine.get_process_frames()
	mark("Pipoco · detalhe da animação","Enche as bochechas, cospe duas moedas e volta a bater as asas.",true)
	await hold(6.2)
	if game.runner.coins!=2:push_error("First physical pair was not collected");quit(1);return
	game.runner.bird.pipoco.until_spit = .8
	mark("Na corrida · moedas de verdade","Giro, queda em arco e quique; o contador sobe somente na coleta.")
	await hold(6.2)
	if game.runner.coins!=4:push_error("Second physical pair was not collected");quit(1);return
	street(true,true)
	mark("Também com esqueletos e no segundo ninho","Apenas aves liberadas e equipadas acompanham a horda.")
	await hold(6.2)
	if game.runner.coins!=2:push_error("Second nest physical pair was not collected");quit(1);return
	var report = {"version":"0.10.72","fps":30,"native_frames":frames,"trim_start":start_frame/30.0,"duration":frames/30.0,"markers":markers,"actual_game_capture":true,"demo_interval_shortened":true,"physical_device_tested":false}
	var file = FileAccess.open(folder+"/capture.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("VIDEO_PREVIEW ",JSON.stringify(report))
	game.sound.set_enabled(false);game.sound.set_process(false)
	for player in game.sound.get_children():
		if player is AudioStreamPlayer:player.stop();player.stream = null
	await create_timer(.15).timeout
	quit(0)

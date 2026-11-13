extends SceneTree
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
	game.data.bird_copies = {"fiapo":3,"pipoco":3};game.data.bird_discovered = {"fiapo":true,"pipoco":true}
	game.data.bird_equipped_slots = ["pipoco","fiapo"] if second else ["fiapo",""]
	game.data.bird_equipped = game.data.bird_equipped_slots[0]
	game.start_run();game.intro_left = 0
	game.runner.start_developer("bomb",4,0,173);game.runner.bird.configure(game.data);game.runner.next_pattern_world = 1e12
	for member in game.runner.members:member.kind = 1 if skeletons else 0
	var power = game.runner.bird.companion.fiapo if second else game.runner.bird.fiapo;power.until_fetch = .8
	if second:game.runner.bird.pipoco.until_spit = .8

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
	game.sound.set_enabled(true);game.sound.set_mix(game.data.audio_levels);Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	street();game._process(0);await process_frame;start_frame = Engine.get_process_frames()
	mark("Fiapo · busca, pega e carrega","Ele voa até o civil, agarra a roupa e o leva até a horda.")
	await hold(6.8)
	if game.runner.souls!=1 or game.runner.active_count()!=5:push_error("First visible rescue failed");quit(1);return
	game.runner.bird.fiapo.until_fetch = .8
	mark("De perto · balanço, queda e captura","O civil usa os quadros atuais; só entra na horda após a captura.",true)
	await hold(6.8)
	if game.runner.souls!=2 or game.runner.active_count()!=6:push_error("Second visible rescue failed");quit(1);return
	street(true,true)
	mark("Fiapo e Pipoco · os dois poderes juntos","Busca de civil e moedas funcionando com Fiapo no segundo ninho.")
	await hold(6.8)
	if game.runner.souls!=1 or game.runner.coins!=2:push_error("Companions did not finish both powers");quit(1);return
	var report = {"version":"0.10.73","fps":30,"native_frames":frames,"trim_start":start_frame/30.0,"duration":frames/30.0,"markers":markers,"actual_game_capture":true,"demo_interval_shortened":true,"new_civilian_assets":0,"physical_device_tested":false}
	var file = FileAccess.open(folder+"/capture.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("VIDEO_PREVIEW ",JSON.stringify(report));game.sound.set_enabled(false);game.sound.set_process(false)
	for player in game.sound.get_children():
		if player is AudioStreamPlayer:player.stop();player.stream = null
	await create_timer(.15).timeout;quit(0)

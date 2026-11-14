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

func street(second: bool = false) -> Dictionary:
	game.data = MonsterCatalog.defaults();game.data.wallet = 1000000;game.data.eyes = 10000
	game.data.bird_copies = {"ferrugem":3,"pipoco":3};game.data.bird_discovered = {"ferrugem":true,"pipoco":true}
	game.data.bird_equipped_slots = ["pipoco","ferrugem"] if second else ["ferrugem",""]
	game.data.bird_equipped = game.data.bird_equipped_slots[0]
	game.start_run();game.intro_left = 0
	game.runner.start_developer("bomb",4,0,175);game.runner.entities.clear();game.runner.bird.configure(game.data);game.runner.next_pattern_world = 1e12
	var bird = game.runner.bird.companion if second else game.runner.bird
	bird.ferrugem.until_shot = .8
	if second:game.runner.bird.pipoco.until_spit = .3
	return game.runner.add_entity("tank",1250,game.runner.FLOOR)

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
	var tank = street();game._process(0);await process_frame;start_frame = Engine.get_process_frames()
	mark("Ferrugem · carrega, mira e destrói","Um laser destrói o tanque inteiro, solta os passageiros e deixa destroços.")
	await hold(6.2)
	if not tank.taken or game.runner.cars!=1 or game.runner.bird.ferrugem.shots!=1:push_error("Tank destruction failed");quit(1);return
	tank = street(true)
	mark("Detalhe · lente, recuo e destroços","Ferrugem no segundo ninho; Pipoco continua soltando suas moedas.",true)
	await hold(6.2)
	if not tank.taken or game.runner.bird.companion.ferrugem.shots!=1 or game.runner.bird.pipoco.cycles!=1:push_error("Companion powers failed");quit(1);return
	street();game.runner.entities.clear();game.runner.space.begin(game.runner,true)
	for i in range(240):
		if game.runner.space.phase=="flight":break
		game._physics_process(1.0/30);game._process(1.0/30);await process_frame
	# Covered entry frames are trimmed out of the space segment below.
	markers.append({"start":frames/30.0,"source_start":(Engine.get_process_frames()-start_frame)/30.0,"title":"No espaço · uma nave por disparo","description":"A fragata perde toda a resistência; os tripulantes sobreviventes são liberados.","closeup":false})
	game.runner.space.objects.clear();game.runner.space.next_group = 1e9
	var ship = game.runner.space.battle.spawn_ship(game.runner.space,game.runner,"ghost_frigate",1160,390)
	game.runner.bird.ferrugem.until_shot = .5
	await hold(6.2)
	if not ship.taken or game.runner.space.battle.destroyed!=1 or game.runner.bird.ferrugem.shots!=1:push_error("Ship destruction failed");quit(1);return
	var report = {"version":"0.10.75","fps":30,"native_frames":frames,"trim_start":start_frame/30.0,"duration":frames/30.0,"markers":markers,"actual_game_capture":true,"demo_interval_shortened":true,"cooldown_seconds":[60,50,40],"physical_device_tested":false}
	var file = FileAccess.open(folder+"/capture.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("VIDEO_PREVIEW ",JSON.stringify(report));game.sound.set_enabled(false);game.sound.set_process(false)
	for player in game.sound.get_children():
		if player is AudioStreamPlayer:player.stop();player.stream = null
	game.queue_free();game = null;current_scene = null
	await process_frame;await process_frame;await create_timer(.25).timeout;quit(0)

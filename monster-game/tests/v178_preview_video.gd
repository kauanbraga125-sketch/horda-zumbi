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
	game.runner.start_developer("bomb",4,0,178);game.runner.entities.clear();game.runner.bird.configure(game.data);game.runner.next_pattern_world = 1e12
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
	mark("Agourinho · morte, invocação e retorno","A horda morre; a ave conjura por quase 4 segundos e uma criatura volta.")
	await hold(.9)
	for i in range(game.runner.members.size()-1,-1,-1):game.runner.remove_member(i,"impact")
	if game.runner.active_count()!=0 or not game.runner.bird.rescue_pending():push_error("The horde did not die");quit(1);return
	await hold(6.1)
	if game.runner.dead or game.runner.active_count()!=1 or game.runner.losses!=4:push_error("Delayed zombie resurrection failed");quit(1);return
	street(1);game.runner.add_entity("gap",game.runner.ANCHOR-120,game.runner.FLOOR,0,520)
	mark("Detalhe · o portal traz um esqueleto de volta","Asas em movimento, vórtice com profundidade e sons em cada etapa.",true)
	await hold(8.5)
	if game.runner.dead or game.runner.active_count()!=1 or game.runner.losses!=4:push_error("Delayed pit resurrection failed");quit(1);return
	var report = {"version":"0.10.78","fps":30,"native_frames":frames,"trim_start":start_frame/30.0,"duration":frames/30.0,"markers":markers,"actual_game_capture":true,"ritual_seconds":3.9,"return_seconds":3.35,"max_returned_creatures":1,"physical_device_tested":false}
	var file = FileAccess.open(folder+"/capture.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("VIDEO_PREVIEW ",JSON.stringify(report));game.sound.set_enabled(false);game.sound.set_process(false)
	for player in game.sound.get_children():
		if player is AudioStreamPlayer:player.stop();player.stream = null
	game.queue_free();game = null;current_scene = null
	await process_frame;await process_frame;await create_timer(.25).timeout;quit(0)

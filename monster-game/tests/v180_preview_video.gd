extends SceneTree

const FPS = 60.0
var game
var frames = 0
var markers: Array[Dictionary] = []

func _initialize() -> void:call_deferred("run")

func hold(seconds: float) -> void:
	for i in range(roundi(seconds*FPS)):
		game._physics_process(1/FPS)
		game._process(1/FPS)
		frames += 1
		await process_frame

func mark(title: String,description: String) -> void:
	markers.append({"start":frames/FPS,"title":title,"description":description})

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func run() -> void:
	var folder = OS.get_environment("HORDA_VIDEO_OUTPUT")
	if folder.is_empty():fail("HORDA_VIDEO_OUTPUT missing");return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720)
	var boot = load("res://boot.tscn").instantiate()
	root.add_child(boot)
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):
			game = current_scene
			break
	if not is_instance_valid(game):fail("Preview game did not boot");return
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.test_mode = true
	game.sound.set_enabled(true)
	game.data = MonsterCatalog.defaults()
	game.sound.set_mix(game.data.audio_levels)
	game.data.bird_copies = {"barao":1}
	game.data.bird_equipped_slots = ["barao",""]
	game.start_run()
	game.intro_left = 0
	var r = game.runner
	r.start_developer("bomb",4,0,180)
	r.next_pattern_world = 1e12
	r.bird.configure(game.data)
	var power = r.bird.barao
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	game._process(0)
	await process_frame
	var start_frame = Engine.get_process_frames()

	power.until_power = .85
	for i in range(10):r.add_entity("coin",r.ANCHOR+170+i*102,r.FLOOR-54)
	mark("MOEDAS EM DOBRO","Novas poses completas do Barão e magia dourada nas moedas.")
	await hold(9.15)
	if r.coins<=10 or r.bird.coin_multiplier()!=1:fail("Preview did not show a full Double cast");return

	var previous: int = r.coins
	power.until_power = .65
	mark("TRILHA DE MOEDAS","O voo original e a nova animação de soltar as moedas.")
	await hold(5.45)
	if r.coins!=previous+6:fail("Preview did not collect the six trail coins");return

	previous = r.coins
	r.add_entity("bomb",r.ANCHOR+625)
	r.add_entity("air_bomb",r.ANCHOR+730,r.FLOOR-173)
	power.until_power = .95
	mark("BOMBAS EM MOEDAS","O feitiço atinge as bombas, que viram moedas em um clarão dourado.")
	await hold(5.3)
	if r.losses!=0 or r.coins!=previous+2:fail("Preview did not collect both converted bombs");return

	var report = {"trim_start":start_frame/FPS,"duration":frames/FPS,"markers":markers,"coins":r.coins}
	var file = FileAccess.open(folder+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("VIDEO_PREVIEW ",JSON.stringify(report))
	game.sound.set_enabled(false)
	game.queue_free()
	await process_frame
	await process_frame
	quit(0)

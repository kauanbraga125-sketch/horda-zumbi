extends SceneTree

const Power = preload("res://scripts/toc_toc_power.gd")
const Catalog = preload("res://scripts/bird_catalog.gd")
const FPS = 60.0
const CASES = [
	{"kind":"bomb","result":"bomb","title":"BICADA NA BOMBA","description":"20% de chance • A bomba estoura no impacto."},
	{"kind":"car","result":"vehicle","title":"CARRO VIRADO","description":"2% de chance • A bicada vira o carro e liberta os passageiros."},
	{"kind":"air_bomb","result":"miss","title":"A BICADA FALHOU","description":"O Toc-Toc recua atordoado e a bomba segue intacta."},
]

var game
var frames = 0
var markers: Array[Dictionary] = []
var contact_ok = false
var wake_seen = false

func _initialize() -> void:
	call_deferred("run")

func fixture_seed(kind: String,success: bool) -> int:
	var rng = RandomNumberGenerator.new()
	var chance = Power.VEHICLE_CHANCE if kind=="car" else Power.BOMB_CHANCE
	for seed_value in range(181,10000):
		rng.seed = seed_value ^ Power.SEED_SALT
		if (rng.randf()<chance)==success:return seed_value
	return 0

func hold(seconds: float) -> void:
	for i in range(roundi(seconds*FPS)):
		var bird = game.runner.bird
		var attacks_before = bird.attacks
		game._physics_process(1/FPS)
		game._process(1/FPS)
		wake_seen = wake_seen or game.effects.particles.any(func(p):return p.kind=="peck_streak")
		if bird.attacks>attacks_before:
			markers.back().contact = frames/FPS
			contact_ok = bird.toc_toc.phase=="peck" and floori(bird.toc_toc.age*Power.Art.FPS)==8
			contact_ok = contact_ok and game.effects.particles.any(func(p):return p.kind=="peck_burst")
		frames += 1
		await process_frame

func fixture(data: Dictionary,seed_value: int) -> void:
	game.data = data.duplicate(true)
	game.start_run()
	game.intro_left = 0
	var runner = game.runner
	runner.start_developer("toc_toc",4,0,seed_value)
	runner.next_pattern_world = 1e12
	runner.bird.configure(game.data)
	contact_ok = false
	wake_seen = false

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func run() -> void:
	var folder = OS.get_environment("HORDA_VIDEO_OUTPUT")
	if folder.is_empty():fail("HORDA_VIDEO_OUTPUT missing");return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720)
	root.add_child(load("res://boot.tscn").instantiate())
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
	var data = MonsterCatalog.defaults()
	game.sound.set_mix(data.audio_levels)
	data.bird_copies = {"toc_toc":1}
	if not Catalog.equip(data,"toc_toc",0):fail("Toc-Toc did not equip");return
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	var start_frame = Engine.get_process_frames()

	for scene in CASES:
		var success = scene.result!="miss"
		fixture(data,fixture_seed(scene.kind,success))
		markers.append({"title":scene.title,"description":scene.description,"start":frames/FPS})
		await hold(.80)
		var r = game.runner
		var height = r.FLOOR-170 if scene.kind=="air_bomb" else r.FLOOR
		var target = r.add_entity(scene.kind,r.ANCHOR+629,height)
		await hold(2.80)
		if r.bird.attacks!=1 or not contact_ok or not wake_seen:
			fail("Expected one animated contact and visible wake for "+scene.result);return
		if bool(target.taken)!=success or r.losses!=0:
			fail("Target or horde state incorrect for "+scene.result);return
		if scene.result=="bomb" and r.mission_stats.bombs_broken!=1:
			fail("Bomb did not count toward the mission");return
		if scene.result=="vehicle" and (r.cars!=1 or r.active_count()<=4):
			fail("Car did not flip and rescue passengers");return
		if scene.result=="miss" and not target.has("toc_toc_hit_at"):
			fail("The failed peck did not leave a recoil mark");return

	var report = {"trim_start":start_frame/FPS,"duration":frames/FPS,"markers":markers}
	var file = FileAccess.open(folder+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("TOC_TOC_PREVIEW_OK ",JSON.stringify(report))
	game.sound.set_enabled(false)
	game.queue_free()
	await process_frame
	quit(0)

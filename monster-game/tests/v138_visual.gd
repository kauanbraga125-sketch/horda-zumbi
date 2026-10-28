extends "res://tests/v134_visual.gd"

func setup(count: int = 6,wear: bool = false) -> void:
	game.lab_count = count;game.start_lab("sewer");game.runner.sewer.encounter.pending = false
	game.runner.sewer.begin(game.runner,true)
	for i in range(game.runner.members.size()):
		var m = game.runner.members[i];m.kind = i%2
		m.cosmetics_0 = ["z_plumber"] if wear else []
		m.cosmetics_1 = ["s_ice"] if wear else []
	game.lab_active = false;game.toast_left = 0

func calm() -> void:
	var s = game.runner.sewer;s.next_encounter = 1e6;s.objects.clear();s.life.next_scene = 1e6;s.life.people.clear()

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720);game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults();game.data.wallet = 1000000;game.data.eyes = 10000
	setup();step(4.8);calm();await snap("01_duplas_novas")
	game.runner.sewer.request_duck(game.runner);step(.72);await snap("02_abaixando")
	setup(6,true);step(4.8);calm();await snap("03_duplas_acessorios")
	game.runner.sewer.pressure = .82;await snap("04_enchente_grande")
	setup();step(4.8);calm();var s = game.runner.sewer
	for i in range(3): s.add_object("rescue",850+i*145,s.WATER-35,{"variant":i})
	await snap("05_novos_sobreviventes")
	s.objects.clear();s.life.next_scene = 0;step(2.4);await snap("06_perseguicao")
	s.spawn(game.runner,"rotor");var e = s.objects.filter(func(item):return item.kind=="rotor")[0];e.x = 1030;await snap("07_bomba_giratoria")
	setup();calm();step(.30);await snap("08_corrida_porto")
	step(.82);await snap("09_embarque")
	step(1.85);await snap("10_salto_entrada")
	step(1.55);await snap("11_dentro_esgoto")
	setup();step(4.8);calm();s = game.runner.sewer;s.spawn(game.runner,"pipe")
	e = s.objects.filter(func(item):return item.kind=="pipe")[0];e.x = 1040;e.age = 2;await snap("12_cano_baixo")
	s.objects.clear();s.left = .001;step(1.3);await snap("13_saida_aprovada")
	step(2.1);await snap("14_corrida_retornada")
	var out = FileAccess.open(folder+"/visual.json",FileAccess.WRITE);out.store_string(JSON.stringify({"version":"0.10.38","native_captures":shots,"physical_device_tested":false},"  "));out.close()
	game.set_process(false);game.queue_free();game = null
	for i in range(8): await process_frame
	preload("res://scripts/bird_art.gd").textures.clear();preload("res://scripts/sewer_art.gd").textures.clear()
	print("V138_VISUAL_OK ",shots);quit()

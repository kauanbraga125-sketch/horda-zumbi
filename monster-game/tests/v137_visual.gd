extends "res://tests/v134_visual.gd"
func sewer(count: int = 10) -> void:
	game.lab_count = count;game.lab_stage = 0;game.start_lab("sewer")
	for i in range(game.runner.members.size()):
		var m = game.runner.members[i];m.kind = i%2
		m.cosmetics_0 = ["z_plumber"] if i%4==0 else []
		m.cosmetics_1 = ["s_ice"] if i%4==1 else []
	step(2.4);game.lab_active = false;game.toast_left = 0
	game.runner.sewer.next_encounter = 1e6;game.runner.sewer.objects.clear();game.runner.sewer.life.next_scene = 1e6;game.runner.sewer.life.people.clear()
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720);game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults();game.data.wallet = 1000000;game.data.eyes = 10000
	sewer(6);await snap("01_duplas_sentadas")
	sewer(10);game.runner.sewer.pressure = .76;step(.2);await snap("02_onda_proxima")
	var s = game.runner.sewer;s.spawn(game.runner,"pipe")
	var e = s.objects.filter(func(item):return item.kind=="pipe")[0];e.x = 1000;e.age = 1
	await snap("03_cano_preso_ao_teto")
	sewer(6);s = game.runner.sewer;s.spawn(game.runner,"gate")
	e = s.objects.filter(func(item):return item.kind=="gate")[0];e.x = 1060;e.age = .2;await snap("04_comporta_baixando")
	e.age = 1;await snap("05_comporta_ancorada")
	sewer(6);s = game.runner.sewer
	for i in range(3): s.add_object("rescue",780+i*170,s.WATER-40,{"variant":i})
	await snap("06_tres_sobreviventes")
	s.objects.clear();s.life.next_scene = 0;step(2.2);await snap("07_fuga_na_passarela")
	s.life.people.append({"x":1000,"age":0.0,"variant":0,"fall":false,"drops":true,"taken":false});step(.35);await snap("08_queda_da_passarela")
	sewer(10);s = game.runner.sewer;s.left = .001;step(.52);await snap("09_saida_do_esgoto")
	step(.85);await snap("10_arco_do_nosso_mapa")
	step(1.35);await snap("11_pouso_no_nosso_mapa")
	step(.48);await snap("12_corrida_retornada")
	sewer(10);s = game.runner.sewer;s.pressure = .76;root.size = Vector2i(960,720);await process_frame;await snap("13_tablet")
	root.size = Vector2i(1800,810);await process_frame;await snap("14_tela_larga")
	var out = FileAccess.open(folder+"/visual.json",FileAccess.WRITE);out.store_string(JSON.stringify({"version":"0.10.37","native_captures":shots,"physical_device_tested":false},"  "));out.close()
	game.set_process(false);game.queue_free();game = null
	for i in range(8): await process_frame
	preload("res://scripts/bird_art.gd").textures.clear();preload("res://scripts/sewer_art.gd").textures.clear()
	print("V137_VISUAL_OK ",shots);quit()

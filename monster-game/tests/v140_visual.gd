extends "res://tests/v134_visual.gd"
func setup(wear: bool = true,count: int = 6) -> void:
	game.lab_count = count;game.start_lab("sewer");game.runner.sewer.encounter.pending = false
	assert(game.runner.sewer.begin(game.runner,true));game.lab_active = false;game.toast_left = 0
	for i in range(game.runner.members.size()):
		var m = game.runner.members[i];m.kind = i%2
		m.cosmetics_0 = ["z_plumber"] if wear and i==0 else []
		m.cosmetics_1 = ["s_ice"] if wear and i==1 else []
	game.runner.sewer.next_encounter = 1e6;game.runner.sewer.life.next_scene = 1e6
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720);game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false);game.data = MonsterCatalog.defaults()
	setup();step(.4);await snap("01_rua_buraco")
	step(.8);await snap("02_queda_inicio");step(.8);await snap("03_descida");step(.8);await snap("04_chegada_jet");step(.8);await snap("05_embarcando");step(1.8);await snap("06_pilotando")
	var s = game.runner.sewer;s.request_duck(game.runner);step(.4);await snap("07_abaixando");step(.4);await snap("08_abaixado");step(.6)
	for i in range(3):
		s.objects.clear();s.add_object("fugitive",1060,s.WATER-24,{"variant":i});await snap("09_fugitivo_%d"%i)
	s.objects.clear();s.add_object("fugitive",s.boats[0].x+60,s.WATER-24,{"variant":2})
	step(.05);await snap("10_captura_jet");step(.28);await snap("11_jet_virando");step(.32);await snap("12_captura_humanos");step(.5);await snap("13_recrutados")
	s.objects.clear();s.add_object("rotor",1030,s.WATER-35);s.add_object("collapse",1220,s.WATER-50,{"age":2,"landed":true});await snap("14_ancorados")
	s.objects.clear();s.add_object("rubble",1050,s.WATER-35);await snap("15_naufragio")
	s.objects.clear();s.add_object("gate",1060,s.WATER-90,{"age":2});await snap("16_comporta")
	s.objects.clear();s.life.next_scene = 0;step(2.7);await snap("17_corridas_fundo")
	s.left = .001;step(.7);await snap("18_rampa_inicio");step(.7);await snap("19_rampa_salto");step(.8);await snap("20_subindo");step(.8);await snap("21_ceu");step(.8);await snap("22_descendo");step(.9);await snap("23_pouso");step(1.8);await snap("24_volta_corrida")
	assert(s.completed==1 and not s.active)
	for shape in [Vector2i(1800,810),Vector2i(1280,960)]:
		root.size = shape;game.configure_layout();setup(true,8);step(5.5);await snap("25_wide" if shape.x==1800 else "26_tablet")
	var out = FileAccess.open(folder+"/visual.json",FileAccess.WRITE);out.store_string(JSON.stringify({"version":"0.10.40","native_captures":shots,"physical_device_tested":false}));out.close()
	game.queue_free();game = null
	for i in range(8): await process_frame
	preload("res://scripts/sewer_art.gd").textures.clear();print("V140_VISUAL_OK ",shots);quit()

extends "res://tests/v134_visual.gd"
const Birds = preload("res://scripts/bird_catalog.gd")
func flight(count: int = 8,cosmetics: bool = false) -> void:
	game.data = MonsterCatalog.defaults();game.lab_count = count;game.lab_stage = 0;game.start_lab("space")
	for i in range(game.runner.members.size()):
		var m = game.runner.members[i];m.kind = i%2
		m.cosmetics_0 = ["z_plumber"] if cosmetics and i%3==0 else []
		m.cosmetics_1 = ["s_ice"] if cosmetics and i%3==1 else []
	step(3.65);game.runner.space.objects.clear();game.runner.space.next_group = 1e6
	game.runner.space.visual.current.clear();game.runner.space.visual.notices.clear();game.runner.space.visual.controls_left = 0;game.toast_left = 0
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720);game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false)
	game.data = MonsterCatalog.defaults();game.data.wallet = 1000000;game.data.eyes = 10000
	game.change_screen("home");await snap("01_inicio_r36")
	game.perform_action("birds_open");await snap("02_ninho_desconhecido")
	game.perform_action("bird_draw");game.birds_ui.age = .75;await snap("03_ovo_fechado")
	game.birds_ui.age = 1.9;await snap("04_ovo_rachando")
	game.birds_ui.age = 3.2;await snap("05_revelacao_real")
	game.perform_action("bird_done")
	for id in Birds.IDS: game.data.bird_copies[id] = 3;game.data.bird_essence[id] = 6
	for i in range(5):
		game.birds_ui.selected = i;game.ui_time = i+.3;await snap("06_ave_"+Birds.IDS[i])
	game.birds_ui.selected = 1;game.perform_action("bird_fusion");await snap("07_fusao")
	game.perform_action("bird_fuse");game.birds_ui.age = 3.2;await snap("08_resultado_fusao")
	game.perform_action("bird_done");game.perform_action("back")
	game.lab_count = 12;game.start_lab("space")
	step(.45);await snap("09_nave_chegando");step(.55);await snap("10_feixe_puxando");step(.42);await snap("11_horda_abduzida");step(1.36);await snap("12_liberando_em_orbita")
	flight(12,true);game.runner.space.routes.start(game.runner.space,game.runner,"rescue");step(1.9);await snap("13_perseguicao_espacial")
	flight(12,true);var s = game.runner.space;s.altitude = 1000
	var cargo = s.battle.spawn_ship(s,game.runner,"cargo",1110,335);cargo.distress = true;cargo.speed = .1;cargo.shot = 99
	step(2.7);await snap("14_capsula_ejetada")
	game.lab_count = 9;game.start_lab("sewer");game.runner.active_cosmetics = ["z_plumber","s_ice"]
	step(2.4);game.toast_left = 0;await snap("15_esgoto_embarque")
	step(1.5);await snap("16_esgoto_desafio")
	game.runner.jump();step(.25);await snap("17_salto_jet_ski")
	step(.6);game.runner.sewer.add_object("rescue",920,515);game.runner.sewer.add_object("barrel",1120,520);await snap("18_resgate_esgoto")
	game.runner.sewer.left = .001;step(.60);await snap("19_rampa_de_saida");step(.8);await snap("20_salto_para_rua");step(1.8);await snap("21_corrida_retomada")
	game.leave_lab();game.change_screen("home");game.perform_action("birds_open")
	root.size = Vector2i(960,720);await process_frame;await snap("22_ninho_tablet")
	root.size = Vector2i(1800,810);await process_frame;await snap("23_ninho_tela_larga")
	var out = FileAccess.open(folder+"/visual.json",FileAccess.WRITE);out.store_string(JSON.stringify({"version":"0.10.36","native_captures":shots,"physical_device_tested":false},"  "));out.close()
	game.set_process(false);game.queue_free();game = null
	for i in range(8): await process_frame
	preload("res://scripts/bird_art.gd").textures.clear()
	print("V136_VISUAL_OK ",shots);quit()

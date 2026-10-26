extends SceneTree
var game
var folder = ""
const STEP = 1.0/60.0
func _initialize() -> void: call_deferred("run")
func step(seconds: float,held: bool = false) -> void:
	for i in range(roundi(seconds*60)):
		game.runner.advance(STEP,held);game.update_camera(STEP);game.configure_layout();game.consume_run_events();game.ui_time += STEP
		game.toast_left = maxf(0,game.toast_left-STEP);game.perfect_left = maxf(0,game.perfect_left-STEP)
func snap(name: String) -> void:
	game.configure_layout();game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw();game.market_canvas.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK);print("ADVENTURE_CAPTURE ",name)
func flight() -> void:
	game.lab_count = 8;game.lab_stage = 0;game.start_lab("space");game.runner.space.manual_control = true;step(2.9)
	game.runner.space.objects.clear();game.runner.space.next_group = 1e6;game.toast_left = 0
	assert(game.runner.space.phase=="flight")
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720);game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_physics_process(false);game.capture_freeze = true;game.data.wallet = 1000000;game.data.eyes = 10000
	game.lab_count = 4;game.lab_stage = 0;game.start_lab("harvester");game.toast_left = 0;step(1.2);await snap("01_cacador_carregando")
	step(.6);await snap("02_cacador_soltando_civil");step(.8);await snap("03_civil_capturado")
	game.start_lab("spectral");game.toast_left = 0;step(.7);await snap("04_manto_espectral")
	game.runner.blessings.reset();game.runner.jump();step(.3,true);await snap("05_salto_quatro")
	flight();var s = game.runner.space
	s.battle.spawn_ship(s,game.runner,"tour_bus",695,315);s.battle.spawn_ship(s,game.runner,"cargo",1055,445)
	s.add_object("meteor",865,530,{"age":.4});s.add_object("astronaut",590,465,{"age":.2});s.add_object("drone",985,280)
	for i in range(6): s.add_object("coin",480+i*58,365-sin(i*.7)*30)
	s.charge = 78;await snap("06_orbita_com_veiculos")
	var dash_button = game.buttons.filter(func(b):return b.action=="space_dash")
	assert(dash_button.size()==1);game.press_at(dash_button[0].rect.get_center(),3);game.release_touch(3);assert(s.dash_left>0)
	var touch = InputEventScreenTouch.new();touch.index = 4;touch.pressed = true;touch.position = Vector2(500,500);game._input(touch)
	var drag = InputEventScreenDrag.new();drag.index = 4;drag.position = Vector2(500,400);drag.relative = Vector2(0,-100);var old_aim = s.aim_y;game._input(drag);assert(s.aim_y<old_aim)
	game.release_touch(4)
	s.altitude = 2200;s.last_zone = 2;s.objects.clear();s.battle.spawn_ship(s,game.runner,"saucer",720,335);s.battle.spawn_ship(s,game.runner,"fighter",1070,440)
	s.battle.give_power(s,game.runner,7);s.add_object("parasite",900,520,{"age":.4,"state":"attack"});s.add_object("orbital_power",600,480)
	await snap("07_simbionte_ninho")
	s.altitude = 3400;s.last_zone = 3;s.objects.clear();s.battle.spawn_ship(s,game.runner,"ghost_frigate",860,410);s.add_object("monolith",1100,290)
	s.battle.give_power(s,game.runner,8);await snap("08_fragata_escudo")
	s.charge = 100;step(.2);await snap("09_horda_carrega_impulso");step(.5);await snap("10_horda_impulso")
	flight();s = game.runner.space;s.battle.pilot_kind = "tour_bus";s.battle.pilot_left = 7;s.battle.pilot_hp = 3
	await snap("11_nave_pilotada")
	game.perfect_left = 1.5;await snap("12_perfect")
	root.size = Vector2i(960,720);await process_frame;await snap("13_tablet_espaco")
	root.size = Vector2i(1800,810);await process_frame;await snap("14_tela_larga_espaco")
	root.size = Vector2i(1280,720);await process_frame
	game.lab_count = 41;game.start_lab("space");step(2.9);game.runner.space.next_group = 1e6;game.runner.space.objects.clear();game.runner.space.left = .001
	step(1.3);await snap("15_reentrada_41");step(1.2);await snap("16_pouso_41")
	game.leave_lab();game.data.power_owned = [2,3,4,5,6,7,8];game.data.power_levels.creeper_rate = 3
	game.open_market(1);game.toast_left = 0;await process_frame;await snap("17_mercado_poderes")
	game.change_screen("prepare");game.data.prepared_items = ["coin_magnet","power_harvester"];game.prepare_ui.sync_horde(game)
	game.prepare_ui.feedback.trigger("power_harvester",Vector2(500,300),4);game.prepare_ui.update(game,.75);await snap("18_preparacao_consumiveis")
	game.prepare_ui.page = 2;await snap("18b_ultima_pagina_preparacao")
	game.change_screen("developer");await snap("19_modo_desenvolvedor")
	game.sound.set_enabled(false);game.set_process(false);game.queue_free();game = null;for i in range(6): await process_frame
	print("ADVENTURE_VISUAL_OK 19 native captures");quit()

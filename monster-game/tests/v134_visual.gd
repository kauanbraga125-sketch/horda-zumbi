extends SceneTree
var game
var folder = ""
var shots = 0
const STEP = 1.0/60.0
func _initialize() -> void: call_deferred("run")
func step(seconds: float) -> void:
	for i in range(roundi(seconds*60)):
		game.runner.advance(STEP,false);game.update_camera(STEP);game.configure_layout();game.consume_run_events();game.update_run_visuals(STEP);game.ui_time += STEP
		game.toast_left = maxf(0,game.toast_left-STEP);game.perfect_left = maxf(0,game.perfect_left-STEP)
func snap(name: String) -> void:
	game.configure_layout();game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	assert(image.save_png(folder+"/"+name+".png")==OK)
	shots += 1;print("V134_CAPTURE ",name)
func flight(count: int = 8,cosmetics: bool = false) -> void:
	game.data = MonsterCatalog.defaults();game.lab_count = count;game.lab_stage = 0;game.start_lab("space")
	game.runner.active_cosmetics.clear()
	for i in range(game.runner.members.size()):
		var m = game.runner.members[i]
		m.kind = i%2 if cosmetics else 0
		m["cosmetics_0"] = ["z_plumber"] if cosmetics and i%3==0 else []
		m["cosmetics_1"] = ["s_ice"] if cosmetics and i%3==1 else []
	step(2.9);game.runner.space.objects.clear();game.runner.space.next_group = 1e6
	game.runner.space.visual.current.clear();game.runner.space.visual.notices.clear();game.runner.space.visual.controls_left = 0;game.toast_left = 0
func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720);game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.test_mode = true;game.capture_freeze = true;game.set_physics_process(false);game.sound.set_enabled(false)
	flight(4);await snap("01_horda_quatro")
	var s = game.runner.space
	s.charge = 78;s.battle.spawn_ship(s,game.runner,"tour_bus",850,330)
	var row = game.runner.new_coin_row(5)
	for i in range(5): s.add_object("coin",560+i*58,490-sin(i*.7)*18,{"coin_row":row})
	s.add_object("astronaut",800,480);await snap("02_rota_clara")
	flight(8,true);await snap("03_horda_cosmeticos")
	flight(20,true);await snap("04_horda_vinte")
	flight(41,true);await snap("05_horda_quarenta_um")
	flight(88,true);await snap("06_horda_oitenta_oito")
	flight(8,true);s = game.runner.space;s.battle.pilot_kind = "tour_bus";s.battle.pilot_left = 7;s.battle.pilot_hp = 3;await snap("07_onibus_cabine")
	s.battle.pilot_kind = "fighter";await snap("08_caca_cabine")
	flight(8);s = game.runner.space;s.add_object("beam",1000,340,{"speed":0.0,"length":730.0,"contacts":{},"hit_at":-10.0})
	step(.5);await snap("09_laser_aviso");step(.8);await snap("10_laser_disparo")
	flight(8,true);s = game.runner.space;s.battle.give_power(s,game.runner,8);step(.15);await snap("11_escudo_formacao")
	s.visual.current.clear();s.visual.notices.clear();game.runner.events.append({"type":"perfect","x":340,"y":400});game.consume_run_events();await snap("12_perfect")
	step(1.7);s.charge = 100;s.boost(game.runner);step(.15);await snap("13_impulso_preparo");step(.5);await snap("14_impulso_lancamento")
	flight(8,true);s = game.runner.space;s.altitude = 3400;s.last_zone = 3
	s.add_object("vortex",960,355,{"speed":0.0});s.add_object("parasite",770,480);s.add_object("egg",1130,510);s.battle.give_power(s,game.runner,7)
	step(.2);await snap("15_regiao_alienigena")
	game.lab_count = 8;game.start_lab("space");game.runner.active_cosmetics.clear();step(.45);await snap("16_subida_terra")
	step(.8);await snap("17_passagem_nuvens");step(1.0);await snap("18_subida_orbita")
	step(.6);s = game.runner.space;s.objects.clear();s.next_group = 1e6;s.left = .001;step(.45);await snap("19_retorno_espaco")
	step(1.35);await snap("20_retorno_terra");step(.7);await snap("21_corrida_retomada")
	flight(8,true);s = game.runner.space
	s.battle.pilot_kind = "tour_bus";s.battle.pilot_left = 7;s.battle.pilot_hp = 3
	root.size = Vector2i(960,720);await process_frame;await snap("22_tablet")
	root.size = Vector2i(1800,810);await process_frame;await snap("23_tela_larga")
	root.size = Vector2i(1280,720);await process_frame
	# Actual authored patterns, actual touch input. No scripted invulnerability or instant collection.
	flight(20,true);s = game.runner.space;s.next_group = 0;s.left = 30
	DirAccess.make_dir_recursive_absolute(folder+"/motion")
	var touch = InputEventScreenTouch.new();touch.index = 42;touch.position = Vector2(350,420);touch.pressed = true;game._input(touch)
	var samples: Array = []
	for frame in range(340):
		if s.phase=="flight" and not game.runner.dead:
			var goal = Vector2(435,405);var nearest = INF
			for e in s.objects:
				if e.taken or e.x<s.x-15 or e.x>s.x+590: continue
				if e.kind in ["gate","exit"]:
					if e.x<nearest: nearest = e.x;goal = Vector2(440,float(e.y)+s.member_height(game.runner)*.5)
				elif e.kind in ["astronaut","coin","core","alien_power","orbital_power"] and e.x<nearest:
					nearest = e.x;goal = Vector2(440,float(e.y)+s.member_height(game.runner)*.5)
				elif s.battle.SHIPS.has(e.kind) and (not bool(e.get("counter",false)) or bool(e.get("core_open",false))):
					if e.x<nearest:
						nearest = e.x;goal = Vector2(435,float(e.y)+s.member_height(game.runner)*.5)
						if e.x-s.x<235 and absf(e.y-(s.y-s.member_height(game.runner)*.5))<65: game.perform_action("space_dash")
			var delta = (goal-Vector2(s.aim_x,s.aim_y)).limit_length(42)
			var drag = InputEventScreenDrag.new();drag.index = 42;drag.position = Vector2(350,420);drag.relative = delta*game.camera_zoom
			game._input(drag)
		step(.1)
		game.configure_layout();game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(folder+"/motion/frame-%03d.png" % frame)==OK)
		if frame in [29,69,119,169,219,269,309,339]:
			await snap("24_partida_%03d" % frame)
			samples.append({"frame":frame,"members":game.runner.active_count(),"souls":game.runner.souls,"charge":s.charge,"phase":s.phase,"x":s.x,"y":s.y})
	var natural = s.routes.history.duplicate(true)
	flight(20,true);s = game.runner.space;s.routes.start(s,game.runner,"gates");step(1.8);await snap("25_passagem_nova")
	flight(20,true);s = game.runner.space;s.altitude = 2150;s.routes.start(s,game.runner,"counterattack");step(.8);await snap("26_mira_alienigena")
	step(1.0);await snap("27_nucleo_exposto")
	flight(20,true);s = game.runner.space;s.charge = 100;s.add_object("exit",850,350,{"speed":0.0});step(.1);await snap("28_portal_proximo_setor")
	var summary = {"version":"0.10.34","native_captures":shots,"motion_frames":340,"natural_encounters":natural,"samples":samples,"physical_device_tested":false}
	var out = FileAccess.open(folder+"/visual.json",FileAccess.WRITE);out.store_string(JSON.stringify(summary,"  "));out.close()
	game.sound.set_enabled(false);game.set_process(false);game.queue_free();game = null
	for i in range(8): await process_frame
	print("V134_VISUAL_OK ",shots," shots + 340 motion frames");quit()

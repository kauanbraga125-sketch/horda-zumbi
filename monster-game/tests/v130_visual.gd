extends SceneTree

var game
var folder = ""

func _initialize() -> void: call_deferred("run")

func step(seconds: float, held: bool = false) -> void:
	for i in range(roundi(seconds * 60)):
		game.update_camera(1.0/60.0);game.configure_layout()
		game.runner.advance(1.0/60.0,held)
		game.consume_run_events()
		game.toast_left = maxf(0,game.toast_left - 1.0/60.0)
	game.ui_time = game.runner.elapsed

func snap(name: String) -> void:
	game.configure_layout();game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var error = image.save_png(folder + "/" + name + ".png")
	assert(error == OK)
	print("SPACE_CAPTURE ",name)

func populate() -> void:
	var s = game.runner.space;s.objects.clear()
	for i in range(8): s.add_object("coin",440 + i * 57,350 - sin(i * 0.5) * 48,{"speed":0.0})
	s.add_object("astronaut",820,345,{"speed":0.0,"age":0.35})
	s.add_object("meteor",750,535,{"speed":0.0,"variant":0,"age":1.1})
	s.add_object("satellite",1040,470,{"speed":0.0,"age":0.8})
	s.add_object("energy",570,405,{"speed":0.0})
	if s.altitude > 1900:
		s.add_object("parasite",965,280,{"speed":0.0,"state":"attack","age":0.3})
		s.add_object("egg",620,515,{"speed":0.0,"state":"open"})
	if s.altitude > 3100:
		s.add_object("ghost_ship",860,570,{"speed":0.0,"age":0.8})
		s.add_object("monolith",1100,350,{"speed":0.0})

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_physics_process(false);game.capture_freeze = true
	game.lab_count = 6;game.lab_stage = 2;game.start_lab("space")
	for i in range(game.runner.members.size()):
		var m = game.runner.members[i]
		if int(m.kind) == 1: m.cosmetics_1 = ["s_ice"] if i == 1 else ["s_silver"]
	step(1.1);await snap("01_subida")
	step(4.0,true);game.runner.space.y = 430;step(.5,false)
	populate();await snap("02_orbita")
	game.runner.space.altitude = 1400;game.runner.space.last_zone = 1;game.runner.space.age = 18
	populate();await snap("03_cemiterio_orbital")
	game.runner.space.altitude = 2250;game.runner.space.last_zone = 2;game.runner.space.age = 29
	populate();await snap("04_ninho_alienigena")
	game.runner.space.altitude = 3650;game.runner.space.last_zone = 3;game.runner.space.age = 48;game.runner.space.duration = 60;game.runner.space.left = 12
	populate();await snap("05_buraco_negro")
	game.change_screen("pause");await snap("06_pausa_espacial");game.change_screen("run")
	root.size = Vector2i(1800,810);await process_frame;game.configure_layout();await snap("07_tela_larga")
	root.size = Vector2i(960,720);await process_frame;game.configure_layout();await snap("08_tablet")
	root.size = Vector2i(1280,720);await process_frame;game.configure_layout()
	game.runner.space.left = 0.001;step(1.85);await snap("09_reentrada")
	step(1.0);await snap("10_pouso_e_tuneis")
	game.runner.space.active = false;game.runner.entities.clear()
	game.runner.add_entity("space_brain",730,HordeRun.FLOOR - 66)
	await snap("11_item_no_chao")
	game.leave_lab();game.data.wallet = 1000000;game.data.power_levels.space_time = 3
	game.toast_left = 0;game.open_market(1);await process_frame;await snap("12_mercado")
	game.change_screen("developer");await snap("13_laboratorio")
	game.sound.set_enabled(false);game.set_process(false);game.queue_free();game = null
	for i in range(8): await process_frame
	print("SPACE_VISUAL_OK 13 actual engine captures")
	quit()

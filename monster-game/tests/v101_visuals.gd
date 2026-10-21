extends SceneTree
var game
var folder = ""

func _initialize() -> void: call_deferred("preview")

func snap(name: String, delay: float = 0.06) -> void:
	game.queue_redraw();game.world_canvas.queue_redraw();game.foreground_canvas.queue_redraw()
	await create_timer(delay).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
	print("V101_SCREEN ",name)

func fresh() -> HordeRun:
	var run = HordeRun.new();run.start(MonsterCatalog.defaults().levels,4101)
	run.entities.clear();run.events.clear();run.next_segment = 99999
	return run

func preview() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if folder.is_empty(): folder = ProjectSettings.globalize_path("res://../validation")
	game = load("res://main.tscn").instantiate();root.add_child(game)
	game.test_mode = true;game.set_physics_process(false)
	game.data = MonsterCatalog.defaults();game.data.wallet = 6543;game.data.eyes = 32
	game.data.level_souls = 33;game.hub.shown_xp = 33;game.hub.shown_level = 1
	game.runner = fresh();game.end_delay = -1
	for item in HordeMeta.OBJECTS: game.data.stock[item.id] = 2
	game.change_screen("home");await snap("Inicio")
	game.market.open(0);game.change_screen("market");await snap("Objetos")
	game.market.scroll = 400;await snap("Objetos-Poderes")
	game.market.open(2);await snap("Acessorios")
	game.change_screen("prepare")
	for id in ["power_mask", "bonus_time", "power_shield"]: game.perform_action("select_object_" + id)
	await snap("Preparacao")
	for i in range(4):
		game.data.player_level = i+1;game.data.level_souls = 33
		game.hub.shown_level = i+1;game.hub.shown_xp = HordeProgress.level_target(i+1)*0.6
		game.change_screen("missions");await snap("Recipiente-"+str(i+1))
	game.data.player_level = 150;game.hub.shown_level = 150
	game.change_screen("book");await snap("Livro-Fechado",0.02)
	await snap("Livro-Abrindo",0.35);await snap("Livro-Aberto",0.8)
	game.hub.name_edit.text = "Kauan"
	game.hub.signature_points = [{"x":0.10,"y":0.72,"new":true},{"x":0.14,"y":0.18,"new":false},{"x":0.12,"y":0.48,"new":false},{"x":0.28,"y":0.24,"new":false},{"x":0.16,"y":0.50,"new":false},{"x":0.32,"y":0.74,"new":false},{"x":0.46,"y":0.42,"new":false},{"x":0.56,"y":0.72,"new":false},{"x":0.69,"y":0.45,"new":false},{"x":0.84,"y":0.65,"new":false}]
	game.hub.action(game,"book_sign");await snap("Livro-Assinado")
	var rng = RandomNumberGenerator.new();rng.seed = 441
	HordeMeta.add_grave_pair(game.data,rng)
	game.data.graves[0].rewards = [{"type":"coins","amount":5000,"label":"TESOURO! 5000 MOEDAS"},{"type":"object","id":"power_mask","amount":1,"label":"MÁSCARA DE EMERGÊNCIA"}]
	game.change_screen("graves");await snap("Lapides-Fechadas")
	var rect = game.hub.clean_rect(game.hub.grave_rects(game)[0])
	game.hub.brush_down = true;game.hub.brush_last = rect.position
	for row in range(6):
		for col in range(12): game.hub.brush(game,rect.position+(Vector2(col,row)+Vector2.ONE*.5)*rect.size/Vector2(12,16))
	await snap("Lapide-Limpando")
	for row in range(6,16):
		for col in range(12): game.hub.brush(game,rect.position+(Vector2(col,row)+Vector2.ONE*.5)*rect.size/Vector2(12,16))
	game.hub.brush_down = false;await snap("Lapide-Premio")
	game.data.player_level = 1;game.data.equipped_hat = "sobrevivente"
	game.toast_left = 0
	game.hub.progress_notice_left = 0;game.runner = fresh()
	for i in range(4): game.runner.add_member(0,false)
	var enemy = game.runner.add_entity("soldier",HordeRun.ANCHOR+52)
	game.runner.begin_capture(enemy,game.runner.members[0]);game.change_screen("run")
	for i in range(8):
		enemy.capture_left = enemy.capture_duration*(1.0-(i+0.1)/8.0)
		await snap("Soldado-Captura-"+str(i+1))
	enemy.state = "normal";enemy.x = 830;enemy.y = HordeRun.FLOOR;game.data.equipped_hat = "bruxa"
	for weapon in ["sniper_in","bazooka_in"]:
		enemy.weapon = weapon
		for i in range(4):
			enemy.weapon_t = 0.32*(i+0.1)/4.0
			await snap("Soldado-"+weapon+"-"+str(i+1))
	game.queue_free();await process_frame
	print("V101_VISUALS_DONE");quit()

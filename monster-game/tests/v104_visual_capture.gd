extends SceneTree
var game
var output = ""
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	await game.capture_frame(output.path_join(name + ".png"))
func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.test_mode = true; game.set_process(false); game.set_physics_process(false)
	game.data = MonsterCatalog.defaults(); game.data.wallet = 340; game.data.eyes = 8
	game.data.best_souls = 18; game.data.best = 648; game.data.runs = 2; game.data.total_souls = 29
	game.data.lifetime = {"horde":15,"coins":100,"cars":7,"tunnels":1,"seconds":60}
	game.hub.update(game, 0.01)
	game.change_screen("profile"); game.hub.profile_page = 0
	await shot("profile")
	game.hub.profile_page = 1
	game.data.death_causes = {"fall":15,"camera":12,"air_bomb":3,"rushing_car":1}
	await shot("losses")
	game.data.death_causes = {}; await shot("losses_zero")
	game.runner.start_developer("animation_check", 1, 0, 104)
	game.runner.members[0].kind = 2; game.runner.members[0].arrival = 0.0
	game.change_screen("run"); game.capture_freeze = true
	await shot("masked_run")
	game.runner.jump()
	for i in range(38): game.runner.advance(1.0 / 120.0, i < 15)
	await shot("masked_jump")
	for i in range(100):
		game.runner.advance(1.0 / 120.0)
		if game.runner.members[0].land_left > 0.0: break
	for i in range(11): game.runner.advance(1.0 / 120.0)
	await shot("masked_land")
	game.runner.members[0].land_left = 0.0
	var e = game.runner.add_entity("civilian", HordeRun.ANCHOR + 40)
	game.runner.begin_capture(e, game.runner.members[0])
	for i in range(19):
		game.runner.update_civilians(1.0 / 60.0)
		game.runner.members[0].attack_left -= 1.0 / 60.0
	await shot("masked_capture")
	game.runner.members[0].attack_left = 0.0; e.taken = true
	var car = game.runner.add_entity("car", HordeRun.ANCHOR + 175)
	car.contacts[game.runner.members[0].id] = 4
	game.runner.flip_vehicle(car)
	game.consume_run_events()
	game.effects.update(0.47, 0.0)
	game.runner.members[0].mask_flip_left = 0.43
	await shot("masked_flip")
	game.runner.members[0].mask_flip_left = 0.0
	game.runner.shields = 1; game.runner.damage(0, "bullet"); game.runner.members[0].hurt_left = 0.36
	await shot("masked_damage")
	game.queue_free(); game = null
	for i in range(3): await process_frame
	print("V104_VISUAL_CAPTURE_READY")
	quit()

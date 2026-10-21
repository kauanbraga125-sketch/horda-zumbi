extends SceneTree
var game
var output=""
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	game.hub.update(game,0.0);game.queue_redraw()
	await game.capture_frame(output.path_join(name+".png"))
func run() -> void:
	output=OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.test_mode=true;game.set_process(false);game.set_physics_process(false)
	game.data=MonsterCatalog.defaults();game.data.wallet=533;game.data.eyes=8;game.data.player_level=3;game.data.level_souls=42
	game.hub.update(game,0.01);game.change_screen("missions")
	await shot("missions")
	for i in range(12):
		game.data.player_level=i+1;game.data.level_souls=floori(HordeProgress.level_target(i+1)*0.67)
		game.ui_time=i*1.6;game.hub.presentation.reset(game.data.player_level,game.data.level_souls)
		await shot("mixture_"+str(i+1))
	game.data.player_level=3;game.data.level_souls=78;game.hub.presentation.reset(3,78)
	HordeProgress.queue_mission(game.data,{"key":"visual","title":"VISUAL","ritual":35})
	game.begin_ritual()
	for i in range(220):
		game.ui_time+=1.0/60.0;game.hub.update(game,1.0/60.0)
		if i in [25,61,95,119,154,191,219]: await shot("reward_"+str(i))
	game.change_screen("home");await shot("home")
	game.runner.start_developer("animation_check",1,0,105);game.change_screen("run")
	game.hub.presentation.reset(3,78);game.data.player_level=3;game.data.level_souls=78
	HordeProgress.queue_mission(game.data,{"key":"visual2","title":"VISUAL","ritual":35});game.begin_ritual()
	game.hub.update(game,1.7);await shot("run_reward")
	game.queue_free();game=null
	for i in range(3): await process_frame
	print("V105_VISUAL_CAPTURE_READY");quit()

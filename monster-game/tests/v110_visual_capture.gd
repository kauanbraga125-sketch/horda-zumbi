extends SceneTree
var game
var output=""
var failures=0
func _initialize() -> void: call_deferred("run")
func setup(old_altar: int = 15, souls: int = 5, xp: int = 85, points: int = 38) -> void:
	game.data=MonsterCatalog.defaults();game.data.wallet=141;game.data.eyes=8
	game.data.player_level=4;game.data.level_souls=xp;game.data.altar_souls=old_altar
	game.start_run();game.end_delay=-1
	game.runner.world_px=353*30;game.runner.coins=35;game.runner.souls=souls;game.runner.max_horde=6
	if points>0:
		HordeProgress.queue_mission(game.data,{"key":"v110-preview","title":"MISSÃO CONCLUÍDA","ritual":points})
		# Fixture uses an exact earned total, including any adrenaline modifier.
		game.data.ritual_pending.back().points=points;game.begin_ritual()
	game.revive_used=true;game.finish_run();game.end_delay=-1;game.change_screen("results")
func shot(name: String) -> void:
	game.toast_left=0
	await game.capture_frame(output.path_join(name+".png"))
func tap(action: String) -> void:
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	for button in game.buttons:
		if button.action==action:
			game.press_at(button.rect.get_center(),110);game.release_touch(110);return
	failures+=1;push_error("V110_MISSING_TOUCH_TARGET "+action)
func run() -> void:
	output=OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.test_mode=true;game.capture_mode=true;game.set_process(false);game.set_physics_process(false)
	setup()
	var previous=0.0
	for at in [0.0,0.65,1.25,2.1,2.65,3.5,4.3,5.4,7.6]:
		for i in range(roundi((at-previous)*60)): game.ui_time+=1.0/60;game.hub.update(game,1.0/60)
		previous=at;await shot("results_"+str(roundi(at*100)))
	setup(97,8,40,18)
	for i in range(86): game.ui_time+=1.0/60;game.hub.update(game,1.0/60)
	await shot("altar_full")
	for i in range(190): game.ui_time+=1.0/60;game.hub.update(game,1.0/60)
	await shot("altar_next")
	setup(42,0,25,0)
	game.hub.update(game,8);await shot("no_rewards")
	await tap("graves_open");await shot("graves")
	await tap("back");await shot("returned")
	await tap("play");await shot("preparation")
	setup(15,5,12,22);game.hub.update(game,2);await shot("partial_fill")
	await tap("home");await shot("home")
	print("V110_VISUAL_RESULT failures=",failures)
	game.queue_free();game=null
	for i in range(3): await process_frame
	quit(1 if failures else 0)

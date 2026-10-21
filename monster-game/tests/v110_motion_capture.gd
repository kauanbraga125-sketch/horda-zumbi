extends SceneTree
var game
var output=""
var events: Array[Dictionary]=[]
var base=0.0
func _initialize() -> void: call_deferred("run")
func setup(old: int, souls: int, xp: int, points: int) -> void:
	game.data=MonsterCatalog.defaults();game.data.wallet=141;game.data.eyes=8
	game.data.player_level=4;game.data.level_souls=xp;game.data.altar_souls=old
	game.start_run();game.end_delay=-1;game.runner.world_px=353*30;game.runner.coins=35;game.runner.souls=souls;game.runner.max_horde=6
	if points>0:
		HordeProgress.queue_mission(game.data,{"key":"capture","title":"MISSÃO CONCLUÍDA","ritual":points})
		game.data.ritual_pending.back().points=points;game.begin_ritual()
	game.revive_used=true;game.finish_run();game.end_delay=-1;game.change_screen("results");game.hub.update(game,0)
func run() -> void:
	output=OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.test_mode=true;game.capture_mode=true;game.set_process(false);game.set_physics_process(false);game.sound.set_enabled(true)
	game.sound.result_cue.connect(func(name, pitch, volume): events.append({"time":base+game.hub.result_ui.clock,"name":name,"pitch":pitch,"volume":volume}))
	var index=0
	for example in range(2):
		base=0.0 if example==0 else 8.0
		setup(15 if example==0 else 97,5 if example==0 else 8,85 if example==0 else 22,38 if example==0 else 18)
		var frames=96 if example==0 else 60
		for frame in range(frames):
			game.ui_time+=1.0/12.0;game.hub.update(game,1.0/12.0)
			await game.capture_frame(output.path_join("frame-%04d.png" % index));index+=1
	FileAccess.open(output.path_join("audio-events.json"),FileAccess.WRITE).store_string(JSON.stringify(events,"  "))
	print("V110_MOTION_READY frames=",index," audio_events=",events.size())
	game.queue_free();game=null
	for i in range(3): await process_frame
	quit()

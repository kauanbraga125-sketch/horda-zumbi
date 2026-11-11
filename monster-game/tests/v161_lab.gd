extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.sound.set_enabled(false)
	assert(game.screen=="home")
	game.perform_action("home_sewer_test")
	var r = game.runner
	assert(game.screen=="run" and r.sewer.encounter.pending and r.sky.pending)
	assert(not r.sewer.active and not r.sky.active)
	assert(not r.has_floor(r.sewer.encounter.left(r)+30.0))
	assert(r.has_floor(r.sewer.encounter.right(r)+30.0))
	assert(r.has_floor(r.sky.pad_world-r.world_px))
	game.queue_redraw()
	await process_frame
	assert(game.buttons.all(func(button): return button.action!="journey_sewer"))
	game.set_process(false)
	game.queue_free()
	for i in range(8): await process_frame
	print("V161_LAB_OK real home button offers all three physical paths")
	quit()

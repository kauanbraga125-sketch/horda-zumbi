extends SceneTree

var game: Node2D
var output = OS.get_environment("POLICE_PREVIEW_DIR")

func _initialize() -> void:
	call_deferred("render_previews")

func render_previews() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.capture_mode = true;game.capture_freeze = true
	game.sound.set_enabled(false)
	game.sprite_npcs = true;game.sprite_subject = 3;game.sprite_paused = true
	game.screen = "sprite_lab"
	var clocks = [0.15, 0.4, 0.32, 0.5, 0.82]
	for state in range(5):
		game.sprite_state = state;game.sprite_clock = clocks[state]
		await game.capture_frame(output + "/lab-" + str(state) + ".png")
	for kind in [0, 3]:
		game.preview_course(0.0, 4, kind)
		game.camera_zoom = game.CAMERA_BASE_ZOOM
		var run = game.runner
		var worker = run.add_entity("civilian", 740.0, HordeRun.FLOOR, 2)
		worker.worker_time = 0.35
		var girl = run.add_entity("civilian", 925.0, HordeRun.FLOOR, 1)
		girl.woman_time = 0.4
		var police = run.add_entity("police", 550.0, HordeRun.FLOOR)
		police.age = 0.25;police.bob = 0.0
		await game.capture_frame(output + "/scene-" + str(kind) + "-run.png")
		run.begin_capture(police, run.members[0])
		var duration = float(police.capture_duration)
		police.x = run.members[0].x + police.capture_offset.x
		police.y = run.members[0].y + police.capture_offset.y
		for u in [0.05, 0.25, 0.5, 0.7, 0.95]:
			police.capture_left = duration * (1.0 - u)
			police.age = 0.25 + duration * u
			run.members[0].attack_left = police.capture_left
			await game.capture_frame(output + "/scene-" + str(kind) + "-capture-" + str(roundi(u * 100)) + ".png")
		if kind == 0:
			for frame in range(36):
				var u = minf(float(frame) / 30.0, 1.0)
				police.capture_left = duration * (1.0 - u)
				police.age = 0.25 + duration * u
				run.members[0].attack_left = police.capture_left
				await game.capture_frame(output + "/frame-" + ("%03d" % frame) + ".png")
	print("POLICE_REAL_RENDER_OK")
	game.queue_free()
	await process_frame
	quit()

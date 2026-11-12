extends SceneTree

var failures: Array[String] = []
var checks = 0
var heard: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func check(valid: bool, message: String) -> void:
	checks += 1
	if not valid: failures.append(message);push_error(message)

func run() -> void:
	var boot = load("res://boot.tscn").instantiate()
	root.add_child(boot);current_scene = boot
	var game
	for frame in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):
			game = current_scene;break
	check(is_instance_valid(game), "Actual game starts through the integrity audit")
	if not is_instance_valid(game): quit(1);return
	game.set_physics_process(false)
	game.sound.set_enabled(true)
	for cycle in range(2):
		for action in ["market", "back"]:
			for player in game.sound.players: player.stop()
			game.perform_action(action)
			check(game.screen == ("market" if action == "market" else "home"), "Navigation action reaches its screen: " + action)
			var group = "UI_01" if action == "market" else "UI_02"
			var playing = ""
			for key in game.sound.variants[group]:
				for player in game.sound.players:
					if player.playing and player.stream == game.sound.clips[key]:
						playing = key
			check(not playing.is_empty(), "Cue is already playing when the navigation action returns: " + action)
			if not playing.is_empty():
				heard[playing] = true
				var stream = game.sound.clips[playing]
				check(stream.get_length() >= .20 and stream.get_length() < .75, "Loaded cue has the corrected duration: " + playing)
			await create_timer(.12).timeout
	check(heard.size() == 4, "Both confirm and back variants are exercised")
	game.sound.set_enabled(false)
	game.perform_action("market")
	check(game.sound.players.all(func(p): return not p.playing), "Muting still suppresses navigation cues")
	var report = {"version":ProjectSettings.get_setting("application/config/version"), "checks":checks, "failures":failures, "variants":heard.keys(), "physical_device_tested":false}
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		var file = FileAccess.open(folder + "/ui-audio.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "));file.close()
	print("V168_UI_AUDIO ", JSON.stringify(report))
	game.set_process(false);game.queue_free();current_scene = null
	for frame in range(8): await process_frame
	quit(0 if failures.is_empty() else 1)

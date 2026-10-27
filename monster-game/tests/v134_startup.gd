extends SceneTree

var checks = 0
var failures: Array[String] = []
var folder = ""
var fixture = ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message);push_error(message)

func _initialize() -> void: call_deferred("run")

func snap(name: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder + "/" + name + ".png") == OK,"capture " + name)

func run() -> void:
	folder = OS.get_environment("HORDA_VALIDATION_DIR");fixture = OS.get_environment("HORDA_STARTUP_FIXTURE")
	assert(not folder.is_empty() and fixture in ["new","existing"])
	if OS.get_environment("HORDA_STARTUP_WIDE") == "1": root.size = Vector2i(1800,810)
	DirAccess.make_dir_recursive_absolute(folder)
	# Each invocation uses a fresh XDG_DATA_HOME; never use the player's directory.
	if fixture == "existing":
		var old = MonsterCatalog.defaults()
		old.wallet = 123;old.eyes = 2;old.best = 4567;old.runs = 31
		old.cosmetics = ["bruxa"];old.active_cosmetics = ["bruxa"]
		var file = FileAccess.open("user://noite-da-horda.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(old));file.close()
	else:
		check(not FileAccess.file_exists("user://noite-da-horda.json"),"fresh save directory")
	var boot = load("res://boot.tscn").instantiate();root.add_child(boot);current_scene = boot
	var game
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("start_run"):
			game = current_scene;break
	check(is_instance_valid(game),"boot loads the actual game")
	if not is_instance_valid(game): quit(1);return
	check(not game.test_mode and not game.capture_mode,"ordinary startup without validation bypass")
	game.set_physics_process(false)
	await snap("01_home_" + fixture)
	check(game.data.wallet >= 1000000 and game.data.eyes >= 10000,"ordinary startup grants both currencies")
	var persisted = JSON.parse_string(FileAccess.get_file_as_string("user://noite-da-horda.json"))
	check(persisted is Dictionary and persisted.wallet >= 1000000 and persisted.eyes >= 10000,"funds are persisted on startup")
	if fixture == "existing":
		check(game.data.best == 4567 and game.data.runs == 31,"existing run progress preserved")
		check(game.data.cosmetics == ["bruxa"] and game.data.active_cosmetics == ["bruxa"],"existing cosmetics preserved")
	if str(ProjectSettings.get_setting("application/config/version")) in ["0.10.31","0.10.32","0.10.33","0.10.34"]:
		var shortcuts: Dictionary = {}
		for candidate in game.buttons:
			if candidate.action in ["home_space_test","developer_test_funds"]: shortcuts[candidate.action] = candidate.rect
		check(shortcuts.size() == 2,"home exposes both test shortcuts")
		if shortcuts.size() == 2:
			check(game.full_rect().encloses(shortcuts.home_space_test) and game.full_rect().encloses(shortcuts.developer_test_funds) and not shortcuts.home_space_test.intersects(shortcuts.developer_test_funds),"shortcuts fit without overlap")
			game.data.wallet = 77;game.data.eyes = 1
			game.press_at(shortcuts.developer_test_funds.get_center());game.release_touch(-1)
			check(game.data.wallet == 1000000 and game.data.eyes == 10000,"home refill works through touch routing")
			game.press_at(shortcuts.home_space_test.get_center());game.release_touch(-1)
			check(game.lab_active and game.runner.space.active,"home space shortcut works through touch routing")
			game.leave_lab();game.change_screen("home");game.toast_left = 0
	game.change_screen("developer");await snap("02_developer_" + fixture)
	var button: Dictionary = {}
	for candidate in game.buttons:
		if candidate.action == "lab_kind_space": button = candidate;break
	check(not button.is_empty(),"space button is registered")
	if not button.is_empty():
		check(game.full_rect().encloses(button.rect),"space button lies inside the screen")
		game.press_at(button.rect.get_center());game.release_touch(-1)
	check(game.lab_active and game.lab_kind == "space" and game.runner.space.active,"space action opens the real flight")
	await snap("03_space_" + fixture)
	game.leave_lab();game.sound.set_enabled(false);game.set_process(false);game.queue_free();current_scene = null;game = null;boot = null
	for i in range(8): await process_frame
	var report = {"version":str(ProjectSettings.get_setting("application/config/version")),"fixture":fixture,"checks":checks,"failures":failures,"physical_device_tested":false}
	var file = FileAccess.open(folder + "/startup-" + fixture + ".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("STARTUP_INTEGRATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

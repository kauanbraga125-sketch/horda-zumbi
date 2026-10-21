extends Node

# Keep this entry point independent of the game's global classes. It verifies
# the exact startup files before loading the full scene and records Android
# read failures instead of silently crashing inside a dependent script.
const REPORT = "user://horda_boot_diagnostico.json"
var results: Dictionary = {"version": str(ProjectSettings.get_setting("application/config/version", "0.10.10")), "status": "starting", "files_checked": 0}
var started = Time.get_ticks_msec()

func _ready() -> void:
	print("HORDA_BOOT_START version=", results.version, " scripts=text")
	call_deferred("start_game")

func sha256(bytes: PackedByteArray) -> String:
	var hash = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func write_report() -> void:
	results.elapsed_ms = Time.get_ticks_msec() - started
	var file = FileAccess.open(REPORT, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(results, "\t"))

func fail(message: String) -> void:
	results.status = "failed";results.error = message
	write_report()
	push_error("HORDA_BOOT_FAILED " + message)
	var label = Label.new()
	label.text = "Não foi possível carregar os arquivos do jogo.\nO diagnóstico de inicialização foi registrado."
	label.position = Vector2(70, 250)
	label.add_theme_font_size_override("font_size", 28)
	add_child(label)

func start_game() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://startup_integrity.json"))
	if not manifest is Dictionary or not manifest.get("files", null) is Array:
		fail("Invalid startup manifest")
		return
	for entry in manifest.files:
		var path = str(entry.path)
		var data = FileAccess.get_file_as_bytes(path)
		var actual = sha256(data)
		if data.size() != int(entry.bytes) or actual != str(entry.sha256):
			results.asset = {"path": path, "expected_bytes": entry.bytes, "actual_bytes": data.size(), "expected_sha256": entry.sha256, "actual_sha256": actual}
			fail("Startup asset mismatch: " + path)
			return
		results.files_checked += 1
	var cache = ConfigFile.new()
	var error = cache.load("res://.godot/global_script_class_cache.cfg")
	if error != OK:
		fail("Global class cache parse error: " + str(error))
		return
	var classes: Array = ProjectSettings.get_global_class_list()
	if classes.size() != int(manifest.class_count):
		fail("Global class count mismatch: " + str(classes.size()))
		return
	print("HORDA_BOOT_ASSETS_OK files=", results.files_checked, " classes=", classes.size())
	var scene = load("res://main.tscn") as PackedScene
	if scene == null:
		fail("Main scene could not be loaded")
		return
	var tree = get_tree()
	var game = scene.instantiate()
	tree.root.add_child(game)
	tree.current_scene = game
	await tree.process_frame
	await tree.process_frame
	if not game.has_method("start_run") or not is_instance_valid(game.sound):
		fail("Game script did not initialize")
		return
	results.status = "scene_loaded"
	write_report()
	print("HORDA_BOOT_READY scene=", game.name)
	queue_free()

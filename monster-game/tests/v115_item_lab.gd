extends SceneTree

var game
var viewport: SubViewport
var failures: Array[String] = []
var checks = 0
var output = ""

func _initialize() -> void: call_deferred("run")

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("V115_LAB_FAIL: " + message)

func draw_frame() -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw

func touch(action: String) -> void:
	await draw_frame()
	var found = false
	for button in game.buttons:
		if button.action == action:
			found = true
			game.press_at(button.rect.get_center(), 115)
			game.release_touch(115)
			break
	verify(found, "Visible touch target: " + action)

func shot(name: String) -> void:
	await draw_frame()
	await game.capture_frame(output.path_join(name + ".png"))

func check_targets() -> void:
	await draw_frame()
	for i in range(game.buttons.size()):
		var a: Dictionary = game.buttons[i]
		verify(a.rect.size.x >= 44 and a.rect.size.y >= 44, "Touch size: " + a.action)
		verify(Rect2(Vector2.ZERO, viewport.size).encloses(Rect2(a.rect.position + game.position, a.rect.size)), "On-screen: " + a.action)
		for j in range(i): verify(not a.rect.intersects(game.buttons[j].rect), "No overlapping targets: " + a.action + "/" + game.buttons[j].action)

func run() -> void:
	output = OS.get_environment("HORDA_VALIDATION_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = load("res://main.tscn").instantiate()
	viewport.add_child(game)
	game.test_mode = true
	game.capture_mode = true
	game.set_process(false)
	game.set_physics_process(false)
	game.data = MonsterCatalog.defaults()
	game.data.wallet = 12345
	game.data.eyes = 12
	var before: Dictionary = game.data.duplicate(true)
	var runner_before = game.runner
	var last_save: float = game.last_save
	game.settings_from = "home"
	game.change_screen("settings")
	await touch("developer")
	verify(game.screen == "developer", "Developer menu opens from settings")
	await shot("01_developer_menu")
	await touch("item_lab_open")
	verify(game.screen == "item_lab", "Workbench opens via real touch")
	await check_targets()
	await shot("02_item_lab_default")
	var lab = game.item_lab
	verify(lab.entries().size() == 35, "All 35 items available without ownership")
	var visited: Array[String] = []
	var keys: Dictionary = {}
	var total_samples = 0
	for page in range(6):
		var list: Array = lab.entries()
		for offset in range(mini(6, list.size() - page * 6)):
			var entry: Dictionary = HordeCosmeticCatalog.ITEMS[list[page * 6 + offset]]
			await touch("item_lab_select_" + entry.id)
			verify(lab.current().id == entry.id, "Selected individual item: " + entry.id)
			visited.append(entry.id)
			var bounds: Rect2 = lab.bounds_for(game.actor.cosmetics)
			verify(bounds.has_area() and is_finite(bounds.size.x) and is_finite(bounds.size.y), "Preview bounds: " + entry.id)
			for state in range(lab.STATES.size()):
				for index in range(int(lab.spec(entry.kind, state).x)):
					var pose: Dictionary = lab.sample(entry.kind, state, index)
					verify(game.actor.cosmetics.frames.has(pose.key), "Measured attachment frame exists: " + pose.key)
					keys[pose.key] = true
					total_samples += 1
		if page < 5: await touch("item_lab_next")
	verify(visited.size() == 35, "Every item reachable through pagination")
	verify(keys.size() == 263, "All 263 measured body frames reachable")
	await touch("item_lab_next")
	verify(lab.page == 0, "Next page wraps to start")
	await touch("item_lab_prev")
	verify(lab.page == 5, "Previous page wraps to end")
	for filter in [0, 1, -1]:
		await touch("item_lab_filter_" + str(filter))
		verify(lab.entries().size() == (35 if filter < 0 else 19 if filter == 0 else 16), "Filter count: " + str(filter))
		verify(lab.selected in lab.entries(), "Selection belongs to active filter")
		verify(lab.page == int(lab.entries().find(lab.selected) / 6), "Selected item remains on visible page")
	await touch("item_lab_filter_0")
	await touch("item_lab_select_coveiro")
	verify(not lab.paused, "Initially playing")
	lab.update(.1)
	verify(lab.cursor > 0, "Playback advances")
	await touch("item_lab_pause")
	var frozen: float = lab.cursor
	lab.update(1.0)
	verify(lab.cursor == frozen, "Paused preview is frozen")
	for state in range(lab.STATES.size()):
		lab.cursor = 0
		await touch("item_lab_frame_prev")
		verify(lab.frame() == int(lab.spec().x) - 1 and lab.paused, "Previous frame wraps and pauses")
		await touch("item_lab_frame_next")
		verify(lab.frame() == 0, "Next frame wraps")
		await touch("item_lab_state")
	verify(lab.state_index == 0, "All nine animations cycle")
	await touch("item_lab_speed")
	verify(lab.SPEEDS[lab.speed_index] == .5, "Half-speed control")
	await touch("item_lab_speed")
	verify(lab.SPEEDS[lab.speed_index] == .25, "Quarter-speed control")
	await touch("item_lab_compare")
	verify(lab.compare, "Before/after comparison enabled")
	await touch("item_lab_reverse")
	verify(lab.reverse, "Facings invert")
	await touch("item_lab_copy")
	var report: String = DisplayServer.clipboard_get()
	verify(report.contains("coveiro") and report.contains(lab.sample().key) and report.contains("quadro 1/16"), "Copied report identifies exact item and frame")
	game.toast_left = 0
	await shot("03_compare")
	await touch("item_lab_zoom")
	verify(lab.ZOOMS[lab.zoom_index] == 1.5, "Detail zoom")
	await shot("04_detail_zoom")
	await touch("item_lab_zoom")
	await shot("05_detail_zoom_2x")
	await touch("item_lab_zoom")
	verify(lab.zoom_index == 0, "Zoom returns to full body")
	await touch("item_lab_filter_1")
	await touch("item_lab_next")
	await touch("item_lab_select_s_space")
	lab.state_index = 7
	lab.cursor = 19
	viewport.size = Vector2i(2048, 922)
	game.configure_layout()
	await check_targets()
	await shot("06_wide_skeleton_capture")
	viewport.size = Vector2i(1280, 960)
	game.configure_layout()
	await check_targets()
	await shot("07_tablet")
	await touch("back")
	verify(game.screen == "developer", "Back returns to developer menu")
	for clip in lab.clips: verify(not clip.visible, "Preview hidden on exit")
	await touch("item_lab_open")
	verify(lab.current().id == "s_space" and lab.paused, "Review position is retained during session")
	await touch("back")
	await touch("back")
	verify(game.screen == "settings", "Developer returns to settings")
	verify(game.data == before, "Entire player save unchanged after reviewing all items")
	verify(game.runner == runner_before and game.last_save == last_save, "Run context and autosave timer unchanged")
	var result = {"checks": checks, "failures": failures, "items_visited": visited.size(), "measured_frames": keys.size(), "animation_samples": total_samples, "screenshots": 7, "player_data_unchanged": game.data == before}
	var file = FileAccess.open(output.path_join("item_lab_validation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("V115_ITEM_LAB_", "OK" if failures.is_empty() else "FAILED", ": ", JSON.stringify(result))
	game.queue_free()
	await process_frame
	viewport.queue_free()
	game = null
	lab = null
	runner_before = null
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

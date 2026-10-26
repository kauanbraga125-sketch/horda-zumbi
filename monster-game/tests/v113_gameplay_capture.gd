extends SceneTree
var game
var failures = 0
var output = ""
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	game.toast_left = 0;game.queue_redraw();game.market_canvas.queue_redraw()
	await game.capture_frame(output.path_join(name + ".png"))
func tap(action: String) -> void:
	game.queue_redraw();game.market_canvas.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	for button in game.buttons:
		if button.action == action:
			game.press_at(button.rect.get_center(),113);game.release_touch(113);return
	failures += 1;push_error("V113_MISSING_TOUCH_TARGET " + action)
func run() -> void:
	output=OS.get_environment("HORDA_VALIDATION_DIR")
	if output.is_empty(): output=ProjectSettings.globalize_path("res://validation/v113-gameplay")
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.test_mode=true;game.capture_mode=true;game.set_process(false);game.set_physics_process(false)
	game.data=MonsterCatalog.defaults();game.data.wallet=10000;game.data.eyes=100
	game.market.open(2);game.change_screen("market");game.ui_time=.41
	await shot("market_zombie")
	await tap("cosmetic_coveiro")
	if "coveiro"not in game.data.active_cosmetics:failures+=1;push_error("V113_PURCHASE_NOT_ACTIVE")
	await tap("market_filter_1");await shot("market_skeleton")
	game.market.scroll_by(10000);await shot("market_skeleton_last")
	var grid=game.market.layout(game.full_rect()).grid
	for button in game.buttons:
		if str(button.action).begins_with("cosmetic_")and not grid.grow(.01).encloses(button.rect):failures+=1;push_error("V113_CLIP_OUTSIDE " + str(button.action))
	await tap("market_filter_2");await shot("market_areas")
	for entry in HordeMeta.COSMETICS:
		if entry.id not in game.data.cosmetics:game.data.cosmetics.append(entry.id);game.data.active_cosmetics.append(entry.id)
	for count in [2,6,32,64]:
		game.start_run();game.runner.start_developer("test",count,0,113);game.runner.next_pattern_world=1e9;game.runner.next_segment=99999
		game.runner.active_cosmetics=game.data.active_cosmetics.duplicate();game.runner.owned=[0,1]
		for i in range(count):game.runner.members[i].kind=i%2
		game.change_screen("run");game.runner.entities.clear();game.runner.view_left=-100;game.runner.view_right=1300
		for _i in range(24):game.runner.advance(1.0/120);game.update_camera(1.0/120)
		await shot("horde_%d_walk"%count)
		game.runner.jump()
		for _i in range(20):game.runner.advance(1.0/120,true);game.update_camera(1.0/120)
		game.runner.release_jump();await shot("horde_%d_jump"%count)
		for _i in range(120):game.runner.advance(1.0/120);game.update_camera(1.0/120)
		if game.runner.members.size()!=count:failures+=1;push_error("V113_FLAT_LOSS count="+str(count)+" remaining="+str(game.runner.members.size())+" causes="+str(game.runner.loss_causes))
	print("V113_GAMEPLAY_RESULT failures=",failures)
	game.queue_free();game=null
	for _i in range(3):await process_frame
	quit(1 if failures else 0)

extends SceneTree
var game
var output = ""
func _initialize() -> void: call_deferred("run")
func run() -> void:
	output=OS.get_environment("HORDA_VALIDATION_DIR");DirAccess.make_dir_recursive_absolute(output)
	var viewport=SubViewport.new();viewport.size=Vector2i(2048,922);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game=load("res://main.tscn").instantiate();viewport.add_child(game)
	game.test_mode=true;game.capture_mode=true;game.set_process(false);game.set_physics_process(false)
	game.data=MonsterCatalog.defaults();game.data.wallet=120;game.data.eyes=0
	game.market.open(2);game.change_screen("market");game.ui_time=.41
	for filter in range(2):
		game.market.accessory_filter=filter
		var layout=game.market.layout(game.full_rect())
		var count=game.market.items(game.data).size()
		for row in range(0,ceili(count/2.0),2):
			game.market.scroll=row*(layout.card_size.y+layout.gap)
			game.toast_left=0;game.queue_redraw();game.market_canvas.queue_redraw()
			await process_frame;await RenderingServer.frame_post_draw
			await game.capture_frame(output.path_join("market_%d_%d.png"%[filter,row]))
	print("V114_MARKET_COMPLETE: all 35 accessories")
	game.queue_free();await process_frame;quit()

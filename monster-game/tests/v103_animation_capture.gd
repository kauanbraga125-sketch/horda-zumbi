extends SceneTree
var game
var output := ""
var frame := 0
func _initialize() -> void: call_deferred("run")
func capture(seconds: float) -> void:
	for i in range(ceili(seconds*15)):
		game.ui_time += 1.0/15
		game.codex.update(game,1.0/15)
		game.hub.update(game,1.0/15)
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("frame_%04d.png"%frame))
		frame += 1
func run() -> void:
	output=OS.get_environment("HORDA_VALIDATION_DIR")
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.test_mode=true;game.set_process(false);game.set_physics_process(false)
	game.data=MonsterCatalog.defaults();game.data.wallet=440;game.data.eyes=5
	game.hub.update(game,0.1)
	await capture(0.7)
	game.codex.open(game,0)
	await capture(3.3)
	game.data.owned.append(1)
	await capture(2.6)
	game.codex.action(game,"codex_next")
	game.data.power_owned.append(2)
	await capture(3.4)
	game.data.player_level=150
	game.codex.action(game,"codex_section_2")
	await capture(3.0)
	game.codex.action(game,"codex_section_3")
	await capture(3.0)
	game.codex.action(game,"back")
	await capture(1.6)
	print("V103_CAPTURE frames=",frame)
	game.queue_free();game=null
	for i in range(3): await process_frame
	quit()

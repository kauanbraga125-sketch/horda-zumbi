extends SceneTree
var game
class Sheet extends Node2D:
	var actor
	var mode = "ride"
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,850),Color("171023"))
		draw_string(ThemeDB.fallback_font,Vector2(25,30),"HORDA ZUMBI • NOVAS POSES • "+mode.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("ffca67"))
		for i in range(HordeCosmeticCatalog.ITEMS.size()):
			var entry = HordeCosmeticCatalog.ITEMS[i];var foot = Vector2(93+(i%7)*182,165+int(i/7)*152)
			actor.paint_rider(self,int(entry.kind),foot,90,.16,0,[entry.id],Color.WHITE,0,mode,.7)
			draw_string(ThemeDB.fallback_font,foot+Vector2(-72,30),entry.id,HORIZONTAL_ALIGNMENT_LEFT,170,12,Color("a4dfc7"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var folder = OS.get_environment("HORDA_VALIDATION_DIR");assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,850);game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_physics_process(false);game.capture_freeze = true;game.sound.set_enabled(false);game.hide()
	var sheet = Sheet.new();sheet.actor = game.actor;root.add_child(sheet)
	for mode in ["ride","duck"]:
		sheet.mode = mode;sheet.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(folder+"/cosmeticos_"+mode+".png")==OK)
	# Exercise every cell, not only a static sitting frame.
	for kind in [0,1]:
		for i in range(12):
			var f = game.actor.sewer_riders.pose(game.actor.cosmetics,kind,i)
			assert(float(f.head_width)>0 and is_finite(float(f.landmarks.near[0])))
	sheet.queue_free();game.set_process(false);game.queue_free();game = null
	for i in range(8): await process_frame
	preload("res://scripts/sewer_art.gd").textures.clear()
	print("V139_RIDERS_OK 35 accessories, 24 drawn character cells, 2 native sheets");quit()

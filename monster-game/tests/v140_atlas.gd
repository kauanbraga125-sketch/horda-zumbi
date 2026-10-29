extends SceneTree
const Art = preload("res://scripts/sewer_art.gd")
var checks = 0
class Canvas extends Node2D:
	var time = 0.0
	func _draw() -> void: Art.flood_new(self,Vector2(420,670),420,time)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport = SubViewport.new();viewport.size = Vector2i(640,720);viewport.transparent_bg = true;viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var canvas = Canvas.new();viewport.add_child(canvas)
	for i in range(16):
		canvas.time = (i+.1)/9.0;canvas.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var im = viewport.get_texture().get_image();var outside = 0;var base = 0
		for y in range(0,230,3):
			for x in range(0,640,3):
				if im.get_pixel(x,y).a>.1: outside += 1
		for x in range(170,405):
			for y in range(662,670):
				if im.get_pixel(x,y).a>.5: base += 1
		assert(outside==0,"wave frame leaked above its actual bounds "+str(i));assert(base>100,"wave first/last lines must meet the water "+str(i));checks += 2
	# Cels are isolated textures, with independently registered real component bounds.
	for id in ["zombie_riders","skeleton_riders"]:
		for i in range(12):
			var tex = Art.cell_texture(id,i);assert(tex.get_size()==Vector2(448,448));checks += 1
			assert(Art.data()[id].poses[i].registered);checks += 1
	var report = {"version":"0.10.40","checks":checks,"frames":16,"leaks_above_wave":0,"physical_device_tested":false}
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder);var f = FileAccess.open(folder+"/atlas.json",FileAccess.WRITE);f.store_string(JSON.stringify(report));f.close()
	print("V140_ATLAS ",JSON.stringify(report));canvas.queue_free();viewport.queue_free()
	for i in range(8): await process_frame
	Art.textures.clear();Art.images.clear();quit()

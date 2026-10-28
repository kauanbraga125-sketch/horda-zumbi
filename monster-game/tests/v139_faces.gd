extends SceneTree
var game
var checks = 0
var failures: Array[String] = []
class Sheet extends Node2D:
	var actor
	var pose_index = 0
	func controls() -> Dictionary:
		if pose_index<8: return {"seat":0 if pose_index<4 else 1,"state":"ride","time":(pose_index%4+.03)/8.0,"motion":0.0}
		return {"seat":0,"state":"duck","time":.20 if pose_index==10 else 0.0,"motion":1.2 if pose_index==8 else .12 if pose_index==11 else .7}
	func _draw() -> void:
		var ctl = controls()
		for i in range(HordeCosmeticCatalog.ITEMS.size()):
			var entry = HordeCosmeticCatalog.ITEMS[i]
			actor.paint_rider(self,int(entry.kind),Vector2(93+i%7*182,165+int(i/7)*152),90,ctl.time,0,[entry.id],Color.WHITE,ctl.seat,ctl.state,ctl.motion)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	game = load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.hide();game.set_physics_process(false);game.capture_freeze = true;game.sound.set_enabled(false)
	var view = SubViewport.new();view.size = Vector2i(1280,850);view.transparent_bg = true;view.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var sheet = Sheet.new();sheet.actor = game.actor;view.add_child(sheet)
	for pose_index in range(12):
		sheet.pose_index = pose_index;sheet.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var im = view.get_texture().get_image()
		for i in range(HordeCosmeticCatalog.ITEMS.size()):
			var entry = HordeCosmeticCatalog.ITEMS[i];var f = game.actor.sewer_riders.pose(game.actor.cosmetics,int(entry.kind),pose_index)
			var old: Dictionary = game.actor.cosmetics.frames[f.source_key]
			var foot = Vector2(93+i%7*182,165+int(i/7)*152);var transform = Transform2D(0,foot-Vector2(0,36));transform.x *= .25;transform.y *= .25;transform.origin -= transform.basis_xform(Vector2(f.anchor[0],f.anchor[1]));transform = transform*f.head_transform
			var eye = Vector2(old.landmarks.near[0],old.landmarks.near[1]);var chin = Vector2(old.landmarks.chin[0],old.landmarks.chin[1])
			for source in [eye,eye.lerp(chin,.45),eye.lerp(chin,.72)]:
				var p = transform*source;var alpha = 0.0
				for dy in range(-1,2):
					for dx in range(-1,2):alpha = maxf(alpha,im.get_pixel(clampi(roundi(p.x)+dx,0,1279),clampi(roundi(p.y)+dy,0,849)).a)
				checks += 1
				if alpha<.90:failures.append("opaque face %s pose%d alpha%.2f" % [entry.id,pose_index,alpha])
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder);var f = FileAccess.open(folder+"/faces.json",FileAccess.WRITE);f.store_string(JSON.stringify({"version":"0.10.39","checks":checks,"failures":failures,"poses":12,"accessories":35,"transparent_render_target":true},"  "));f.close()
	print("V139_FACES ",JSON.stringify({"checks":checks,"failures":failures}));sheet.queue_free();view.queue_free();game.set_process(false);game.queue_free();game = null
	for i in range(8): await process_frame
	preload("res://scripts/sewer_art.gd").textures.clear();quit(0 if failures.is_empty() else 1)

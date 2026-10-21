extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := OS.get_environment("DAMAGE_PREVIEW_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load("res://preview.tscn").instantiate()
	root.add_child(scene)
	scene.automatic = false
	root.size = Vector2i(800,600)
	for i in range(55):
		scene.apply_time(i/25.0-0.50)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("frame_%03d.png"%i))
	print("DAMAGE_CAPTURE_OK frames=55 fps=25")
	scene.queue_free()
	await process_frame
	quit()

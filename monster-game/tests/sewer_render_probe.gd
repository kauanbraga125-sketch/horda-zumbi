extends RefCounted
## Isolate actual physical terrain. The distant scenery is intentionally allowed
## below the walking plane; checking that background against empty pixels would
## enforce the very rectangular cut this transition is designed to remove.
static func terrain_image(g,tree: SceneTree) -> Image:
	g.configure_layout()
	var clear = RenderingServer.get_default_clear_color()
	RenderingServer.set_default_clear_color(Color.MAGENTA)
	var nodes = [g,g.world_canvas,g.foreground_canvas,g.sewer_background_canvas,g.sewer_street_canvas]
	var colors: Array[Color] = []
	for node in nodes:
		colors.append(node.self_modulate);node.self_modulate.a = 0
	var probe = Node2D.new();probe.z_index = 100;g.world_canvas.add_child(probe)
	probe.draw.connect(func():
		var target = g.paint_target;g.paint_target = probe
		probe.draw_set_transform(Vector2(0,-g.runner.sewer.entry_drop()))
		g.ground(g.runner.world_px)
		probe.draw_set_transform(Vector2.ZERO);g.paint_target = target)
	g.queue_redraw();g.world_canvas.queue_redraw();g.foreground_canvas.queue_redraw();probe.queue_redraw()
	await tree.process_frame;await RenderingServer.frame_post_draw
	var result = tree.root.get_texture().get_image()
	probe.queue_free()
	for i in range(nodes.size()): nodes[i].self_modulate = colors[i]
	RenderingServer.set_default_clear_color(clear)
	g.queue_redraw();g.world_canvas.queue_redraw();g.foreground_canvas.queue_redraw()
	await tree.process_frame;await RenderingServer.frame_post_draw
	return result

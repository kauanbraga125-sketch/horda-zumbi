extends HordeCosmetics

# A raw texture quad is independent of all source-occlusion meshes and
# legacy polygon outlines. It supplies the original protected source pixels.
func draw_item(_canvas: Node2D, _id: String, _f: Dictionary, _root: Transform2D, _tint: Color, _front: bool = false) -> void:
	pass

func draw_source(canvas: Node2D, key: String, cut: String, transform: Transform2D, tint: Color) -> void:
	if cut in ["clown_details", "clown_face", "hockey_ears", "face"]: return
	var f: Dictionary = frames[key]
	canvas.draw_set_transform_matrix(transform)
	canvas.draw_texture_rect_region(texture(f.file),Rect2(0,0,f.rect[2],f.rect[3]),Rect2(f.rect[0],f.rect[1],f.rect[2],f.rect[3]),tint)

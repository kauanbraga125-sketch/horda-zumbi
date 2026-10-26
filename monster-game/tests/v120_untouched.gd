extends HordeCosmetics

# Independent visual reference: original texture and original frame outline,
# without any generated head/body masks or equipment layers.
func draw_item(_canvas: Node2D, _id: String, _f: Dictionary, _root: Transform2D, _tint: Color, _front: bool = false) -> void:
	pass

func draw_source(canvas: Node2D, key: String, _cut: String, transform: Transform2D, tint: Color) -> void:
	var f: Dictionary = frames[key]
	canvas.draw_set_transform_matrix(transform)
	if f.has("original_outline"):
		var outline = PackedVector2Array();var uvs = PackedVector2Array()
		for point in f.original_outline:
			var local = vector(point);outline.append(local)
			uvs.append((Vector2(f.rect[0], f.rect[1]) + local) / texture(f.file).get_size())
		canvas.draw_polygon(outline, PackedColorArray([tint]), uvs, texture(f.file))
	else:
		canvas.draw_texture_rect_region(texture(f.file), Rect2(Vector2.ZERO, Vector2(f.rect[2], f.rect[3])), Rect2(f.rect[0], f.rect[1], f.rect[2], f.rect[3]), tint)

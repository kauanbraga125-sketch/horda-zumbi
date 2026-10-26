extends SceneTree
var checks = 0
var failures = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1;push_error("V113_FITTING_FAIL " + message)
func _initialize() -> void:
	var fitting = HordeCosmetics.new();fitting.ensure_data()
	check(fitting.frames.size() == 263, "all approved body frames have measurements")
	for key in fitting.frames:
		var f: Dictionary = fitting.frames[key]
		var size = Vector2(f.rect[2],f.rect[3])
		check(f.head_width > 8 and f.head_width < size.x, "valid head size " + key)
		for name in f.meshes:
			var mesh: Dictionary = f.meshes[name]
			check(mesh.indices.size() % 3 == 0, "complete triangles " + key)
			for p in mesh.points:
				check(is_finite(float(p[0])) and is_finite(float(p[1])) and p[0] >= -2 and p[1] >= -2 and p[0] <= size.x + 2 and p[1] <= size.y + 2, "UV mesh stays in its source frame " + key)
			for i in mesh.indices: check(i >= 0 and i < mesh.points.size(), "valid indexed vertex " + key)
		for entry in HordeCosmeticCatalog.ITEMS:
			if entry.kind != f.kind: continue
			var transform = fitting.fit_transform(entry.id, f)
			check(transform.is_finite() and absf(transform.determinant()) > .000001, "noncollapsed attachment " + key + ":" + entry.id)
	for id in fitting.graphics:
		var graphic: Dictionary = fitting.graphics[id]
		var size = fitting.texture(graphic.file).get_size()
		check(Rect2(Vector2.ZERO,size).encloses(Rect2(graphic.rect[0],graphic.rect[1],graphic.rect[2],graphic.rect[3])), "equipment crop bounds " + id)
	print("V113_FITTING checks=",checks," failures=",failures)
	quit(1 if failures else 0)

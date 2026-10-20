extends SceneTree

# Recover original pixels/font bytes from the imported runtime resources.
# This makes the recovered project editable without depending on import caches.
var restored := 0
var missing: Array[String] = []

func _initialize() -> void:
	visit("res://assets")
	print("HORDA_SOURCE_RECOVERY restored=", restored, " unresolved=", missing)
	quit(1 if not missing.is_empty() else 0)

func visit(directory: String) -> void:
	for folder in DirAccess.get_directories_at(directory):
		visit(directory.path_join(folder))
	for filename in DirAccess.get_files_at(directory):
		if not filename.ends_with(".import"): continue
		var imported := directory.path_join(filename)
		var source := imported.trim_suffix(".import")
		if source.get_extension() not in ["png", "ttf", "otf"]: continue
		if FileAccess.file_exists(source): continue
		var config := ConfigFile.new()
		var bytes := FileAccess.get_file_as_bytes(imported)
		while not bytes.is_empty() and bytes[-1] == 0: bytes.resize(bytes.size() - 1)
		var text := bytes.get_string_from_utf8()
		if config.parse(text) != OK:
			missing.append(source)
			continue
		var resource_path := str(config.get_value("remap", "path", ""))
		if resource_path.is_empty(): resource_path = str(config.get_value("remap", "path.etc2", ""))
		if resource_path.is_empty():
			missing.append(source)
			continue
		var resource = load(resource_path)
		if resource is Texture2D and source.ends_with(".png"):
			var image: Image = resource.get_image()
			if image != null and not image.is_empty():
				if image.is_compressed(): image.decompress()
				if image.save_png(source) == OK:
					restored += 1
					continue
		elif resource is FontFile and source.get_extension() in ["ttf", "otf"]:
			var file := FileAccess.open(source, FileAccess.WRITE)
			if file != null and not resource.data.is_empty():
				file.store_buffer(resource.data)
				restored += 1
				continue
		missing.append(source)

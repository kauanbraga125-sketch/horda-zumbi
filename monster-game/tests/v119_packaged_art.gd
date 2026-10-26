extends SceneTree
func _initialize():
 var texture = load("res://assets/art/cosmetics_v119/adventure.png") as Texture2D
 if texture == null:
  push_error("V119_PACKAGED_ART_FAILED: missing adventure hat");quit(1);return
 var image = texture.get_image()
 image.convert(Image.FORMAT_RGBA8)
 var hash = HashingContext.new()
 hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
 var valid = image.get_size() == Vector2i(512,247) and hash.finish().hex_encode() == "2d76e44c41abea1d5d3da20c0cae18724a9f49b0656be1351b659c6c7d822e3f"
 if valid: print("V119_PACKAGED_ART_OK 512x247 lossless pixels verified")
 else: push_error("V119_PACKAGED_ART_FAILED: different pixels or dimensions")
 quit(0 if valid else 1)

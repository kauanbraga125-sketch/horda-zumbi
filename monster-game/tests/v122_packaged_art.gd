extends SceneTree
func _initialize():
 var specs = [["pirate", 512, 324, "41412fb3156b23758928f46d4e1c4844a859259e0cfe27f611308d0ff02020a8"]]
 var failures = 0
 for spec in specs:
  var texture = load("res://assets/art/cosmetics_v122/"+spec[0]+".png") as Texture2D
  if texture == null:
   failures += 1;continue
  var image = texture.get_image();image.convert(Image.FORMAT_RGBA8)
  var hash = HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
  if image.get_size() != Vector2i(spec[1],spec[2]) or hash.finish().hex_encode() != spec[3]: failures += 1
 if failures == 0: print("V122_PACKAGED_ART_OK 1 lossless texture verified")
 else: push_error("V122_PACKAGED_ART_FAILED: "+str(failures))
 quit(0 if failures == 0 else 1)

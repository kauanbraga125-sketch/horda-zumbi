extends SceneTree
func _initialize():
 var specs = [["nightmare", 512, 300, "b7c3f72db32ad4ebac95cbb01beb26a9958548f311b0729486eeb443e47ebd64"], ["sorcerer", 512, 370, "f3a4f0766fd0796af81a3af02aee7eec8e71bded4696433e623043a09dc96ae6"]]
 var failures = 0
 for spec in specs:
  var texture = load("res://assets/art/cosmetics_v120/"+spec[0]+".png") as Texture2D
  if texture == null:
   failures += 1;continue
  var image = texture.get_image();image.convert(Image.FORMAT_RGBA8)
  var hash = HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
  if image.get_size() != Vector2i(spec[1],spec[2]) or hash.finish().hex_encode() != spec[3]: failures += 1
 if failures == 0: print("V120_PACKAGED_ART_OK 2 lossless textures verified")
 else: push_error("V120_PACKAGED_ART_FAILED: "+str(failures))
 quit(0 if failures == 0 else 1)

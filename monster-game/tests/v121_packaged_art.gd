extends SceneTree
func _initialize():
 var specs = [["beanie", 512, 383, "036b9c985d0adb773f779b3754949ae9fa0fb542e0f0cb15506fa25ac9323d6c"], ["sorcerer", 512, 343, "c3b69dd23cfe837080875bf3412d6d3a889b5cf49edce279e82ad0b89147a785"]]
 var failures = 0
 for spec in specs:
  var texture = load("res://assets/art/cosmetics_v121/"+spec[0]+".png") as Texture2D
  if texture == null:
   failures += 1;continue
  var image = texture.get_image();image.convert(Image.FORMAT_RGBA8)
  var hash = HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
  if image.get_size() != Vector2i(spec[1],spec[2]) or hash.finish().hex_encode() != spec[3]: failures += 1
 if failures == 0: print("V121_PACKAGED_ART_OK 2 lossless textures verified")
 else: push_error("V121_PACKAGED_ART_FAILED: "+str(failures))
 quit(0 if failures == 0 else 1)

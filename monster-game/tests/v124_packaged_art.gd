extends SceneTree

func _initialize() -> void:
	var expected = {
		"hockey":{"size":Vector2i(1419,1108),"rgba":"965a171330ed04ea2f13107669bb3e6b914b671896ef1efd6e32b02b891b68d1"},
		"clown":{"size":Vector2i(1508,1043),"rgba":"5fe71801fda4b304c4e53a711ced4d4662568e2fc54260aca4958bc51ed2c8d9"}
	}
	var failures=0
	for name in expected:
		var image: Image=load("res://assets/art/cosmetics_v124/"+name+".png").get_image()
		image.convert(Image.FORMAT_RGBA8)
		var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
		var digest=hash.finish().hex_encode()
		if image.get_size()!=expected[name].size or digest!=expected[name].rgba:
			push_error("New sprite pixel mismatch: "+name);failures+=1
		if name=="hockey":
			for point in [Vector2i(725,547),Vector2i(1093,573)]:
				if image.get_pixelv(point).a>.01:push_error("Mask aperture is not transparent");failures+=1
	print("V124_PACKAGED_ART_", "OK" if failures==0 else "FAILED", " two lossless textures, transparent mask apertures, failures=",failures)
	quit(0 if failures==0 else 1)

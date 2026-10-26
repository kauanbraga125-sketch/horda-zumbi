extends RefCounted
## Shared raw atlas cache; no dependency on editor import state on Android.
static var textures: Dictionary = {}
static var cells: Dictionary = {}

func warm() -> void:
	if not textures.is_empty(): return
	for key in ["fleet","helpers"]:
		var image = Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/adventure_v132/" + key + ".png")) != OK: push_error("Missing adventure art " + key);continue
		textures[key] = ImageTexture.create_from_image(image);cells[key] = []
		for index in range(16):
			var tile = AtlasTexture.new();tile.atlas = textures[key];tile.region = Rect2((index % 4) * 256,int(index / 4) * 256,256,256);tile.filter_clip = true;cells[key].append(tile)

func sprite(c, key: String, frame: int, point: Vector2, size: float, angle: float = 0.0, tint: Color = Color.WHITE, reverse: bool = false) -> void:
	warm()
	if not cells.has(key): return
	c.draw_set_transform(point,angle,Vector2(-1 if reverse else 1,1))
	c.draw_texture_rect(cells[key][posmod(frame,16)],Rect2(Vector2.ONE * -size * .5,Vector2.ONE * size),false,tint)
	c.draw_set_transform(Vector2.ZERO)

func power(c, kind: int, point: Vector2, size: float, time: float) -> void:
	if kind == 5: sprite(c,"helpers",posmod(int(time*6),4),point,size)
	elif kind == 6: sprite(c,"helpers",8+posmod(int(time*6),4),point,size)
	else: sprite(c,"fleet",12 if kind == 7 else 13,point,size,sin(time*2)*.05)

class_name HordePolish
extends RefCounted

const ROOT = "res://assets/art/polish_v101/"
var meta: Dictionary = {}
var textures: Dictionary = {}
var icons: Dictionary = {}

func _init() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "runtime.json"))

func entry(group: String, index: int) -> Dictionary:
	return meta.sets[group].entries[clampi(index, 0, meta.sets[group].entries.size() - 1)]

func texture(group: String) -> Texture2D:
	if not textures.has(group): textures[group] = load(ROOT + group + ".png")
	return textures[group]

func icon(group: String, index: int) -> AtlasTexture:
	var key = group + str(index)
	if not icons.has(key):
		var region: Array = entry(group, index).region
		var item = AtlasTexture.new();item.atlas = texture(group)
		item.region = Rect2(region[0],region[1],region[2],region[3]);item.filter_clip = true
		icons[key] = item
	return icons[key]

func draw(canvas: Node2D, group: String, index: int, center: Vector2, box: Vector2, tint: Color = Color.WHITE, angle: float = 0.0) -> void:
	var image = icon(group,index)
	var scale = minf(box.x / image.get_width(),box.y / image.get_height())
	var size = image.get_size() * scale
	canvas.draw_set_transform(center,angle)
	canvas.draw_texture_rect(image,Rect2(-size*0.5,size),false,tint)
	canvas.draw_set_transform(Vector2.ZERO)

func capture(canvas: Node2D, e: Dictionary, tint: Color) -> void:
	var progress = HordeCaptureMotion.progress(e)
	var phase = clampf(progress * 8.0,0,7)
	var index = floori(phase)
	# The whole body remains visible above the capturer before the final pull down.
	var rise = smoothstep(0.04,0.30,progress)*64.0
	var center = Vector2(e.x,e.y - 54 - rise - sin(progress * PI) * 12)
	center.y += smoothstep(0.82,1.0,progress) * 35
	center.x += sin(progress * PI * 3.0) * 3.0
	var item = entry("capture",index);var r: Array = item.region
	var size = Vector2(r[2],r[3]) * 0.54
	tint.a *= 1.0-smoothstep(0.86,1.0,progress)
	canvas.draw_texture_rect_region(texture("capture"),Rect2(center-size*0.5,size),Rect2(r[0],r[1],r[2],r[3]),tint)

func weapon_switch(canvas: Node2D, e: Dictionary, tint: Color) -> void:
	var start = 0 if str(e.weapon) == "sniper_in" else 4
	var index = start + clampi(int(float(e.weapon_t) / 0.32 * 4),0,3)
	var item = entry("switch",index);var r: Array = item.region;var o: Array = item.offset
	canvas.draw_texture_rect_region(texture("switch"),Rect2(Vector2(e.x,e.y)+Vector2(o[0],o[1])*0.51,Vector2(r[2],r[3])*0.51),Rect2(r[0],r[1],r[2],r[3]),tint)

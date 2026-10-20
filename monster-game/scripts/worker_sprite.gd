class_name HordeWorkerSprite
extends RefCounted

const ROOT = "res://assets/art/trabalhador_corrigido/"
const BODY_HEIGHT = 424.0
const FOOT = Vector2(256, 472)
const CLUMSY_SECONDS = 3.6
const RECOVER_SECONDS = 0.24
const LAB_LABELS = ["DESASTRADO", "DEFESA", "LEVANTANDO", "CAPTURA"]
var sheets: Array[Texture2D] = []
var frames: Dictionary = {}
var expected_pages = 0

func _init() -> void :
	if not FileAccess.file_exists(ROOT + "runtime.json"): return
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "runtime.json"))
	if not metadata is Dictionary: return
	frames = metadata.clips
	expected_pages = metadata.pages.size()
	for page in metadata.pages:
		var texture = load(ROOT + str(page.file)) as Texture2D
		if texture == null or texture.get_size() != Vector2(float(page.size[0]), float(page.size[1])):
			sheets.clear()
			return
		sheets.append(texture)

func has_assets() -> bool:
	return expected_pages > 0 and sheets.size() == expected_pages and frames.size() == 3

static func idle_frame(age: float) -> int:
	return clampi(int(fposmod(age, CLUMSY_SECONDS + RECOVER_SECONDS) / CLUMSY_SECONDS * 36.0), 0, 35)

static func pose(entity: Dictionary) -> Array:
	var age = float(entity.get("worker_time", entity.get("age", 0.0)))
	if entity.get("state", "normal") == "capture":
		var u = HordeCaptureMotion.progress(entity)
		var start = 0.5 if int(entity.get("capture_kind", 0)) == 3 else 0.0
		if u < start: return ["captura", int(age * 25.0) % 30]
		var grip = (u - start) / (1.0 - start)
		if grip < 0.2: return ["captura", mini(9, int(grip / 0.2 * 10.0))]
		return ["transicoes", 3 if grip < 0.4 else (4 if grip < 0.72 else 5)]
	match str(entity.get("worker_clip", "desastrado")):
		"recover": return ["transicoes", clampi(int(age / RECOVER_SECONDS * 3), 0, 2)]
		"defesa": return ["captura", int(age * 25.0) % 30]
	var loop_age = fposmod(age, CLUMSY_SECONDS + RECOVER_SECONDS)
	if loop_age >= CLUMSY_SECONDS:
		return ["transicoes", clampi(int((loop_age - CLUMSY_SECONDS) / RECOVER_SECONDS * 3), 0, 2)]
	return ["desastrado", idle_frame(age)]

func paint(canvas: Node2D, entity: Dictionary, foot: Vector2, height: float = 110.0, tint: Color = Color.WHITE, angle: float = 0.0) -> void :
	if not has_assets(): return
	var selected = pose(entity)
	var entry: Dictionary = frames[selected[0]][selected[1]]
	var r: Array = entry.region
	var region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var trim = Vector2(float(entry.offset[0]), float(entry.offset[1]))
	var shift = Vector2(20, 0) if selected[0] == "transicoes" and selected[1] == 5 else Vector2.ZERO
	var scale = height / BODY_HEIGHT
	canvas.draw_set_transform(foot, angle, Vector2(-1, 1))
	canvas.draw_texture_rect_region(sheets[int(entry.page)], Rect2((trim - FOOT + shift) * scale, region.size * scale), region, tint)
	canvas.draw_set_transform(Vector2.ZERO)

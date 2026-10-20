class_name HordePoliceSprite
extends RefCounted

const ROOT = "res://assets/art/policial_aprovado/"
const BODY_HEIGHT = 304.0
const FOOT = Vector2(256, 352)
const HEIGHT = 112.0
const RUN_FPS = 12.0
const LAB_LABELS = ["CORRIDA", "DEFESA", "CAPTURA", "SUSPENSO", "CORRIDA → CAPTURA"]
const STRIKE = [4, 8, 9, 10, 11, 14, 15, 16]
var sheets: Array[Texture2D] = []
var frames: Dictionary = {}
var expected_pages = 0

func _init() -> void:
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
	return expected_pages > 0 and sheets.size() == expected_pages and frames.get("corrida", []).size() == 12 and frames.get("reacao", []).size() == 36

static func run_frame(age: float, bob: float = 0.0) -> int:
	return posmod(int(floor(age * RUN_FPS + bob * 12.0)), 12)

static func pose(entity: Dictionary) -> Array:
	var age = float(entity.get("age", 0.0))
	if entity.get("state", "normal") == "capture":
		var u = HordeCaptureMotion.progress(entity)
		if int(entity.get("capture_kind", 0)) == 3 and u < 0.5:
			return ["reacao", STRIKE[posmod(int(age * 16.0), STRIKE.size())]]
		var grip = HordeCaptureMotion.grip_progress(entity)
		if grip < 0.24:
			return ["reacao", STRIKE[clampi(int(grip / 0.24 * STRIKE.size()), 0, STRIKE.size() - 1)]]
		return ["reacao", 17 + clampi(int((grip - 0.24) / 0.76 * 16.0), 0, 15)]
	match str(entity.get("police_clip", "corrida")):
		"defesa": return ["reacao", STRIKE[posmod(int(age * 10.0), STRIKE.size())]]
		"suspenso": return ["reacao", 23 + posmod(int(age * 12.0), 10)]
		"idle": return ["reacao", 4 + posmod(int(age * 3.0), 5)]
	return ["corrida", run_frame(age, float(entity.get("bob", 0.0)))]

func paint_frame(canvas: Node2D, clip: String, index: int, foot: Vector2, height: float, tint: Color, angle: float, flip: bool) -> void:
	var entry: Dictionary = frames[clip][index]
	var r: Array = entry.region
	var region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var trim = Vector2(float(entry.offset[0]), float(entry.offset[1]))
	var scale = height / BODY_HEIGHT * float(entry.get("scale_correction", 1.0))
	canvas.draw_set_transform(foot, angle, Vector2(-1.0 if flip else 1.0, 1.0))
	canvas.draw_texture_rect_region(sheets[int(entry.page)], Rect2((trim - FOOT) * scale, region.size * scale), region, tint)
	canvas.draw_set_transform(Vector2.ZERO)

func paint(canvas: Node2D, entity: Dictionary, foot: Vector2, height: float = HEIGHT, tint: Color = Color.WHITE, angle: float = 0.0) -> void:
	if not has_assets(): return
	var selected = pose(entity)
	var flip = float(entity.get("vx", -135.0)) > 0.0
	var mix = 1.0
	if entity.get("state", "normal") == "capture" and int(entity.get("capture_kind", 0)) != 3:
		var grip = HordeCaptureMotion.grip_progress(entity)
		mix = smoothstep(0.0, 0.09, grip)
		if mix < 1.0:
			var elapsed_capture = HordeCaptureMotion.progress(entity) * float(entity.get("capture_duration", 0.62))
			var age = maxf(0.0, float(entity.get("age", 0.0)) - elapsed_capture)
			paint_frame(canvas, "corrida", run_frame(age, float(entity.get("bob", 0.0))), foot, height, tint * Color(1, 1, 1, 1.0 - mix), angle, flip)
	if mix > 0.0:
		paint_frame(canvas, str(selected[0]), int(selected[1]), foot, height, tint * Color(1, 1, 1, mix), angle, flip)

func paint_actor(canvas: Node2D, foot: Vector2, height: float, phase: float, state: String, time: float, tint: Color, reverse: bool) -> void:
	if not has_assets(): return
	var clip = "corrida"
	var index = posmod(int(floor(phase * 12.0)), 12)
	if state in ["idle", "aim"]:
		clip = "reacao";index = 4 + posmod(int(time * 3.0), 5)
	elif state in ["panic", "push"]:
		clip = "reacao";index = STRIKE[posmod(int(time * 10.0), STRIKE.size())]
	elif state in ["capture", "rise", "fall", "fly"]:
		clip = "reacao";index = 17 + clampi(int(clampf(phase, 0.0, 1.0) * 16.0), 0, 15)
	paint_frame(canvas, clip, index, foot, height, tint, 0.0, not reverse)

class_name HordeSkeletonSprite
extends RefCounted

# Approved skeleton animations. This class is used ONLY by monster kind 1.
# The original HordeZombieSprite remains assigned to kind 0.
const SHEET_ROOT = "res://assets/art/esqueleto_aprovado/"
const TILE = Vector2(384, 288)
const COLS = 6
const BODY_HEIGHT = 181.0
const RUN_COUNT = 36
const JUMP_COUNT = 30
const PUSH_COUNT = 36
const CAPTURE_COUNT = 35

var clips: Dictionary = {}

func _init() -> void:
	var entries = {
		"run": "corrida.png",
		"jump": "pulo_pouso.png",
		"push": "quebrar_veiculos.png",
		"capture": "captura.png"
	}
	for clip_name in entries:
		var path = SHEET_ROOT + str(entries[clip_name])
		if ResourceLoader.exists(path):
			clips[clip_name] = load(path) as Texture2D
		else:
			push_warning("Missing skeleton animation: " + path)

static func clip_name_for(state: String, landing: float) -> String:
	match state:
		"run":
			return "jump" if landing > 0.0 else "run"
		"rise", "fly", "fall":
			return "jump"
		"push":
			return "push"
		"capture":
			return "capture"
		_:
			return ""

func has_state(state: String, landing: float) -> bool:
	var clip_name = clip_name_for(state, landing)
	return clip_name != "" and clips.has(clip_name) and clips[clip_name] != null

static func frame_for(state: String, phase: float, time: float, landing: float, air_age: float, vy: float) -> int:
	match state:
		"run":
			if landing > 0.0:
				return clampi(int((0.2 - landing) / 0.2 * 6.0) + 24, 24, 29)
			return posmod(int(fposmod(phase, 1.0) * float(RUN_COUNT)), RUN_COUNT)
		"rise":
			return clampi(int(maxf(0.0, air_age) * 30.0), 0, 11)
		"fly":
			return 12 + posmod(int(time * 9.0), 7)
		"fall":
			return 20 + clampi(int(maxf(0.0, vy) / 140.0), 0, 3)
		"push":
			# The caller passes running phase (unbounded), not push progress.
			return posmod(int(time * 18.0), PUSH_COUNT)
		"capture":
			return clampi(int(clampf(phase, 0.0, 0.999) * float(CAPTURE_COUNT)), 0, CAPTURE_COUNT - 1)
		_:
			return 0

func paint(canvas: Node2D, foot: Vector2, height: float, phase: float, state: String, time: float, landing: float, tint: Color, reverse: bool, air_age: float = -1.0, vertical_speed: float = 0.0) -> void:
	var clip_name = clip_name_for(state, landing)
	if clip_name == "" or not has_state(state, landing):
		return
	var frame_id = frame_for(state, phase, time, landing, air_age, vertical_speed)
	var col = frame_id % COLS
	var row = int(frame_id / COLS)
	var src = Rect2(col * TILE.x, row * TILE.y, TILE.x, TILE.y)
	var scale = height / BODY_HEIGHT
	var size = TILE * scale
	var position = Vector2(-size.x * 0.5, -size.y + 8.0 * scale)
	canvas.draw_set_transform(foot, 0.0, Vector2(-1.0 if reverse else 1.0, 1.0))
	canvas.draw_texture_rect_region(clips[clip_name], Rect2(position, size), src, tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

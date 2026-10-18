class_name HordeSkeletonApprovedSprite
extends RefCounted

# EXCLUSIVE to rig 1 (Esqueleto). Do not use this class for zombie (rig 0).
# Atlas data is from the four approved transparent sheets.
# Real RGBA bounds measured from approved 384x288 cells. No image edits.
# 36-frame running sequence is deliberately slowed, without skipping frames.
const RUN_PHASE_SPEED = 0.40
const RUN_FEET = [240, 242, 245, 249, 245, 242, 248, 252, 249, 249, 241, 249, 248, 249, 249, 243, 246, 255, 246, 247, 241, 247, 248, 249, 234, 235, 241, 241, 242, 241, 232, 238, 239, 238, 236, 230]
const JUMP_FEET = [238, 241, 241, 233, 225, 222, 217, 216, 212, 208, 202, 197, 187, 184, 178, 182, 187, 194, 199, 205, 218, 226, 241, 241, 224, 218, 217, 217, 217, 217]
const ROOT = "res://assets/art/esqueleto_aprovado/"
const TILE_SIZE = Vector2(384, 288)
const COLUMNS = 6
const SHEETS = {
	"run": {"file": "corrida.png", "frames": 36, "visible_height": 181.0, "center_x": 178.0},
	"jump": {"file": "pulo_pouso.png", "frames": 30, "visible_height": 176.0, "center_x": 185.0},
	"push": {"file": "quebrar_veiculos.png", "frames": 36, "visible_height": 205.0, "center_x": 185.0},
	"capture": {"file": "captura.png", "frames": 35, "visible_height": 280.0, "center_x": 192.0},
}

var atlases: Dictionary = {}

func _init() -> void:
	for name in SHEETS:
		var path: String = ROOT + str(SHEETS[name]["file"])
		assert(ResourceLoader.exists(path), "Missing approved skeleton sprite sheet: " + path)
		atlases[name] = load(path) as Texture2D
		assert(atlases[name] != null, "Unable to load approved skeleton sprite sheet: " + path)
		var expected = Vector2i(int(COLUMNS * TILE_SIZE.x), int(ceil(float(SHEETS[name]["frames"]) / COLUMNS) * TILE_SIZE.y))
		assert(Vector2i(atlases[name].get_size()) == expected, "Skeleton sheet atlas geometry mismatch: " + path)

static func clip_for(state: String, landing: float) -> String:
	match state:
		"run":
			return "jump" if landing > 0.0 else "run"
		"rise", "fly", "fall":
			return "jump"
		"push":
			return "push"
		"capture":
			return "capture"
	return ""

func has_state(state: String, landing: float) -> bool:
	var clip := clip_for(state, landing)
	return clip != "" and atlases.has(clip) and atlases[clip] != null

static func frame_for(state: String, phase: float, time: float, landing: float, air_age: float, vertical_speed: float) -> int:
	match state:
		"run":
			if landing > 0.0:
				return clampi(24 + int((0.2 - landing) / 0.2 * 6), 24, 29)
			return posmod(int(fposmod(phase * RUN_PHASE_SPEED, 1.0) * 36.0), 36)
		"rise":
			if air_age >= 0.0:
				return clampi(int(air_age * 35.0), 0, 11)
			return posmod(int(time * 15.0), 12)
		"fly":
			return 12 + posmod(int(time * 9.0), 6)
		"fall":
			return 18 + clampi(int(maxf(0.0, vertical_speed) / 85.0), 0, 5)
		"push":
			return posmod(int(time * 20.0), 36)
		"capture":
			return posmod(int(time * 22.0), 35)
	return 0

static func foot_anchor_for(clip: String, index: int, landing: bool = false) -> float:
	match clip:
		"run":
			return float(RUN_FEET[clampi(index, 0, RUN_FEET.size() - 1)])
		"jump":
			# Start takeoff exactly on the ground. Air frames keep their natural arc.
			# Landing frames return to the ground with no fake hovering.
			if landing or index < 3:
				return float(JUMP_FEET[clampi(index, 0, JUMP_FEET.size() - 1)])
			return 241.0
		"push":
			return 278.0
		"capture":
			return 276.0
	return 244.0

func paint(canvas: Node2D, foot: Vector2, height: float, phase: float, state: String, time: float, landing: float, tint: Color, reverse: bool, air_age: float = -1.0, vertical_speed: float = 0.0) -> void:
	var clip := clip_for(state, landing)
	if not has_state(state, landing):
		return
	var spec: Dictionary = SHEETS[clip]
	var index: int = clampi(frame_for(state, phase, time, landing, air_age, vertical_speed), 0, int(spec["frames"]) - 1)
	var frame_source := Rect2(Vector2(index % COLUMNS * TILE_SIZE.x, int(index / COLUMNS) * TILE_SIZE.y), TILE_SIZE)
	# Use consistent body scale, with a modest size correction for the much wider
	# push and capture drawings. These preserve their intentional stretched poses.
	var scale: float = height / float(spec["visible_height"])
	var size: Vector2 = TILE_SIZE * scale
	var bottom: float = foot_anchor_for(clip, index, clip == "jump" and state == "run" and landing > 0.0)
	var origin: Vector2 = Vector2(-float(spec["center_x"]), -bottom) * scale
	canvas.draw_set_transform(foot, 0.0, Vector2(-1.0 if reverse else 1.0, 1.0))
	canvas.draw_texture_rect_region(atlases[clip], Rect2(origin, size), frame_source, tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

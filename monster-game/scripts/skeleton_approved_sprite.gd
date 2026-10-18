class_name HordeSkeletonApprovedSprite
extends RefCounted

# EXCLUSIVE to rig 1 (Esqueleto). Do not use this class for zombie (rig 0).
# Atlas data is from the four approved transparent sheets.
const ROOT = "res://assets/art/esqueleto_aprovado/"
const TILE_SIZE = Vector2(384, 288)
const COLUMNS = 6
const SHEETS = {
	"run": {"file": "corrida.png", "frames": 36, "visible_height": 181.0, "foot_y": 244.0},
	"jump": {"file": "pulo_pouso.png", "frames": 30, "visible_height": 176.0, "foot_y": 219.0},
	"push": {"file": "quebrar_veiculos.png", "frames": 36, "visible_height": 186.0, "foot_y": 280.0},
	"capture": {"file": "captura.png", "frames": 35, "visible_height": 250.0, "foot_y": 276.0},
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
			return posmod(int(fposmod(phase, 1.0) * 36.0), 36)
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

func paint(canvas: Node2D, foot: Vector2, height: float, phase: float, state: String, time: float, landing: float, tint: Color, reverse: bool, air_age: float = -1.0, vertical_speed: float = 0.0) -> void:
	var clip := clip_for(state, landing)
	if not has_state(state, landing):
		return
	var spec: Dictionary = SHEETS[clip]
	var index: int = clampi(frame_for(state, phase, time, landing, air_age, vertical_speed), 0, int(spec["frames"]) - 1)
	var frame_source := Rect2(Vector2(index % COLUMNS * TILE_SIZE.x, int(index / COLUMNS) * TILE_SIZE.y), TILE_SIZE)
	# Scale by the character's visible height (not the tile height).
	# This keeps capture/vehicle frames from suddenly becoming much larger than run frames.
	var scale: float = height / float(spec["visible_height"])
	var size: Vector2 = TILE_SIZE * scale
	var origin: Vector2 = Vector2(-TILE_SIZE.x * 0.5, -float(spec["foot_y"])) * scale
	canvas.draw_set_transform(foot, 0.0, Vector2(-1.0 if reverse else 1.0, 1.0))
	canvas.draw_texture_rect_region(atlases[clip], Rect2(origin, size), frame_source, tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

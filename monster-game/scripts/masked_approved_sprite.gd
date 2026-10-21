class_name HordeMaskedApprovedSprite
extends RefCounted

const ROOT = "res://assets/art/masked_v104/"
const CELL = Vector2(512, 512)
const COLUMNS = 4
const BODY_HEIGHT = 414.0
const FOOT_ORIGIN = Vector2(224, 480)
const LANDING_SECONDS = 0.48
const FLIP_SECONDS = 0.9
const DAMAGE_SECONDS = 0.64
const TIMINGS = {
	"andando": [143,143,143,143,143,143,143,143],
	"pulo": [60,70,90,90,120,180,150,100],
	"pouso": [40,50,70,50,60,60,70,80],
	"virar_veiculo": [100,100,140,100,80,100,120,160],
	"dano": [70,60,70,70,80,80,90,120],
	"captura": [100,100,80,60,50,60,70,90,120,90,80,100],
}
var textures: Dictionary = {}
var capture_hands: Array = []

func _init() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	if manifest is Dictionary: capture_hands = manifest.get("capture_hands_px", [])
	for clip in TIMINGS:
		var texture = load(ROOT + clip + ".png") as Texture2D
		var rows = ceili(TIMINGS[clip].size() / float(COLUMNS))
		if texture != null and texture.get_size() == CELL * Vector2(COLUMNS, rows):
			textures[clip] = texture

func has_assets() -> bool:
	return textures.size() == TIMINGS.size() and capture_hands.size() == 12

static func animation_for(state: String, landing: float = 0.0) -> String:
	match state:
		"capture": return "captura"
		"push": return "virar_veiculo"
		"panic", "panic_run": return "dano"
		"rise", "fly", "fall": return "pulo"
	return "pouso" if landing > 0.0 else "andando"

static func timed_frame(clip: String, progress: float) -> int:
	var times: Array = TIMINGS[clip]
	var duration = 0.0
	for milliseconds in times: duration += float(milliseconds)
	var cursor = clampf(progress, 0.0, 1.0) * duration
	for i in range(times.size()):
		cursor -= float(times[i])
		if cursor < 0: return i
	return times.size() - 1

static func frame_for(state: String, phase: float, time: float, landing: float = 0.0, air_age: float = -1.0, vertical_speed: float = 0.0) -> int:
	var clip = animation_for(state, landing)
	if clip == "pouso": return timed_frame(clip, 1.0 - landing / LANDING_SECONDS)
	if clip == "pulo":
		# Physics owns the jump. Hold the airborne poses until the actual descent.
		if air_age >= 0.0 and air_age < 0.22:
			return 0 if air_age < 0.06 else (1 if air_age < 0.13 else 2)
		if vertical_speed < -240.0: return 3
		if vertical_speed < -70.0: return 4
		if absf(vertical_speed) <= 70.0: return 5
		return 6 if vertical_speed < 380.0 else 7
	if clip in ["captura", "virar_veiculo", "dano"]: return timed_frame(clip, phase)
	if state in ["idle", "aim"]: return 0
	return posmod(int(floor(maxf(time, 0.0) * 7.0)), 8)

static func draw_rect(height: float) -> Rect2:
	var scale = height / BODY_HEIGHT
	return Rect2(-FOOT_ORIGIN * scale, CELL * scale)

static func push_reach(height: float = 112.0) -> float:
	return (419.0 - FOOT_ORIGIN.x) * height / BODY_HEIGHT

func capture_hand(progress: float, height: float = 112.0) -> Vector2:
	var point: Array = capture_hands[timed_frame("captura", progress)]
	return (Vector2(point[0], point[1]) - FOOT_ORIGIN) * height / BODY_HEIGHT

func paint(canvas: Node2D, foot: Vector2, height: float, phase: float, state: String, time: float, landing: float, tint: Color, reverse: bool, air_age: float, vertical_speed: float) -> void:
	var clip = animation_for(state, landing)
	if not textures.has(clip): return
	var frame = frame_for(state, phase, time, landing, air_age, vertical_speed)
	var region = Rect2(Vector2(frame % COLUMNS, int(frame / COLUMNS)) * CELL, CELL)
	canvas.draw_set_transform(foot, 0.0, Vector2(-1.0 if reverse else 1.0, 1.0))
	canvas.draw_texture_rect_region(textures[clip], draw_rect(height), region, tint)
	canvas.draw_set_transform(Vector2.ZERO)

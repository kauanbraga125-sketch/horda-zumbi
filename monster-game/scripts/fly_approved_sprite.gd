class_name HordeFlyApprovedSprite
extends RefCounted



const ROOT: String = "res://assets/art/mosca_aprovada/"
const CELL: Vector2 = Vector2(384, 288)
const COLUMNS: int = 6
const BODY_HEIGHT: float = 216.0
const FOOT_ORIGIN: Vector2 = Vector2(192, 276)
const PUSH_FRONT_X: float = 326.0
const FPS: float = 20.0
const CAPTURE_SECONDS: float = 36.0 / FPS
const DAMAGE_SECONDS: float = 16.0 / FPS
const TRANSITION_SECONDS: float = 0.08
const AIR_TRANSITION_SECONDS: float = 0.1
const DESCENT_FOR_WING_PHASE: Array[int] = [12, 13, 14, 15, 16, 17, 6, 7, 8, 9, 10, 11]

const IDLE_FRAMES: Array[int] = [0, 0, 0, 5, 13, 5, 0, 0]
const IDLE_FPS: float = 5.0
const ATLAS_INFO = {
	"voo": ["voo_loop.png", 12], 
	"corrida": ["corrida.png", 18], 
	"pouso": ["pouso.png", 18], 
	"captura": ["captura.png", 36], 
	"push": ["push.png", 12], 
	"dano": ["dano.png", 16], 
}
var textures: Dictionary = {}

func _init() -> void :
	for animation in ATLAS_INFO:
		var description: Array = ATLAS_INFO[animation]
		var path: String = ROOT + str(description[0])
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			push_warning("Mosca: missing atlas " + path)
			continue
		var expected_size: = Vector2(CELL.x * COLUMNS, CELL.y * ceili(float(description[1]) / COLUMNS))
		if texture.get_size() != expected_size:
			push_warning("Mosca: invalid atlas grid " + path)
			continue
		textures[animation] = texture

func has_assets() -> bool:
	return textures.size() == ATLAS_INFO.size()

static func animation_for(state: String, _landing: float = 0.0) -> String:
	match state:
		"idle", "aim", "run": return "corrida"
		"rise", "fly": return "voo"
		"fall": return "pouso"
		"capture": return "captura"
		"push": return "push"
		"panic", "panic_run": return "dano"
	return "corrida"

static func clip_key(state: String) -> String:
	return "idle" if state in ["idle", "aim"] else animation_for(state)

static func wing_phase(time: float) -> int:
	return posmod(int(floor(maxf(time, 0.0) * FPS)), 12)

static func frame_for(state: String, phase: float, time: float, _landing: float = 0.0, _vertical_speed: float = 0.0) -> int:
	match state:
		"idle", "aim":
			return IDLE_FRAMES[posmod(int(floor(maxf(time, 0.0) * IDLE_FPS)), IDLE_FRAMES.size())]
		"rise", "fly":
			return wing_phase(time)
		"fall":
			return DESCENT_FOR_WING_PHASE[wing_phase(time)]
		"run":
			return posmod(int(floor(maxf(time, 0.0) * FPS)), 18)
		"push":
			return posmod(int(floor(maxf(time, 0.0) * FPS)), 12)
		"capture":
			return clampi(int(floor(clampf(phase, 0.0, 1.0) * 36.0)), 0, 35)
		"panic", "panic_run":
			return clampi(int(floor(clampf(phase, 0.0, 1.0) * 16.0)), 0, 15)
	return 0

static func action_seconds(state: String) -> float:
	return CAPTURE_SECONDS if state == "capture" else DAMAGE_SECONDS

static func palette_grade_for(_animation: String) -> Color:

	return Color.WHITE

static func transition_duration(from_clip: String, to_clip: String) -> float:
	if from_clip == to_clip: return 0.0
	if from_clip == "dano" or to_clip == "dano":
		return 0.045 if to_clip == "dano" else 0.1
	if from_clip in ["voo", "pouso"] and to_clip in ["voo", "pouso"]:
		return AIR_TRANSITION_SECONDS
	return TRANSITION_SECONDS

static func pivot_y(_animation: String, _frame: int) -> float:
	return FOOT_ORIGIN.y

static func draw_rect(height: float) -> Rect2:
	var scale: = height / BODY_HEIGHT
	return Rect2( - FOOT_ORIGIN * scale, CELL * scale)

static func push_reach(height: float = 112.0) -> float:
	return (PUSH_FRONT_X - FOOT_ORIGIN.x) * height / BODY_HEIGHT

func paint(canvas: Node2D, foot: Vector2, height: float, phase: float, state: String, time: float, landing: float, tint: Color, reverse: bool, _air_age: float, vertical_speed: float) -> void :
	var anim: = animation_for(state, landing)
	if not textures.has(anim): return
	var frame: = frame_for(state, phase, time, landing, vertical_speed)
	var region: = Rect2(float(frame % COLUMNS) * CELL.x, float(int(frame / COLUMNS)) * CELL.y, CELL.x, CELL.y)
	var position: = foot
	var color: = tint
	if state in ["panic", "panic_run"]:
		var age: = clampf(phase, 0.0, 1.0) * DAMAGE_SECONDS
		var flash: = maxf(0.0, 1.0 - age / 0.085)
		var recoil: = sin(clampf(age / 0.23, 0.0, 1.0) * PI)
		position.x -= recoil * 2.0 * height / 112.0

		color *= Color(1.0 + flash * 0.28, 1.0 + flash * 0.15, 1.0 + flash * 0.12, 1.0)
	canvas.draw_set_transform(position, 0.0, Vector2(-1.0 if reverse else 1.0, 1.0))
	canvas.draw_texture_rect_region(textures[anim], draw_rect(height), region, color)
	canvas.draw_set_transform(Vector2.ZERO)

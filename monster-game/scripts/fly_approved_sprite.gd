class_name HordeFlyApprovedSprite
extends RefCounted

# Approved fly-only atlas renderer; all other characters retain their sprites.
const ROOT: String = "res://assets/art/mosca_aprovada/"
const CELL: Vector2 = Vector2(384, 288)
const COLUMNS: int = 6
# Idle/flight is the reference. Different painted bounds need different
# denominators even though every atlas uses identical 384x288 cells.
const BODY_HEIGHT: float = 188.0
const RUN_PHASE_SPEED: float = 0.42
const TRANSITION_SECONDS: float = 0.14
const VISIBLE_HEIGHT = {
	"voo": BODY_HEIGHT,
	"corrida": 216.0,
	"pouso": 236.0,
	"captura": 209.0,
	"push": 216.0,
	"dano": 204.0,
}
const FALL_FPS: float = 16.0
const PUSH_FPS: float = 18.0
const ATLAS_INFO = {
	"voo": ["voo.png", 36],
	"corrida": ["corrida.png", 30],
	"pouso": ["pouso.png", 24],
	"captura": ["captura.png", 36],
	"push": ["push.png", 36],
	"dano": ["dano.png", 16],
}
var textures: Dictionary = {}

func _init() -> void:
	for animation in ATLAS_INFO:
		var description: Array = ATLAS_INFO[animation]
		var path: String = ROOT + str(description[0])
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			push_warning("Mosca: missing atlas " + path)
			continue
		var expected_size: Vector2 = Vector2(CELL.x * COLUMNS, CELL.y * ceili(float(description[1]) / COLUMNS))
		if texture.get_size() != expected_size:
			push_warning("Mosca: invalid atlas grid " + path)
			continue
		textures[animation] = texture

func has_assets() -> bool:
	return textures.size() == ATLAS_INFO.size()

static func animation_for(state: String, landing: float) -> String:
	match state:
		"idle", "rise", "fly", "aim": return "voo"
		"run": return "pouso" if landing > 0.0 else "corrida"
		"fall": return "pouso"
		"capture": return "captura"
		"push": return "push"
		"panic", "panic_run": return "dano"
	return "voo"

static func frame_for(state: String, phase: float, time: float, landing: float, vertical_speed: float) -> int:
	match state:
		"idle", "rise", "fly", "aim":
			return posmod(int(time * 12.0), 36)
		"run":
			if landing > 0.0:
				return clampi(18 + int((0.2 - landing) / 0.2 * 6.0), 18, 23)
			return posmod(int(fposmod(phase * RUN_PHASE_SPEED, 1.0) * 30.0), 30)
		"fall":
			# Velocity alone froze the image at a constant falling speed.
			# Animate all 18 descent frames; frames 18-23 play on landing.
			return posmod(int(maxf(0.0, time) * FALL_FPS), 18)
		"capture":
			# A modest slowdown without altering the 0.62-second capture.
			return clampi(int(clampf(phase * 0.88, 0.0, 1.0) * 35.0), 0, 35)
		"push":
			# Continuous looping throughout a physical vehicle push,
			# independent of the short push_left timer at the bumper.
			return posmod(int(maxf(0.0, time) * PUSH_FPS), 36)
		"panic", "panic_run":
			return clampi(int(clampf(phase, 0.0, 1.0) * 15.0), 0, 15)
	return 0

static func pivot_y(animation: String, frame: int) -> float:
	if animation == "voo": return 242.0
	if animation == "pouso": return 244.0 + roundi(14.0 * float(frame) / 23.0)
	return 258.0

func paint(canvas: Node2D, foot: Vector2, height: float, phase: float, state: String, time: float, landing: float, tint: Color, reverse: bool, _air_age: float, vertical_speed: float) -> void:
	var anim: String = animation_for(state, landing)
	if not textures.has(anim): return
	var frame := frame_for(state, phase, time, landing, vertical_speed)
	var region := Rect2(float(frame % COLUMNS) * CELL.x, float(int(frame / COLUMNS)) * CELL.y, CELL.x, CELL.y)
	var scale := height / float(VISIBLE_HEIGHT[anim])
	var top_left := Vector2(-CELL.x * 0.5, -pivot_y(anim, frame)) * scale
	var position := foot
	if state in ["idle", "fly", "rise"]:
		position.y += sin(time * 7.0) * 1.6
	elif state in ["panic", "panic_run"]:
		position.x += sin(time * 47.0) * 2.0
	canvas.draw_set_transform(position, 0.0, Vector2(-1.0 if reverse else 1.0, 1.0))
	canvas.draw_texture_rect_region(textures[anim], Rect2(top_left, CELL * scale), region, tint)
	canvas.draw_set_transform(Vector2.ZERO)

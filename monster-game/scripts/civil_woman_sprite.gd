class_name HordeCivilWomanSprite
extends RefCounted

# Only civilian variant 1; the other NPCs keep their original rigs.
const ROOT = "res://assets/art/civil-feminina-v0813/"
const TILE = Vector2(256, 256)
const COLUMNS = 6
# Labels and clip order shown ONLY for female civilian in developer NPC sprite lab.
const LAB_CLIPS = ["idle", "startle", "run", "capture"]
const LAB_LABELS = ["PARADA", "SUSTO", "CORRIDA", "QUEDA / CAPTURA"]
const BODY_HEIGHT = 182.0
const FOOT_Y = 244.0
const CLIPS = {
	"idle": {"file": "idle.png", "frames": 36, "fps": 9.0, "loop": true},
	"startle": {"file": "startle.png", "frames": 36, "fps": 36.0, "loop": false},
	"run": {"file": "run.png", "frames": 36, "fps": 27.0, "loop": true},
	"capture": {"file": "capture.png", "frames": 36, "fps": 36.0 / 0.62, "loop": false},
}
var atlases: Dictionary = {}

func _init() -> void:
	for clip_name in CLIPS:
		var spec: Dictionary = CLIPS[clip_name]
		var path: String = ROOT + str(spec["file"])
		if not ResourceLoader.exists(path):
			continue
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			continue
		var expected := Vector2i(int(TILE.x) * COLUMNS, int(TILE.y) * ceili(float(spec["frames"]) / float(COLUMNS)))
		if Vector2i(texture.get_size()) != expected:
			push_warning("Girl sheet geometry mismatch: " + path)
			continue
		atlases[clip_name] = texture

func has_assets() -> bool:
	for clip_name in CLIPS:
		if not atlases.has(clip_name):
			return false
	return true

static func sample(clip_name: String, age: float) -> int:
	var spec: Dictionary = CLIPS.get(clip_name, {})
	if spec.is_empty():
		return 0
	var frame_count: int = int(spec["frames"])
	var frame: int = int(maxf(0.0, age) * float(spec["fps"]))
	return posmod(frame, frame_count) if bool(spec["loop"]) else clampi(frame, 0, frame_count - 1)

func paint(canvas: Node2D, entity: Dictionary, foot: Vector2, height: float = 104.0, tint: Color = Color.WHITE) -> void:
	if not has_assets():
		return
	var clip_name: String = str(entity.get("woman_clip", "idle"))
	if str(entity.get("state", "normal")) == "capture":
		clip_name = "capture"
	if not atlases.has(clip_name):
		clip_name = "idle"
	var age: float = float(entity.get("woman_time", 0.0))
	if clip_name == "capture":
		age = 0.62 - float(entity.get("capture_left", 0.62))
	var frame: int = sample(clip_name, age)
	var src := Rect2(float(frame % COLUMNS) * TILE.x, float(int(frame / COLUMNS)) * TILE.y, TILE.x, TILE.y)
	var scale: float = height / BODY_HEIGHT
	var flip: bool = bool(entity.get("woman_reverse", float(entity.get("vx", 0.0)) < 0.0))
	canvas.draw_set_transform(foot, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	canvas.draw_texture_rect_region(atlases[clip_name], Rect2(Vector2(-TILE.x * 0.5, -FOOT_Y) * scale, TILE * scale), src, tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

class_name HordeCaptureMotion
extends RefCounted


static func progress(entity: Dictionary) -> float:
	var duration = maxf(0.001, float(entity.get("capture_duration", 0.62)))
	return clampf(1.0 - float(entity.get("capture_left", duration)) / duration, 0.0, 1.0)

static func grip_progress(entity: Dictionary) -> float:

	var start = 0.5 if int(entity.get("capture_kind", 0)) == 3 else 0.0
	return clampf((progress(entity) - start) / (1.0 - start), 0.0, 1.0)

static func offset(entity: Dictionary, height: float) -> Vector2:
	var u = grip_progress(entity)
	var lift = smoothstep(0.02, 0.32, u) * height * 0.65
	var sink = smoothstep(0.7, 1.0, u) * height * 0.76
	var wobble = sin(u * TAU * 2.0) * 2.2 * smoothstep(0.1, 0.3, u)
	return Vector2(-12.0 * smoothstep(0.0, 1.0, u), - lift + sink + wobble)

static func angle(entity: Dictionary) -> float:
	var u = grip_progress(entity)
	return sin(u * TAU * 1.5) * 0.1 * smoothstep(0.05, 0.25, u)

static func tint(entity: Dictionary) -> Color:
	return Color(1, 1, 1, 1.0 - smoothstep(0.85, 1.0, grip_progress(entity)))

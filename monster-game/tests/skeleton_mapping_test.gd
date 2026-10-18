extends SceneTree

# The normal zombie must keep HordeZombieSprite; approved frames must be
# available only through HordeSkeletonSprite, used by actor kind 1.
func _initialize() -> void:
	var art = HordeArt.new()
	var actor = HordeActor.new(art)
	if actor.zombie == null or actor.skeleton == null:
		push_error("HORDE_SKELETON_MAPPING_FAIL: sprite renderers not initialized")
		quit(1)
		return
	if actor.zombie is not HordeZombieSprite or actor.skeleton is not HordeSkeletonSprite:
		push_error("HORDE_SKELETON_MAPPING_FAIL: wrong renderer types")
		quit(1)
		return
	for state in ["run", "rise", "fall", "push", "capture"]:
		if not actor.skeleton.has_state(state, 0.0):
			push_error("HORDE_SKELETON_MAPPING_FAIL: missing clip " + state)
			quit(1)
			return
	if not actor.skeleton.has_state("run", 0.1):
		push_error("HORDE_SKELETON_MAPPING_FAIL: landing clip absent")
		quit(1)
		return
	if actor.skeleton.has_state("idle", 0.0):
		push_error("HORDE_SKELETON_MAPPING_FAIL: idle must use original skeleton rig")
		quit(1)
		return
	if HordeSkeletonSprite.CAPTURE_COUNT != 35:
		push_error("HORDE_SKELETON_MAPPING_FAIL: capture count wrong")
		quit(1)
		return
	print("HORDE_SKELETON_MAPPING_OK")
	quit(0)

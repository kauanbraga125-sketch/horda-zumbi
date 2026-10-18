extends SceneTree

# Guard against the exact regression reported by the player:
# Zumbi (kind 0) MUST use original HordeZombieSprite.
# Esqueleto (kind 1) MUST use approved sprite sheets only during active actions.
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("HORDE_SKELETON_ISOLATION_FAIL: " + message)

func _initialize() -> void:
	call_deferred("check_routes")

func check_routes() -> void:
	var actor = HordeActor.new(HordeArt.new())
	check(actor.zombie is HordeZombieSprite, "Zumbi no longer uses original renderer")
	check(actor.skeleton_approved is HordeSkeletonApprovedSprite, "Skeleton renderer not initialized")
	for state in ["run", "rise", "fly", "fall", "push", "capture"]:
		check(actor.renderer_for(0, state, 0.0) == "zombie_original", "Zumbi action changed: " + state)
		check(actor.renderer_for(1, state, 0.0) == "skeleton_approved", "Skeleton action not replaced: " + state)
		check(actor.renderer_for(2, state, 0.0) == "original_rig", "Mascarado affected: " + state)
		check(actor.renderer_for(3, state, 0.0) == "original_rig", "Mosca affected: " + state)
	check(actor.renderer_for(0, "run", 0.11) == "zombie_original", "Zumbi landing altered")
	check(actor.renderer_for(1, "run", 0.11) == "skeleton_approved", "Skeleton landing not replaced")
	check(actor.renderer_for(1, "idle", 0.0) == "original_rig", "Skeleton idle must preserve original rig")
	for clip in HordeSkeletonApprovedSprite.SHEETS:
		var atlas: Texture2D = actor.skeleton_approved.atlases.get(clip) as Texture2D
		check(atlas != null, "Missing skeleton clip: " + str(clip))
		if atlas != null:
			var spec: Dictionary = HordeSkeletonApprovedSprite.SHEETS[clip]
			var expected = Vector2(2304, ceil(float(spec["frames"]) / 6.0) * 288.0)
			check(atlas.get_size() == expected, "Invalid skeleton atlas size: " + str(clip))
	check(HordeSkeletonApprovedSprite.SHEETS["capture"]["frames"] == 35, "Capture frame count mismatch")
	check(HordeSkeletonApprovedSprite.frame_for("capture", 0.0, 999.0, 0.0, 0.0, 0.0) < 35, "Capture reached nonexistent frame")
	if failures.is_empty():
		print("HORDE_SKELETON_ISOLATION_OK")
		quit(0)
	else:
		print("HORDE_SKELETON_ISOLATION_FAIL: " + str(failures.size()) + " regressions")
		quit(1)

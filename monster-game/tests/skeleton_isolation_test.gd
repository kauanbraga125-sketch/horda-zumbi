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
	# Regression checks for the problems found on the in-game sprite testing screen.
	check(HordeSkeletonApprovedSprite.RUN_PHASE_SPEED <= 0.5, "Skeleton running is too fast")
	check(HordeSkeletonApprovedSprite.frame_for("run", 1.0, 1.0, 0.0, -1.0, 0.0) < 20, "Run cycle still rushes through 36 frames")
	check(HordeSkeletonApprovedSprite.RUN_FEET.size() == 36, "Running foot anchors must cover every frame")
	check(HordeSkeletonApprovedSprite.JUMP_FEET.size() == 30, "Jump foot anchors must cover every frame")
	for i in range(36):
		check(HordeSkeletonApprovedSprite.foot_anchor_for("run", i) == float(HordeSkeletonApprovedSprite.RUN_FEET[i]), "Running foot floats on frame " + str(i))
	check(HordeSkeletonApprovedSprite.foot_anchor_for("jump", 0) == 238.0, "Jump first frame is not grounded")
	check(HordeSkeletonApprovedSprite.foot_anchor_for("jump", 24, true) == 224.0, "Jump landing is not grounded")
	check(HordeSkeletonApprovedSprite.foot_anchor_for("push", 0) == 278.0, "Push foot alignment changed")
	check(HordeSkeletonApprovedSprite.foot_anchor_for("capture", 0) == 276.0, "Capture foot alignment changed")
	check(float(HordeSkeletonApprovedSprite.SHEETS["push"]["visible_height"]) > 195.0, "Push sprite still oversized")
	check(float(HordeSkeletonApprovedSprite.SHEETS["capture"]["visible_height"]) > 270.0, "Capture sprite still oversized")
	# Visual size correspondence using measured widths of the approved skulls.
	# At the same requested character height, the skull must not shrink on takeoff.
	var run_skull: float = 60.0 / float(HordeSkeletonApprovedSprite.SHEETS["run"]["visible_height"])
	var jump_skull: float = 52.0 / float(HordeSkeletonApprovedSprite.SHEETS["jump"]["visible_height"])
	check(absf(jump_skull / run_skull - 1.0) < 0.03, "Jump skull size differs from running skull size")
	var run_head_offset: float = (245.0 - float(HordeSkeletonApprovedSprite.SHEETS["run"]["center_x"])) / float(HordeSkeletonApprovedSprite.SHEETS["run"]["visible_height"])
	var jump_head_offset: float = (224.0 - float(HordeSkeletonApprovedSprite.SHEETS["jump"]["center_x"])) / float(HordeSkeletonApprovedSprite.SHEETS["jump"]["visible_height"])
	check(absf(run_head_offset - jump_head_offset) < 0.03, "Jump skull shifts horizontally at the transition")
	check(HordeSkeletonApprovedSprite.SHEETS["capture"]["frames"] == 35, "Capture frame count mismatch")
	check(HordeSkeletonApprovedSprite.frame_for("capture", 0.0, 999.0, 0.0, 0.0, 0.0) < 35, "Capture reached nonexistent frame")
	if failures.is_empty():
		print("HORDE_SKELETON_ISOLATION_OK")
		quit(0)
	else:
		print("HORDE_SKELETON_ISOLATION_FAIL: " + str(failures.size()) + " regressions")
		quit(1)

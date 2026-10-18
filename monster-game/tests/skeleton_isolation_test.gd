extends SceneTree

# Guard against the exact regression reported by the player:
# Zumbi (kind 0) MUST use original HordeZombieSprite.
# Esqueleto (kind 1) MUST use approved sprite sheets only during active actions.
# Mosca (kind 3) MUST use the six approved animation atlases, without affecting other monsters.
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
	check(actor.fly_approved is HordeFlyApprovedSprite, "Fly renderer not initialized")
	check(actor.fly_approved.has_assets(), "Fly atlases missing, empty or wrong geometry")
	for state in ["run", "rise", "fly", "fall", "push", "capture"]:
		check(actor.renderer_for(0, state, 0.0) == "zombie_original", "Zumbi action changed: " + state)
		check(actor.renderer_for(1, state, 0.0) == "skeleton_approved", "Skeleton action not replaced: " + state)
		check(actor.renderer_for(2, state, 0.0) == "original_rig", "Mascarado affected: " + state)
		check(actor.renderer_for(3, state, 0.0) == "fly_approved", "Fly approved sheet not selected: " + state)
	check(actor.renderer_for(0, "run", 0.11) == "zombie_original", "Zumbi landing altered")
	check(actor.renderer_for(1, "run", 0.11) == "skeleton_approved", "Skeleton landing not replaced")
	check(actor.renderer_for(3, "idle", 0.0) == "fly_approved", "Fly idle sheet not selected")
	check(actor.renderer_for(3, "panic", 0.0) == "fly_approved", "Fly damage sheet not selected")
	check(actor.renderer_for(3, "run", 0.11) == "fly_approved", "Fly landing sheet not selected")
	check(HordeFlyApprovedSprite.animation_for("run", 0.0) == "corrida", "Fly run clip invalid")
	check(HordeFlyApprovedSprite.animation_for("run", 0.11) == "pouso", "Fly landing clip invalid")
	check(HordeFlyApprovedSprite.animation_for("fly", 0.0) == "voo", "Fly aerial clip invalid")
	check(HordeFlyApprovedSprite.animation_for("capture", 0.0) == "captura", "Fly capture clip invalid")
	check(HordeFlyApprovedSprite.animation_for("push", 0.0) == "push", "Fly vehicle clip invalid")
	check(HordeFlyApprovedSprite.animation_for("panic", 0.0) == "dano", "Fly damage clip invalid")
	for name in HordeFlyApprovedSprite.ATLAS_INFO:
		var sheet: Texture2D = actor.fly_approved.textures.get(name) as Texture2D
		var frames: int = int(HordeFlyApprovedSprite.ATLAS_INFO[name][1])
		var expect_size: Vector2 = Vector2(2304.0, ceilf(float(frames) / 6.0) * 288.0)
		check(sheet != null, "Missing fly animation: " + name)
		if sheet != null:
			check(sheet.get_size() == expect_size, "Wrong fly atlas geometry: " + name)
	check(HordeFlyApprovedSprite.frame_for("panic", 1.0, 0.0, 0.0, 0.0) == 15, "Damage last frame missing")
	check(HordeFlyApprovedSprite.RUN_PHASE_SPEED < 0.5, "Fly running still too fast")
	check(HordeFlyApprovedSprite.frame_for("run", 1.0, 0.0, 0.0, 0.0) < 20, "Fly run must use slower phase")
	check(HordeFlyApprovedSprite.frame_for("fall", 0.0, 0.0, 0.0, 240.0) == 0, "Fly fall must start on initial descent frame")
	check(HordeFlyApprovedSprite.frame_for("fall", 0.0, 0.5, 0.0, 240.0) == 8, "Fly fall must advance at constant velocity")
	check(HordeFlyApprovedSprite.frame_for("push", 0.0, 0.0, 0.0, 0.0) == 0, "Fly push must begin with its first frame")
	check(HordeFlyApprovedSprite.frame_for("push", 0.0, 1.999, 0.0, 0.0) == 35, "Fly push must play all 36 frames")
	check(HordeFlyApprovedSprite.frame_for("push", 0.0, 2.0, 0.0, 0.0) == 0, "Fly push must loop without freezing")
	check(HordeFlyApprovedSprite.VISIBLE_HEIGHT["corrida"] > HordeFlyApprovedSprite.BODY_HEIGHT, "Fly run scale was not normalized to idle")
	check(HordeFlyApprovedSprite.VISIBLE_HEIGHT["pouso"] > HordeFlyApprovedSprite.VISIBLE_HEIGHT["corrida"], "Fly fall scale was not normalized")
	check(HordeFlyApprovedSprite.TRANSITION_SECONDS > 0.0 and HordeFlyApprovedSprite.TRANSITION_SECONDS <= 0.2, "Fly sprite changes must crossfade quickly")
	# New optional clips route to sheets only after the supplemental ZIP is imported.
	for extra in ["idle", "panic"]:
		var installed: bool = actor.skeleton_approved.atlases.has(extra)
		var route: String = "skeleton_approved" if installed else "original_rig"
		check(actor.renderer_for(1, extra, 0.0) == route, "Skeleton optional route invalid: " + extra)
	for clip in HordeSkeletonApprovedSprite.SHEETS:
		var atlas: Texture2D = actor.skeleton_approved.atlases.get(clip) as Texture2D
		if clip not in ["idle", "panic"]:
			check(atlas != null, "Missing mandatory skeleton clip: " + str(clip))
		if atlas != null:
			var spec: Dictionary = HordeSkeletonApprovedSprite.SHEETS[clip]
			var expected = Vector2(2304, ceil(float(spec["frames"]) / 6.0) * 288.0)
			check(atlas.get_size() == expected, "Invalid skeleton atlas size: " + str(clip))
	# Woman must never replace another civilian when optional sheets are absent.
	var woman := HordeCivilWomanSprite.new()
	if woman.has_assets():
		for clip in HordeCivilWomanSprite.CLIPS:
			var texture: Texture2D = woman.atlases.get(clip) as Texture2D
			check(texture != null, "Missing civilian female clip: " + str(clip))
			if texture != null:
				check(texture.get_size() == Vector2(1536, 1536), "Wrong female tile geometry: " + str(clip))
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
	check(HordeSkeletonApprovedSprite.SHEETS["capture"]["frames"] == 35, "Capture frame count mismatch")
	check(HordeSkeletonApprovedSprite.frame_for("capture", 0.0, 999.0, 0.0, 0.0, 0.0) < 35, "Capture reached nonexistent frame")
	if failures.is_empty():
		print("HORDE_SKELETON_ISOLATION_OK")
		quit(0)
	else:
		print("HORDE_SKELETON_ISOLATION_FAIL: " + str(failures.size()) + " regressions")
		quit(1)

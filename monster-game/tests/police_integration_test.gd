extends SceneTree

var failures: Array[String] = []
var checks = 0

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("POLICE_FAIL: " + message)

func isolated(kind: int = 0) -> HordeRun:
	var run = HordeRun.new()
	run.start(MonsterCatalog.defaults().levels, 902)
	run.entities.clear();run.events.clear();run.next_segment = 99999
	for member in run.members: member.kind = kind
	return run

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var art = HordeArt.new()
	var police = art.police_sprite
	var actor = HordeActor.new(art)
	expect(police.has_assets(), "All approved police assets load")
	for clip in ["corrida", "reacao"]:
		for entry in police.frames[clip]:
			var size = police.sheets[int(entry.page)].get_size()
			var rect = Rect2(float(entry.region[0]), float(entry.region[1]), float(entry.region[2]), float(entry.region[3]))
			expect(Rect2(Vector2.ZERO, size).encloses(rect), "Atlas frame stays inside its texture: " + clip)
	for page in police.sheets:
		expect(page.get_width() <= 2048 and page.get_height() <= 2048, "Police atlas fits 2048px mobile texture budget")
	for state in ["idle", "run", "rise", "fall", "capture", "panic", "push"]:
		expect(actor.renderer_for(8, state, 0.0) == "police_approved", "Police renderer: " + state)
		expect(actor.renderer_for(0, state, 0.0) == "zombie_original", "Original zombie preserved: " + state)
		expect(actor.renderer_for(2, state, 0.0) == "masked_approved", "Approved masked monster preserved: " + state)
		expect(actor.renderer_for(3, state, 0.0) == "fly_approved", "Latest fly preserved: " + state)
	expect(art.worker.has_assets() and art.woman.has_assets(), "Worker and female civilian still load")
	expect(is_equal_approx(HordeFlyApprovedSprite.CAPTURE_SECONDS, 1.8), "Fly capture duration preserved")
	expect(is_equal_approx(HordeFlyApprovedSprite.DAMAGE_SECONDS, 0.8), "Fly damage duration preserved")
	for kind in [0, 3]:
		var run = isolated(kind)
		var person = run.add_entity("police", HordeRun.ANCHOR + 40)
		expect(is_equal_approx(float(person.vx), -135.0), "Police movement speed preserved")
		var count = run.members.size()
		var duration = 1.8 if kind == 3 else 0.62
		run.begin_capture(person, run.members[0])
		expect(is_equal_approx(float(person.capture_duration), duration), "Capture duration matches monster")
		var original = person.duplicate(true)
		for i in range(101):
			var sampled = person.duplicate(true)
			sampled.capture_left = duration * (1.0 - float(i) / 100.0)
			sampled.age = float(i) * duration / 100.0
			var selected = HordePoliceSprite.pose(sampled)
			expect(selected[0] == "reacao" and int(selected[1]) >= 0 and int(selected[1]) <= 32, "Capture has no restart frames")
			if i >= 65:
				expect(int(selected[1]) >= 17, "Late capture stays lifted")
		expect(person == original, "Sampling animation does not mutate gameplay")
		run.update_civilians(duration - 0.01)
		expect(not person.taken and run.members.size() == count, "No early reward")
		run.update_civilians(0.02)
		expect(person.taken and run.members.size() == count + 1 and run.souls == 1 and run.soldiers == 1, "Police converts once")
		run.complete_capture(person)
		expect(run.members.size() == count + 1 and run.souls == 1, "No duplicated capture reward")
		expect(is_equal_approx(float(run.members[-1].y), run.ground_y(float(run.members[-1].x))), "Recruit joins at ground height")
		expect(is_zero_approx(float(run.members[-1].arrival)), "No floating recruit")
	var cancelled = isolated()
	var hostage = cancelled.add_entity("police", HordeRun.ANCHOR + 40)
	cancelled.begin_capture(hostage, cancelled.members[0])
	cancelled.members[0].falling = true
	cancelled.update_civilians(0.7)
	expect(hostage.state == "normal" and not hostage.taken and cancelled.souls == 0, "Losing capturer cancels capture")
	var ended = isolated()
	var remaining = ended.add_entity("police", HordeRun.ANCHOR + 40)
	ended.begin_capture(remaining, ended.members[0]);ended.dead = true
	ended.update_civilians(1.0)
	expect(not remaining.taken and ended.souls == 0, "Game over cannot award capture")
	print("POLICE_INTEGRATION: ", checks, " checks / ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

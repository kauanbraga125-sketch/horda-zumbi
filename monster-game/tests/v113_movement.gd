extends SceneTree
var checks = 0
var failures = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1;push_error("V113_FAIL " + message)
func flat(count: int) -> HordeRun:
	var run = HordeRun.new();run.start_developer("test", count, 0, 113)
	run.next_pattern_world = 1e9;run.next_segment = 99999;run.tutorial_enabled = false
	run.refresh_formation()
	return run
func _initialize() -> void: call_deferred("run_tests")
func run_tests() -> void:
	var run = flat(2)
	run.members[1].x = run.members[0].x
	for _i in range(90): run.advance(1.0 / 120)
	check(absf(run.members[0].x - run.members[1].x) >= 29.5, "two walkers leave overlap")
	run.members[1].x = run.members[0].x;run.jump()
	var due = run.members[1].jump_queue[0].due - run.elapsed
	check(due <= .066 and due >= .064, "pair delay stays responsive")
	for _i in range(14): run.advance(1.0 / 120, true)
	run.release_jump()
	check(absf(run.members[0].x - run.members[1].x) > 1, "overlap corrects while airborne")
	check(run.members[0].hold_open, "original wave still held before recorded release is integrated")
	var hold = float(run.wave_durations[run.jump_sequence])
	check(absf(hold - 14.0 / 120) < .0001, "records exact button hold")
	var leader_id = run.members[0].id
	run.members[1].x = float(run.members[0].x) + 30;run.refresh_formation()
	check(run.members[run.leader_index()].id != leader_id, "front member takes leadership")
	check(run.members[1].formation_rank == 0, "formation follows overtaking member")
	for count in [1, 2, 4, 8, 16, 32, 64]:
		run = flat(count);var slots = {}
		for i in range(count):
			check(run.member_depth(i) == 0, "formation never floats grounded feet")
			var key = str(run.slot_x(i)) + ":" + str(run.member_depth(i))
			check(not slots.has(key), "distinct formation slot " + str(count) + ":" + str(i));slots[key] = true
		run.jump();run.advance(.05, true);run.release_jump()
		for _i in range(150): run.advance(1.0 / 120)
		check(run.members.size() == count, "flat run retains " + str(count))
	check(absf(run.follower_delay(63) - 1.035) < .001, "large horde preserves progressive delay")
	run = flat(1);var m: Dictionary = run.members[0]
	m.y -= 100;m.coyote = 0;m.vy = 0
	var x = float(m.x);m.x = run.reform_x(m, x - 100, .1)
	check(absf(m.x - x) <= 2.801 and absf(m.x - x) > 0, "air correction slower than walking")
	run = flat(1);var a: Dictionary = run.members[0]
	run.add_entity("gap", float(a.x) - 40, HordeRun.FLOOR, 0, 30);run.rebuild_surfaces()
	check(run.reform_x(a, float(a.x) - 25, 1) == a.x, "formation never drags grounded member into a gap")
	run = flat(5)
	var vehicle = run.add_entity("truck", 500)
	vehicle.required_count = 5;vehicle.passengers.clear()
	var edge = float(vehicle.x) - float(vehicle.width) * .5
	for i in range(5): run.members[i].x = edge - 15 - i * 42;run.members[i].y = vehicle.y
	run.update_vehicle(vehicle, .016)
	check(vehicle.taken, "five separated members transmit force through grounded queue")
	run = flat(5);vehicle = run.add_entity("truck",500);vehicle.required_count = 5;vehicle.passengers.clear();edge = float(vehicle.x) - float(vehicle.width) * .5
	for i in range(5): run.members[i].x = edge - 15 - i * 42;run.members[i].y = vehicle.y
	run.members[2].y -= 50;run.members[2].vy = -100
	run.update_vehicle(vehicle,.016)
	check(not vehicle.taken, "airborne member cannot transmit pushing force")
	print("V113_MOVEMENT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

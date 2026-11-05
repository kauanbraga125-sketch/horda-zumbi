extends RefCounted

# Opening sequence teaches both kinds of lift before the generated climb.
const OPENING = [
	[.54, 435.0, "ember"], [1.12, 634.0, "balloon"],
	[1.78, 1040.0, "ember"], [2.58, 1230.0, "bat"], [2.88, 1440.0, "ember"],
	[3.15, 854.0, "ember"], [3.37, 1390.0, "para_ochre"], [3.76, 1425.0, "cloud"],
	[4.27, 1770.0, "ember"], [5.16, 1990.0, "storm"],
	[5.68, 1730.0, "ember"], [5.83, 2170.0, "ember"],
	[6.47, 2260.0, "para_lilac"], [6.76, 2400.0, "ember"], [7.72, 2680.0, "ember"],
	[8.60, 3165.0, "ember"], [8.87, 3220.0, "jetpack"],
]
const Civil = preload("res://scripts/sky_civilians.gd")

var random = RandomNumberGenerator.new()
var gate = 0
var next_x = 0.0
var next_height = 0.0
var speed = 0.0

static func pressure(height: float) -> float:
	return clampf((height - 2400.0) / 9600.0, 0.0, 1.0)

func start(r, sky) -> void:
	random.seed = int(r.run_seed) ^ roundi(r.world_px) ^ 0x5a71
	gate = 0
	speed = r.speed
	var origin = r.world_px + r.ANCHOR
	for entry in OPENING:
		var object: Dictionary = sky.add_object(entry[2], origin + float(entry[0]) * speed, entry[1])
		if Civil.is_civil(entry[2]): object.pass_at = entry[0]
	next_x = origin + 9.30 * speed
	next_height = 3250.0

func fill(r, sky) -> void:
	var horizon = r.world_px + r.view_right + 120.0
	while next_x < horizon:
		place_leg(sky)

func rejoin(r, sky, support: Dictionary) -> void:
	var horizon = r.world_px + r.view_right + 120.0
	for i in range(sky.objects.size() - 1, -1, -1):
		var e: Dictionary = sky.objects[i]
		if e.get("generated", false) and float(e.x) > horizon:
			sky.objects.remove_at(i)
	next_x = float(support.x) + speed * .83
	next_height = float(support.height) + 411.0
	add(sky, "ember", next_x, next_height)
	next_x = float(support.x) + speed * 2.33
	next_height = float(support.height) + 585.0

func add(sky, kind: String, x: float, height: float) -> void:
	var object: Dictionary = sky.add_object(kind, x, height)
	object.generated = true

func place_leg(sky) -> void:
	var difficulty = pressure(next_height)
	# A free lift alone cannot reach the next support. The brasa between
	# them pays for the extra tap if the player times it well.
	var seconds = lerpf(2.35, 2.15, difficulty) + random.randf_range(-.08, .10)
	var rise = lerpf(630.0, 895.0, difficulty) + random.randf_range(-32.0, 37.0)
	var is_cloud = gate % 2 == 0
	add(sky, "cloud" if is_cloud else "balloon", next_x, next_height)
	var pickup_time = lerpf(.84, 1.02, difficulty)
	var lift_speed = 870.0 if is_cloud else 790.0
	var charge_height = next_height + lift_speed * pickup_time - .5 * sky.GRAVITY * pickup_time * pickup_time
	add(sky, "ember", next_x + speed * pickup_time, charge_height - 20.0)
	if difficulty < .48 and gate % 2 == 0:
		add(sky, "ember", next_x + speed * 1.48, next_height + 380.0)

	# Attack lanes leave space to aim at the next support or recover below.
	var obstacle_time = seconds * .60
	var obstacle_height = next_height + rise * .86
	if gate % 3 == 1:
		add(sky, "bat", next_x + speed * obstacle_time, obstacle_height - lerpf(409.0, 244.0, difficulty))
	else:
		add(sky, "storm", next_x + speed * obstacle_time, obstacle_height + lerpf(390.0, 288.0, difficulty))
	if difficulty > .7 and gate % 3 == 2:
		add(sky, "bat", next_x + speed * 1.08, charge_height - 205.0)
	next_x += seconds * speed
	next_height += rise
	gate += 1

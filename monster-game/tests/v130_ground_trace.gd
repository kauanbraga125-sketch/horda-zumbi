extends SceneTree
## Run the same deterministic road/input trace against both packaged versions.
func _initialize() -> void:
	var results = []
	for seed_value in [123,9981,74321,9,1300,881]:
		var r = HordeRun.new()
		r.start({"horde":3,"jump":3},seed_value,0,[0,1],[0,1],[3,2],{})
		var trace = []
		for frame in range(5400):
			if frame % 80 == 0: r.jump()
			var held = frame % 80 < 30
			r.advance(1.0/60.0,held)
			var event_types = []
			for e in r.drain_events(): event_types.append(e.type)
			if frame % 30 == 0 or not event_types.is_empty():
				var members = []
				for m in r.members: members.append([m.id,m.kind,snappedf(m.x,.001),snappedf(m.y,.001),snappedf(m.vy,.001),m.falling])
				trace.append([frame,snappedf(r.world_px,.001),snappedf(r.speed,.001),r.coins,r.souls,r.completed_tunnels,r.perk_kind,members,event_types])
			if r.dead: break
		results.append({"seed":seed_value,"trace":trace,"stats":r.stats()})
	var path = OS.get_environment("HORDA_GROUND_TRACE")
	var f = FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(results));f = null
	print("GROUND_TRACE_OK ",results.size()," courses")
	quit()

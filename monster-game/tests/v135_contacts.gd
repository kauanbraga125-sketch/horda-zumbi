extends SceneTree
## Geometric regressions from the portal/mines video: no grace-period ghosting.
var checks = 0
var failures: Array[String] = []
var observations: Array = []
const DT = 1.0/60
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks += 1
 if not ok: failures.append(label);push_error(label)
func flight(count: int = 8):
 var r = HordeRun.new();r.start_developer("space",count,0,135042);r.developer_kind = "validation"
 r.entities.clear();r.space.begin(r,true);r.space.phase = "flight";r.space.next_group = 1e6
 for i in range(40): r.advance(DT,false)
 r.space.objects.clear();r.events.clear();return r
func run() -> void:
 var solver = preload("res://scripts/space_contacts.gd").new()
 for finish in [Vector2(110,0),Vector2(220,0)]:
  var hit = solver.sweep(Vector2.ZERO,finish,Vector2(100,0),Vector2(100,0),35)
  check(not hit.is_empty() and hit.point.x<66 and hit.normal.x<-.9,"fast motion stays on entry side of solid")
 var moving = solver.sweep(Vector2(90,0),Vector2(90,0),Vector2(180,0),Vector2(100,0),35)
 check(not moving.is_empty() and moving.point.x<66,"moving hazard cannot pass through stationary member")
 check(solver.sweep(Vector2(0,60),Vector2(220,60),Vector2(100,0),Vector2(100,0),35).is_empty(),"clear route stays clear")
 var centred = solver.sweep(Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,35)
 check(not centred.is_empty() and is_finite(centred.point.x),"spawn overlap resolves without NaN")
 for count in [1,4,20,44]:
  for delta in [DT,.1]:
   var r = flight(count);var s = r.space;r.hit_grace = 100
   var centre = s.battle.member_centre(r,0)
   var gate = s.add_object("gate",s.x+170,centre.y+152,{"gap":178.0,"motion":18.0,"speed":1.0,"damage_count":100,"contacts":{}})
   for frame in range(40):
    if frame==8: s.dash()
    r.advance(delta,false)
    var parts = s.contacts.gate_parts(gate)
    if gate in s.objects:
     var minimum = INF;var bad = {}
     for m in r.members:
      var point = Vector2(m.x+s.member_height(r)*.12,m.y-s.member_height(r)*.5)
      for part in parts:
       var distance = point.distance_to(part)
       if distance<minimum: minimum = distance;bad = {"frame":frame,"point":str(point),"part":str(part),"in_scene":gate in s.objects,"root":str(Vector2(s.x,s.y))}
     var required = 63+maxf(18,s.member_height(r)*.26)-1.5
     if minimum<required and observations.size()<5: print("CONTACT_PROBE ",count," ",delta," ",bad," distance=",minimum," need=",required)
     check(minimum>=required,"survivors remain outside visible solids: %d dt %.3f" % [count,delta])
   check(r.active_count()==count,"damage grace and exhausted damage budget preserve count")
   observations.append({"members":count,"delta":delta,"root_x":s.x,"root_y":s.y})
 var rock = flight(4);var rs = rock.space;rock.hit_grace = 100
 var solid = rs.add_object("rock",rs.x+100,rs.y-48,{"radius":48.0,"speed":0.0})
 rs.dash();rock.advance(.1,false)
 check(not solid.taken and rock.active_count()==4,"shielded dash does not delete solid scenery")
 rs.drag_by(Vector2(80,-170))
 for i in range(100): rock.advance(DT,false)
 check(rs.y<280 and not rock.dead,"player can steer away from contact and resume flight")
 var pilot = flight(8);var ps = pilot.space;ps.battle.pilot_left = 5;ps.battle.pilot_hp = 3;ps.battle.pilot_kind = "tour_bus"
 var obstacle = ps.add_object("rock",ps.x-270,ps.y-48,{"radius":48.0,"speed":0.0})
 var old_x = ps.x
 check(solver.push(ps,pilot,obstacle,Vector2(obstacle.x,obstacle.y),48,"space_rock")==0 and ps.x==old_x,"hidden old members cannot collide outside visible pilot hull")
 # Rise must visibly travel, not just change the layer label.
 var rise = flight(20);var s = rise.space;var initial_foot = float(rise.members[0].y);var initial_sky = s.sky_scroll;var seconds = s.left
 var old_object = s.add_object("rock",900,280,{"radius":48.0,"speed":.2})
 s.boost(rise)
 for i in range(60): rise.advance(DT,false)
 check(s.phase=="boost" and s.sky_scroll-initial_sky>400 and s.climb_speed>700,"rise moves scenery down with acceleration")
 check(initial_foot-float(rise.members[0].y)>80,"rise moves the horde upward on screen")
 check(absf(s.left-seconds)<.01,"cinematic rise does not consume playable flight time")
 check(float(old_object.y)>500 and not old_object.taken,"old objects depart downward instead of vanishing")
 check(HordeActor.space_pose("launch",1,-600).angle<-.5,"launch faces upward")
 check(absf(HordeActor.space_pose("dash",1,0).angle)<.2,"horizontal dash has its own pose")
 for i in range(70): rise.advance(DT,false)
 check(s.phase=="flight" and s.zone()==1,"rise settles into next layer")
 # A death is emitted at the actual airborne foot with its fitted accessories.
 var death = flight(4);death.members[0].cosmetics_0 = ["z_plumber"];death.members[0].kind = 0
 var foot = Vector2(death.members[0].x,death.members[0].y);death.space.battle.hurt(death.space,death,0,"space_rock",foot,true)
 var event: Dictionary = death.events.filter(func(e):return e.type=="hit")[0]
 check(bool(event.in_space) and Vector2(event.foot_x,event.foot_y).distance_to(foot)<.01,"space loss uses its airborne location")
 check(event.space_wear==["z_plumber"],"ejected member retains its own accessory")
 var g = load("res://main.tscn").instantiate();root.add_child(g);await process_frame;g.set_process(false);g.set_physics_process(false);g.runner = death
 g.consume_run_events()
 check(g.effects.deaths.is_empty() and g.runner.space.visual.casualties.size()==1,"space loss never spawns a ground coffin or ground shadow")
 g.sound.set_enabled(false);g.queue_free();g = null
 for i in range(6): await process_frame
 var folder = OS.get_environment("HORDA_VALIDATION_DIR")
 if not folder.is_empty():
  DirAccess.make_dir_recursive_absolute(folder);var f = FileAccess.open(folder+"/contacts.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"  "));f.close()
 print("V135_CONTACTS checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)

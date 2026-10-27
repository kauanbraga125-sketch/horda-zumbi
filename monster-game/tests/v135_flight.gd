extends SceneTree
## Play contracts: freedom, trajectory replay, authored routes and the same run.
var checks = 0
var failures: Array[String] = []
var report: Array = []
const DT = 1.0/60
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks += 1
 if not ok: failures.append(label);push_error(label)
func flight(count: int = 8):
 var r = HordeRun.new();r.start_developer("space",count,0,134042)
 r.developer_kind = "validation";r.entities.clear();r.events.clear();r.space.begin(r,true)
 r.space.phase = "flight";r.space.phase_age = 0;r.space.next_group = 1e6
 ticks(r,40);r.space.objects.clear();r.events.clear();return r
func ticks(r,n: int) -> void:
 for i in range(n): r.advance(DT,false)
func run() -> void:
 for count in [1,4,8,16,20,44,88]:
  var r = flight(count);var s = r.space;var ids = r.members.map(func(m):return m.id);var initial_x = s.x
  check(s.steering_bounds(r)==Vector2(249,579),"same vertical freedom "+str(count))
  s.drag_by(Vector2(100,-160));ticks(r,22)
  check(s.y<280 and s.x>400,"responsive diagonal steering "+str(count))
  var first = s.battle.member_centre(r,0)
  check(absf(first.y-(s.y-s.member_height(r)*.5))<25,"leader follows control promptly "+str(count))
  s.drag_by(Vector2(-110,350));ticks(r,50)
  check(s.y>570 and absf(s.x-(initial_x-10))<5,"leader reaches bottom and moves back "+str(count))
  check(r.members.map(func(m):return m.id)==ids,"flight preserves member IDs "+str(count))
  for m in r.members:
   check(float(m.y)>=220 and float(m.y)<=610 and float(m.x)>=r.view_left+20,"tail stays visible "+str(count))
  report.append({"count":count,"bounds":str(s.steering_bounds(r)),"last_lag":s.follower_lag(count-1,int(s.formation(r).strands))})
 var trail = flight(44);var ts = trail.space;ts.aim_y = 260;ticks(trail,18)
 check(absf(float(trail.members[0].y)-float(trail.members[-1].y))>45,"large tail replays earlier trajectory")
 check(ts.follower_lag(19,2)>ts.follower_lag(7,1),"extra reaction delay starts after sixteen")
 var stable = flight(20);var ribbons = stable.space.formation(stable).strands
 stable.add_member(0,false);check(stable.space.formation(stable).strands==ribbons,"rescue never reshuffles the entire horde")
 var idle = flight();ticks(idle,600)
 check(idle.space.charge==0 and idle.space.wave_number==1,"waiting alone grants no impulse")
 var soul = flight();var before = soul.active_count();var peak = soul.max_horde
 var npc = soul.space.add_object("astronaut",soul.space.x,soul.space.y-45)
 ticks(soul,60)
 check(soul.active_count()==before+1 and soul.souls==1 and soul.max_horde==maxi(peak,before+1),"rescue grows the real horde, souls and record")
 check(soul.space.charge>=16,"rescue earns impulse")
 # Full rows grant the bonus only for that row, never from a previous event.
 var coin = flight();var row = coin.new_coin_row(3)
 coin.space.add_object("coin",coin.space.x,coin.space.y-45,{"speed":0.0,"coin_row":row})
 coin.space.add_object("coin",coin.space.x+10,coin.space.y-45,{"speed":0.0,"coin_row":row})
 coin.space.add_object("coin",coin.space.x+5,coin.space.y-45,{"speed":0.0,"coin_row":row});ticks(coin,1)
 check(is_equal_approx(coin.space.charge,14.5),"perfect row earns exact impulse")
 row = coin.new_coin_row(3);coin.space.add_object("coin",coin.space.x,coin.space.y-45,{"speed":0.0,"coin_row":row});ticks(coin,1)
 check(is_equal_approx(coin.space.charge,16),"old Perfect cannot complete another row")
 # Charges arm a physical exit; they do not erase an ongoing fight.
 var exit = flight();exit.space.charge = 100
 var enemy = exit.space.add_object("meteor",900,300)
 ticks(exit,1);check(exit.space.phase=="flight" and enemy in exit.space.objects,"full bar does not erase threats")
 exit.space.add_object("exit",exit.space.x,exit.space.y-45,{"speed":0.0,"radius":58.0});ticks(exit,1)
 check(exit.space.phase=="boost","crossing armed exit launches the horde")
 ticks(exit,130);check(exit.space.zone()==1 and exit.space.wave_number==2,"launch reaches next layer")
 # A successful dash allows another, but never cancels the active dash.
 var combo = flight(20);var cs = combo.space
 cs.dash();var ship = cs.battle.spawn_ship(cs,combo,"fighter",cs.x+85,cs.y-45);ticks(combo,2)
 check(ship.taken and cs.chain==1 and cs.dash_cooldown<.2,"ship dash refills chain window")
 check(not cs.dash(),"active dash cannot be restarted every frame")
 ticks(combo,27);check(cs.dash(),"chain permits the next timed dash")
 var shield = flight();var ss = shield.space;var saucer = ss.battle.spawn_ship(ss,shield,"saucer",ss.x+70,ss.y-45)
 saucer.counter = true;saucer.fired = false;saucer.lock_y = ss.y-45;var hp = int(saucer.hp);before = shield.active_count()
 ss.dash();ticks(shield,1)
 check(int(saucer.hp)==hp and shield.active_count()==before-1,"closed alien shield requires dodging")
 var open = flight(20);var os = open.space;saucer = os.battle.spawn_ship(os,open,"saucer",os.x+85,os.y-45)
 saucer.counter = true;saucer.fired = true;saucer.age = 2.0;saucer.lock_y = os.y-45;os.dash();ticks(open,1)
 check(saucer.taken,"exposed alien core rewards counterattack")
 # Solid obstacles require movement even during a dash.
 var gate = flight(4);var gs = gate.space;before = gate.active_count();gs.dash()
 gs.add_object("gate",gs.x+50,520,{"gap":150.0,"speed":0.0,"contacts":{},"damage_count":0});ticks(gate,12)
 check(gate.active_count()<before,"dash cannot ignore a closed gate")
 var safe = flight(4);before = safe.active_count()
 safe.space.add_object("gate",safe.space.x+10,safe.space.y-safe.space.member_height(safe)*.5,{"gap":180.0,"speed":0.0,"contacts":{},"damage_count":0});ticks(safe,120)
 check(safe.active_count()==before,"aligned small horde fits through safe passage")
 # Actual director: variants, time-to-contact across displays, bounded object count.
 var kinds = {}
 for layer in range(4):
  for width in [960.0,1280.0,1800.0]:
   var r = flight(20);r.view_left = 0;r.view_right = width;var s = r.space;s.altitude = [0.0,1100.0,2150.0,3400.0][layer]
   var contact = (s.routes.at(s,r,3)-s.x)/s.battle.scroll_speed(r)
   check(absf(contact-3)<.01,"reaction time independent of aspect ratio")
   for i in range(5):
    s.objects.clear();s.routes.start(s,r)
    for e in s.objects: kinds[e.kind] = true
    check(s.objects.size()<32,"bounded objects per authored encounter")
    for e in s.objects:
     if e.kind=="gate": check(float(e.gap)>=150,"gate remains reachable for small horde")
 for kind in ["coin","astronaut","gate","tour_bus","fighter","cargo","saucer","ghost_frigate","vortex","rock","drone","egg","boarding"]:
  check(kinds.has(kind),"authored encounters include "+kind)
 var rhythm = flight(12);rhythm.hit_grace = 100;rhythm.space.next_group = 0;ticks(rhythm,1500)
 check(rhythm.space.routes.history.size()>=3,"director presents multiple encounters in thirty seconds")
 check(rhythm.space.objects.size()<50,"encounters never pile up")
 # All members lost in space ends the same run and keeps the space backdrop.
 var fatal = flight(1);fatal.space.battle.hurt(fatal.space,fatal,0,"space_rock",Vector2.ZERO,true);ticks(fatal,1)
 check(fatal.dead and fatal.active_count()==0 and fatal.space.active,"full horde loss ends run in space")
 var land = flight(44);var ids = land.members.map(func(m):return m.id);var world = land.world_px
 land.space.left = .001;ticks(land,150)
 check(not land.space.active and not land.dead and land.active_count()==44,"large horde returns safely")
 check(land.members.map(func(m):return m.id)==ids and land.world_px>world+600,"landing preserves IDs and advances main course")
 check(land.hit_grace>0 and land.recovery_left>0,"landing offers a short safe road")
 var out = OS.get_environment("HORDA_VALIDATION_DIR")
 if not out.is_empty():
  DirAccess.make_dir_recursive_absolute(out);var f = FileAccess.open(out+"/flight.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"control":report,"director":rhythm.space.routes.history},"  "));f.close()
 print("V135_FLIGHT checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)

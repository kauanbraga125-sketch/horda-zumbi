extends SceneTree
class RecordingActor extends HordeActor:
	var calls:Array=[]
	func _init(source:HordeArt) -> void:super(source)
	func paint(_canvas:Node2D,kind:int,_foot:Vector2,_height:float,_phase:float,_state:String="run",_time:float=0,_landing:float=0,_tint:Color=Color.WHITE,_reverse:bool=false,_pose_mix:float=1.0,_show_prop:bool=true,_air_age:float=-1,_vertical_speed:float=0,wear:Array=[]) -> void:
		calls.append({"kind":kind,"wear":wear.duplicate()})
var game
var canvas:Node2D
var viewport:SubViewport
var recorder:RecordingActor
var checks=0
var failures:Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func draw_world() -> void:
	game.paint_target=canvas
	game.draw_run()
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	game=load("res://main.tscn").instantiate();viewport.add_child(game);game.hide();game.test_mode=true;game.capture_mode=true;game.set_process(false);game.set_physics_process(false)
	recorder=RecordingActor.new(game.art);game.actor=recorder
	canvas=Node2D.new();viewport.add_child(canvas);canvas.draw.connect(draw_world)
	for kind in [0,1]:
		game.runner.start_developer("sprites",6,1,129)
		game.runner.entities.clear()
		var expected=["z_plumber"] if kind==0 else ["s_punk","s_hourglass"]
		for m in game.runner.members:
			m.kind=kind;m["cosmetics_"+str(kind)]=expected.duplicate()
		game.runner.transform_kind=3;game.runner.transform_from_kind=-1;game.runner.transform_left=game.runner.transform_duration*.5
		recorder.calls.clear();canvas.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		var source_calls=recorder.calls.filter(func(v):return v.kind==kind)
		var transformed_calls=recorder.calls.filter(func(v):return v.kind==3)
		check(not source_calls.is_empty(),"Original species rendered during transformation")
		check(not transformed_calls.is_empty(),"Power-up species rendered during transformation")
		for call in source_calls:check(call.wear==expected,"Worn accessories retained until source fades")
		for call in transformed_calls:check(call.wear.is_empty(),"No incompatible items on power-up")
		var member=game.runner.members[0]
		for state in ["run","rise","fly","fall","push","capture","panic","idle"]:
			check(game.runner.cosmetics_for(member,kind)==expected,"Same item identity in "+state)
	print("V129_TRANSFORM_",("OK" if failures.is_empty() else "FAILED")," checks=",checks," failures=",failures)
	game.queue_free();canvas.queue_free();viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

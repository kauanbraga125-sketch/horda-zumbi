extends Node2D

const TIMES = [0.07,0.06,0.07,0.07,0.08,0.08,0.09,0.12]
var actor: AnimatedSprite2D
var material_effect: ShaderMaterial
var elapsed := 0.0
var automatic := true
var manual := false
var manual_age := 0.0

func _ready() -> void:
	actor = AnimatedSprite2D.new()
	actor.sprite_frames = load("res://mascarado_dano.tres")
	assert(actor.sprite_frames.get_frame_count("dano")==8)
	assert(not actor.sprite_frames.get_animation_loop("dano"))
	actor.animation = "dano"
	actor.position = Vector2(400,316)
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	material_effect = ShaderMaterial.new()
	material_effect.shader = preload("res://dano_flash.gdshader")
	actor.material = material_effect
	add_child(actor)
	apply_time(0)
	print("DAMAGE_PREVIEW_OK frames=8 loop=false duration=0.64")

func _process(delta: float) -> void:
	if automatic:
		elapsed += delta
		if manual:
			manual_age += delta
			apply_time(manual_age)
			if manual_age>1.15: manual = false
		else: apply_time(fposmod(elapsed,2.2)-0.50)

func apply_time(time: float) -> void:
	var at := 0.0
	var frame := 7 if time>=0.64 else 0
	if time>=0 and time<0.64:
		for i in range(TIMES.size()):
			at += float(TIMES[i])
			if time<at:
				frame = i
				break
	actor.frame = frame
	material_effect.set_shader_parameter("hit_flash",maxf(0.0,1.0-absf(time-0.09)/0.07) if time>=0 else 0.0)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and event.keycode==KEY_SPACE) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		manual = true
		manual_age = 0.0
		apply_time(0)

func _draw() -> void:
	draw_rect(Rect2(0,0,800,600),Color("1e152b"))
	draw_rect(Rect2(0,526,800,74),Color("15101f"))
	draw_line(Vector2(0,526),Vector2(800,526),Color("675168"),2,true)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(30,38),"MASCARADO · REAÇÃO AO DANO",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("ffd087"))
	draw_string(font,Vector2(30,65),"Impacto · recuo · recuperação",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a9dcc5"))
	draw_string(font,Vector2(30,575),"Toque ou aperte espaço para repetir",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("baabc6"))

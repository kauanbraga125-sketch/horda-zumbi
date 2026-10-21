extends Node2D
var actor: AnimatedSprite2D
var age := 0.0
func _ready() -> void:
	actor = AnimatedSprite2D.new()
	actor.sprite_frames = load("res://mascarado_andando.tres")
	actor.position = Vector2(400,316)
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(actor)
	actor.play("andando")
func _process(delta: float) -> void:
	age += delta
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(0,0,800,600),Color("1e152b"))
	draw_rect(Rect2(0,526,800,74),Color("15101f"))
	draw_line(Vector2(0,526),Vector2(800,526),Color("675168"),2,true)
	for i in range(-1,12):
		var x := i*85-fposmod(age*125,85)
		draw_line(Vector2(x,550),Vector2(x+28,550),Color("3c2c48"),2,true)
	draw_string(ThemeDB.fallback_font,Vector2(30,38),"MASCARADO · CAMINHADA",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("ffd087"))
	draw_string(ThemeDB.fallback_font,Vector2(30,65),"Passos curtos · arma baixa · loop contínuo",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a9dcc5"))

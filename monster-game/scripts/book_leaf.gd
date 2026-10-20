extends Node2D

var book
var game
var entry: Dictionary = {}
var number := 1
var side := 0
var reveal := 1.0
var owned := false
var portrait := Sprite2D.new()

func _init() -> void:
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var effect := ShaderMaterial.new()
	effect.shader = preload("res://scripts/codex_illustration.gdshader")
	portrait.material = effect
	add_child(portrait)

func _draw() -> void:
	if game == null or book == null: return
	var previous = game.paint_target
	game.paint_target = self
	book.paint_leaf(game, self)
	game.paint_target = previous

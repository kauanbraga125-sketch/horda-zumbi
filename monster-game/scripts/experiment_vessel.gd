class_name HordeExperimentVessel
extends Node2D
var liquid: ColorRect
var frame: TextureRect
var specimens: Array[Sprite2D] = []
var rect = Rect2()
var pane = Rect2()
var level = -1
var variant: Dictionary = {}
func _init() -> void:
	z_index=2
	liquid=ColorRect.new();liquid.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material=ShaderMaterial.new();material.shader=preload("res://scripts/experiment_liquid.gdshader");liquid.material=material;add_child(liquid)
	for i in range(2):
		var sprite=Sprite2D.new();var mat=ShaderMaterial.new();mat.shader=preload("res://scripts/experiment_specimen.gdshader");sprite.material=mat
		add_child(sprite);specimens.append(sprite)
	frame=TextureRect.new();frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.texture=HordeExperimentArt.texture("machine");frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;add_child(frame)
func place(box: Rect2) -> void:
	var tex = frame.texture
	var size = tex.get_size()*minf(box.size.x/tex.get_width(),box.size.y/tex.get_height())
	rect=Rect2(box.get_center()-size*0.5,size)
	pane=Rect2(rect.position+rect.size*Vector2(0.3,0.2314),rect.size*Vector2(0.3985,0.4932))
	frame.position=rect.position;frame.size=rect.size;liquid.position=pane.position;liquid.size=pane.size
func animate(shown_level: int, amount: float, clock: float, energy: float, fade: float = 1.0) -> void:
	if level!=shown_level:
		level=shown_level;variant=HordeExperimentArt.variant(level)
		for i in range(2): specimens[i].texture=HordeExperimentArt.texture("specimen_"+variant.objects[i])
	modulate.a=fade
	for material in [liquid.material,specimens[0].material,specimens[1].material]:
		material.set_shader_parameter("amount",clampf(amount,0,1));material.set_shader_parameter("liquid",variant.color)
		material.set_shader_parameter("clock",clock);material.set_shader_parameter("energy",energy);material.set_shader_parameter("speed",variant.speed)
	var shake = Vector2(sin(clock*73)*1.5,cos(clock*57)*0.6)*energy
	position=shake
	for i in range(2):
		var sprite=specimens[i];var id: String=variant.objects[i]
		var size = pane.size.x*0.5
		var pulse = 1.0+sin(clock*3.6+i)*0.045 if id in ["brain","heart","egg"] else 1.0
		sprite.scale=Vector2.ONE*size/maxi(sprite.texture.get_width(),sprite.texture.get_height())*pulse
		if id=="eye": sprite.scale.y*=1.0-0.85*pow(maxf(0,sin(clock*1.25+i)),40)
		sprite.position=pane.position+pane.size*Vector2(0.29+i*0.42,clampf(1.0-amount*0.53+i*0.18,0.4,0.88))+Vector2(sin(clock*0.9+i*3.2)*pane.size.x*0.04,sin(clock*1.4+i*2.4)*pane.size.y*0.018)
		sprite.rotation=sin(clock*0.8+i*2.8)*0.13
		var origin = global_transform*pane.position
		sprite.material.set_shader_parameter("pane_origin",origin)
		sprite.material.set_shader_parameter("pane_size",pane.size*global_transform.get_scale())
		sprite.material.set_shader_parameter("creature",1.0 if id in ["tentacle","ghost","hand","larva","bat"] else 0.0)

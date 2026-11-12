extends SceneTree

# A labelled art inspection, separate from the normal gameplay recording.
const Pop = preload("res://scripts/sky_pop_encounters.gd")
const Regions = preload("res://scripts/sky_region_scenery.gd")
const Atmosphere = preload("res://scripts/sky_atmosphere.gd")
const Deep = preload("res://scripts/sky_deep_landscape.gd")
const Motion = preload("res://scripts/sky_motion.gd")
const PARTS = [
	["worm",9.5,-2680.0,4.5,"BRUMA · O VERME E O VIAJANTE"],
	["kaiju",7.5,-5020.0,9.0,"TEMPESTADE · DUELO DOS GIGANTES"],
	["orbit",8.0,-8170.0,20.0,"CEMITÉRIO ORBITAL · A CAÇADA"],
	["time_car",7.0,-10450.0,27.0,"UNIVERSO · UMA VISITA DO FUTURO"]
]

class World extends Node2D:
	var motion = Motion.new()
	var part: Array
	var age = 0.0
	func _draw() -> void:
		var view = Rect2(0,part[2],1600,900)
		var camera = Vector2(8000,view.position.y)
		if part[0] in ["worm","kaiju"]:
			draw_rect(view,Color("241340"))
			Atmosphere.clouds(self,motion,view,camera*.085+Vector2(age*5,0),false,1.0)
			Regions.paint_air(self,motion,view,camera,age,1.0)
			Pop.paint_air(self,motion,view,camera,age,1.0)
			Atmosphere.clouds(self,motion,view,camera*.26+Vector2(age*12,0),true,1.0)
		else:
			draw_rect(view,Color("080817"))
			if part[0]=="orbit":
				draw_texture_rect(motion.frames.orbit_sky.texture,view,false,Color(.55,.40,.53))
				Regions.paint_orbit(self,motion,view,camera,age,1.0)
			else:Deep.paint_background(self,motion,view,camera,age,1.0)
			Pop.paint_orbit(self,motion,view,camera,age,1.0)

class Labels extends Node2D:
	var heading = ""
	func _draw() -> void:
		var font = ThemeDB.fallback_font
		draw_rect(Rect2(0,0,1280,90),Color(.025,.02,.055,.9))
		draw_string(font,Vector2(30,34),"PRÉVIA DAS ANIMAÇÕES · câmera de inspeção",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("c7c3d7"))
		draw_string(font,Vector2(30,70),heading,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("d8e8ed"))
		draw_string(font,Vector2(30,694),"Encontros decorativos · posições fixas no mundo · v0.10.66",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("cbc4dc"))

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var folder = OS.get_environment("HORDA_VALIDATION_DIR")
	assert(not folder.is_empty())
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720)
	var world = World.new()
	world.scale = Vector2(.8,.8)
	world.motion.warm()
	root.add_child(world)
	var labels = Labels.new()
	root.add_child(labels)
	var frame = 0
	for part in PARTS:
		world.part = part
		world.position = Vector2(0,-part[2]*.8)
		labels.heading = part[4]
		labels.queue_redraw()
		for local_frame in range(int(part[1]*30)):
			world.age = part[3]+local_frame/30.0
			world.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_jpg(folder+"/frame-%05d.jpg"%frame,.90)==OK)
			frame += 1
		print("V166_INSPECTION ",part[0]," complete")
	print("V166_INSPECTION_OK ",frame," frames")
	quit()

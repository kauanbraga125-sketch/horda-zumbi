extends SceneTree

func sole(image: Image) -> Dictionary:
	var y_max := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a>0.4: y_max = y
	var x_min := image.get_width()
	var x_max := 0
	for y in range(maxi(0,y_max-22),y_max+1):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a>0.4:
				x_min = mini(x_min,x)
				x_max = maxi(x_max,x)
	return {"y":y_max,"x":(x_min+x_max)/2.0}

func _initialize() -> void:
	var image := Image.load_from_file("res://fonte_mascarado_dano.png")
	var reference := sole(Image.load_from_file("res://referencias/caminhada_aprovada.png"))
	var cell := Vector2i(444,444)
	var atlas := Image.create(cell.x*4,cell.y*2,false,Image.FORMAT_RGBA8)
	atlas.fill(Color(0,0,0,0))
	var ready_pose: Image
	for i in range(8):
		var col := i%4
		var row := i/4
		var left := roundi(col*image.get_width()/4.0)
		var top := roundi(row*image.get_height()/2.0)
		var right := roundi((col+1)*image.get_width()/4.0)
		var bottom := roundi((row+1)*image.get_height()/2.0)
		var region := image.get_region(Rect2i(left,top,right-left,bottom-top))
		var contact := sole(region)
		var shift := Vector2i(roundi(float(reference.x)-float(contact.x)),int(reference.y)-int(contact.y))
		var frame := Image.create(cell.x,cell.y,false,Image.FORMAT_RGBA8)
		frame.fill(Color(0,0,0,0))
		frame.blit_rect(region,Rect2i(Vector2i.ZERO,region.get_size()),shift)
		if i==0: ready_pose = frame.duplicate()
		if i==7: frame = ready_pose.duplicate()
		frame.save_png("res://frames/mascarado_dano_%02d.png"%(i+1))
		atlas.blit_rect(frame,Rect2i(Vector2i.ZERO,cell),Vector2i(col*cell.x,row*cell.y))
		print("DAMAGE_FRAME ",i+1," registration=",shift," contact=",sole(frame))
	atlas.save_png("res://mascarado_dano.png")
	print("DAMAGE_FRAMES_OK frames=8 frame_px=444x444")
	quit()

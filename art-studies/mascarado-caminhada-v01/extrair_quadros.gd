extends SceneTree
func _initialize() -> void:
	var image := Image.load_from_file("res://fonte_mascarado_andando.png")
	var cell := Vector2i(ceili(image.get_width()/4.0),ceili(image.get_height()/2.0))
	var atlas := Image.create(cell.x*4,cell.y*2,false,Image.FORMAT_RGBA8)
	atlas.fill(Color(0,0,0,0))
	for i in range(8):
		var col := i%4
		var row := i/4
		var left := roundi(col*image.get_width()/4.0)
		var top := roundi(row*image.get_height()/2.0)
		var right := roundi((col+1)*image.get_width()/4.0)
		var bottom := roundi((row+1)*image.get_height()/2.0)
		var region := image.get_region(Rect2i(left,top,right-left,bottom-top))
		var sole := 0
		for y in range(region.get_height()):
			for x in range(region.get_width()):
				if region.get_pixel(x,y).a>0.4: sole = y
		var frame := Image.create(cell.x,cell.y,false,Image.FORMAT_RGBA8)
		frame.fill(Color(0,0,0,0))
		var shift := cell.y-12-sole
		assert(region.get_used_rect().position.y+shift>=0)
		frame.blit_rect(region,Rect2i(Vector2i.ZERO,region.get_size()),Vector2i(0,shift))
		frame.save_png("res://frames/mascarado_andando_%02d.png"%(i+1))
		atlas.blit_rect(frame,Rect2i(Vector2i.ZERO,cell),Vector2i(col*cell.x,row*cell.y))
		print("MASCARADO_FRAME ",i+1," used=",frame.get_used_rect()," vertical_registration=",shift)
	atlas.save_png("res://mascarado_andando.png")
	print("MASCARADO_FRAMES_OK dimensions=",cell," count=8")
	quit()

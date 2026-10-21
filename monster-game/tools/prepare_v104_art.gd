extends SceneTree

const SIZE := Vector2i(512,512)
const MASK_ROOT := "res://assets/art/masked_v104/"
const PROFILE_ROOT := "res://assets/art/profile_v104/"
const PROFILE_IDS := ["record","distance","runs","souls","horde","coins","vehicles","tunnels","time"]
const LOSS_IDS := ["fall","camera","air_bomb","rushing_car","bullet","rocket_explosion","bomb","helicopter","spikes","crate","hump","vehicle"]

func rect(values: Array) -> Rect2i:
	return Rect2i(int(values[0]),int(values[1]),int(values[2]),int(values[3]))

func _initialize() -> void:
	var source := ProjectSettings.globalize_path("res://").path_join("../art-source/v0.10.4").simplify_path()
	var extraction: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("extraction.json")))
	for group in ["profile_icons","loss_icons"]:
		var image := Image.load_from_file(source.path_join(group+".png"))
		var ids: Array = PROFILE_IDS if group=="profile_icons" else LOSS_IDS
		for i in range(ids.size()):
			var icon := image.get_region(rect(extraction[group][i]))
			icon.save_png(PROFILE_ROOT+("profile_" if group=="profile_icons" else "loss_")+str(ids[i])+".png")
	var panels := Image.load_from_file(source.path_join("stat_panels.png"))
	for i in range(2):
		var panel := panels.get_region(rect(extraction.panels[i]))
		panel.resize(256,roundi(panel.get_height()*256.0/panel.get_width()),Image.INTERPOLATE_LANCZOS)
		panel.save_png(PROFILE_ROOT+("panel.png" if i==0 else "featured.png"))
	var metadata := {"origin_px":[224,480],"body_height_px":414,"frame_px":[512,512],"columns":4,"clips":{}}
	var v02: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("mascarado_animacoes_v02.json")))
	for name in ["andando","pulo","pouso","virar_veiculo"]:
		var times: Array = []
		for frame in v02.animations[name].frames: times.append(int(frame.duration_ms))
		metadata.clips[name] = {"file":name+".png","frames":8,"duration_ms":int(v02.animations[name].duration_ms),"times_ms":times}
	var ready := Image.load_from_file(MASK_ROOT+"andando.png").get_region(Rect2i(0,0,512,512))
	for name in ["dano","captura"]:
		var original := Image.load_from_file(source.path_join("mascarado_"+name+".png"))
		var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("mascarado_"+name+".json")))
		var count := 8 if name=="dano" else 12
		var cell := Vector2i(444,444) if name=="dano" else Vector2i(512,444)
		var offset := Vector2i(-12,48) if name=="dano" else Vector2i(-20,48)
		var atlas := Image.create(2048,512*ceili(float(count)/4),false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		var times: Array = []
		var hands: Array = []
		for i in range(count):
			var frame := Image.create(512,512,false,Image.FORMAT_RGBA8)
			frame.fill(Color.TRANSPARENT)
			if i==0 or i==count-1:
				frame = ready.duplicate()
			else:
				var crop := original.get_region(Rect2i((i%4)*cell.x,(i/4)*cell.y,cell.x,cell.y))
				var bounds := crop.get_used_rect()
				frame.blit_rect(crop,bounds,bounds.position+offset)
			atlas.blit_rect(frame,Rect2i(Vector2i.ZERO,SIZE),Vector2i((i%4)*512,(i/4)*512))
			times.append(int(old.frames[i].duration_ms))
			if name=="captura":
				var hand: Array = old.frames[i].hand_grip_px
				hands.append([float(hand[0])+offset.x,float(hand[1])+offset.y])
		atlas.save_png(MASK_ROOT+name+".png")
		metadata.clips[name] = {"file":name+".png","frames":count,"duration_ms":640 if name=="dano" else 1000,"times_ms":times}
		if name=="captura": metadata.capture_hands_px = hands
	FileAccess.open(MASK_ROOT+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"  ")+"\n")
	FileAccess.open(PROFILE_ROOT+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify({"profile":PROFILE_IDS,"losses":LOSS_IDS,"source":"Approved profile and loss concepts; builtin image_gen artwork; native dynamic values"},"  ")+"\n")
	print("V104_ART_READY icons=21 panels=2 masked_clips=6")
	quit()

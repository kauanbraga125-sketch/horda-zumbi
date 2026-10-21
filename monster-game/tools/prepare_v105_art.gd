extends SceneTree
const ROOT = "res://assets/art/experiment_v105/"
const SPECIMENS = ["brain","eye","hand","mask","tentacle","ghost","larva","egg","vhs","skull","fang","heart","bat","mushroom","leaves","vial"]
const MISSIONS = [["souls","coins","distance","vehicles","jumps","bonuses","horde","fly"],["frenzy","soldier","tunnel","groups","passengers","moto","bus","truck"],["tank","plane","mask_power","skeleton","shield","bombs","clean_tunnel","survival"]]
func _initialize() -> void:
	var src = ProjectSettings.globalize_path("res://../art-source/v0.10.5/")
	var meta = JSON.parse_string(FileAccess.get_file_as_string(src+"extraction.json"))
	var machine = Image.load_from_file(src+"machine.png")
	machine.resize(600,roundi(600.0*machine.get_height()/machine.get_width()),Image.INTERPOLATE_LANCZOS);machine.save_png(ROOT+"machine.png")
	for group in ["specimens","missions_a","missions_b","missions_c"]:
		var source = Image.load_from_file(src+group+".png")
		var ids: Array = SPECIMENS if group=="specimens" else MISSIONS[["missions_a","missions_b","missions_c"].find(group)]
		for i in range(ids.size()):
			var b: Array = meta[group][i];var icon = source.get_region(Rect2i(b[0],b[1],b[2],b[3]))
			var scale = minf(1.0,(220.0 if group=="specimens" else 380.0)/maxi(icon.get_width(),icon.get_height()))
			icon.resize(maxi(1,roundi(icon.get_width()*scale)),maxi(1,roundi(icon.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
			icon.save_png(ROOT+("specimen_" if group=="specimens" else "mission_")+ids[i]+".png")
	FileAccess.open(ROOT+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify({"pane":meta.pane,"specimens":SPECIMENS,"mission_art":MISSIONS[0]+MISSIONS[1]+MISSIONS[2],"source":"Approved generated resurrection machine, 16 specimens, 24 mission illustrations; continuous native liquid"},"  ")+"\n")
	print("V105_ART_READY machine=1 specimens=16 illustrations=24");quit()

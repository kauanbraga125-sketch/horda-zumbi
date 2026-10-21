class_name HordeMissionCatalog
extends RefCounted
const FILE = "res://assets/art/experiment_v105/missions.json"
static var templates: Array = []
static func all() -> Array:
	if templates.is_empty(): templates = JSON.parse_string(FileAccess.get_file_as_string(FILE)).templates
	return templates
static func template(id: String) -> Dictionary:
	for item in all():
		if item.id == id: return item
	return {}
static func make(item: Dictionary, serial: int) -> Dictionary:
	var m = item.duplicate(true)
	for key in ["target","ritual","difficulty","min_level","power","area"]: m[key]=int(m[key])
	m.template = item.id;m.serial = serial;m.id = "m"+str(serial)+":"+str(item.id)
	m.key = "v105:"+str(serial)+":"+str(item.id);m.title = str(item.title).replace("{n}",str(int(item.target)))
	return m
static func initialize(data: Dictionary) -> void:
	data.mission_schema = 2;data.mission_serial = 3;data.mission_history = [];data.mission_slots = []
	for i in range(3): data.mission_slots.append(make(all()[i],i))
static func active(data: Dictionary) -> Array[Dictionary]:
	if not data.get("mission_slots",null) is Array or data.mission_slots.size()!=3: initialize(data)
	var result: Array[Dictionary] = []
	for m in data.mission_slots: result.append(m)
	return result
static func eligible(item: Dictionary, data: Dictionary) -> bool:
	if int(data.player_level)<int(item.min_level): return false
	var power = int(item.power)
	if power == 1 and 1 not in data.owned: return false
	if power in [2,3] and power not in data.power_owned: return false
	return int(item.area)<0 or int(item.area) in data.areas
static func next_for(data: Dictionary, slot: int) -> Dictionary:
	var difficulty = mini(slot+1,3 if int(data.player_level)>=7 else (2 if int(data.player_level)>=3 else 1))
	var ids = [];var families = []
	for i in range(3):
		if i!=slot: ids.append(data.mission_slots[i].get("template",""));families.append(data.mission_slots[i].art)
	var pool = [];var recent = [];var varied = []
	for m in all():
		if eligible(m,data) and int(m.difficulty)==difficulty and m.id not in ids:
			pool.append(m)
			if m.id not in data.mission_history:
				recent.append(m)
				if m.art not in families: varied.append(m)
	var candidates = varied if not varied.is_empty() else (recent if not recent.is_empty() else pool)
	if candidates.is_empty(): candidates = [all()[0]]
	return make(candidates[posmod(int(data.mission_serial)*13+slot*7,candidates.size())],int(data.mission_serial))
static func replace_completed(data: Dictionary, slot: int) -> bool:
	var old: Dictionary = active(data)[slot]
	if old.key not in data.claimed: return false
	data.mission_history.append(old.get("template",old.id))
	while data.mission_history.size()>16: data.mission_history.pop_front()
	data.mission_slots[slot] = next_for(data,slot);data.mission_serial += 1
	data.mission_progress.erase(old.id);data.mission_progress[data.mission_slots[slot].id]=0;data.claimed.erase(old.key)
	data.mission_tier = maxi(int(data.mission_tier),int(data.missions_completed)/3)
	return true
static func advance(data: Dictionary, values: Dictionary, previous: Dictionary, baselines: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for m in active(data):
		if m.key in data.claimed: continue
		var current = maxi(0,int(values.get(m.stat,0)))
		if m.mode=="best" and baselines.has(m.key):
			# Challenges requiring a whole run or a peak start on the following run.
			# This prevents rotating completed peak objectives into free repeat rewards.
			continue
		var count = maxi(0,int(data.mission_progress.get(m.id,0)))
		count = count+maxi(0,current-int(previous.get(m.stat,0))) if m.mode=="sum" else maxi(count,current)
		data.mission_progress[m.id] = mini(count,int(m.target))
		if count>=int(m.target): data.claimed.append(m.key);data.missions_completed+=1;result.append(m)
	return result
static func legacy_art(stat: String) -> String:
	return str({"souls":"souls","coins":"coins","distance":"distance","cars":"vehicles","jumps":"jumps","bonuses":"bonuses","horde":"horde","flights":"fly","boost":"frenzy","soldiers":"soldier","tunnels":"tunnel","groups":"groups","rescues":"passengers"}.get(stat,"souls"))
static func legacy_item(item: Dictionary, tier: int) -> Dictionary:
	var m = item.duplicate(true);m.legacy=true;m.art=legacy_art(str(m.stat));m.difficulty=1 if tier<2 else 2
	return m
static func migrate(data: Dictionary, raw: Dictionary, legacy: Array[Dictionary]) -> void:
	var old_claimed: Array = data.claimed.duplicate()
	data.mission_schema = 2;data.mission_serial=clampi(int(raw.get("mission_serial",3)),3,99999999);data.mission_history=[]
	var history = raw.get("mission_history",[])
	if history is Array:
		for id in history.slice(-16):
			if id is String and id.length()<60: data.mission_history.append(id)
	var restored: Array = [];var keys = {}
	if int(raw.get("mission_schema",0))>=2 and raw.get("mission_slots",null) is Array:
		for slot in raw.mission_slots.slice(0,3):
			if not slot is Dictionary: continue
			var trusted = {}
			if bool(slot.get("legacy",false)):
				var key = str(slot.get("key",""));var tier = clampi(int(key.get_slice(":",0)),0,9999)
				for old in MonsterCatalog.active_missions(tier):
					if old.key==key: trusted=legacy_item(old,tier)
			else:
				var item = template(str(slot.get("template","")));var serial = int(slot.get("serial",-1))
				if not item.is_empty() and serial>=0 and serial<int(data.mission_serial): trusted=make(item,serial)
			if not trusted.is_empty() and not keys.has(trusted.key): restored.append(trusted);keys[trusted.key]=true
	if restored.size()!=3:
		restored=[]
		for old in legacy: restored.append(legacy_item(old,int(data.mission_tier)))
	data.mission_slots=restored;data.mission_progress={};data.claimed=[]
	var progress = raw.get("mission_progress",{});var claimed = old_claimed if int(raw.get("version",0))==1 else raw.get("claimed",[])
	for m in restored:
		data.mission_progress[m.id]=clampi(int(progress.get(m.id,0)) if progress is Dictionary else 0,0,int(m.target))
		if claimed is Array and m.key in claimed: data.mission_progress[m.id]=int(m.target);data.claimed.append(m.key)

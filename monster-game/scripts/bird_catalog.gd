extends RefCounted
## Collection rules are independent of animation, rendering and the run RNG.
const IDS = ["pipoco","fiapo","ferrugem","agourinho","barao"]
const RARITIES = ["CLÁSSICA","SUPER","HIPER","ULTRA","LENDÁRIA"]
const COLORS = [Color("9ce4aa"),Color("71ded5"),Color("79b8ff"),Color("c994ff"),Color("ffce73")]
const WEIGHTS = [60.0,25.0,10.0,4.0,1.0]
const NAMES = ["PIPOCO","FIAPO","FERRUGEM","AGOURINHO","BARÃO GOELA"]
const PERSONALITIES = ["Uma barriga enorme. Uma fome maior ainda.","Magrelo, medroso e sempre vendo perigo.","Metade corvo. Metade sucata. Inteiro mau humor.","Três olhos. Um segredo. Nenhum pio normal.","Sua excelência exige espaço para a barriga."]
const HINTS = ["Enche as bochechas antes de cuspir um pequeno tesouro.","Perninhas finas, garras firmes. Volta sempre com companhia.","Está sempre procurando algo para desmontar.","Não gosta de despedidas definitivas.","Só faz uma entrada triunfal depois de bons saltos."]
const PRICE = 30
const FUSION_PRICE = 0
const ESSENCE_NEEDED = 6
const BARS_PER_BIRD = 3

static func defaults() -> Dictionary:
	return {"bird_copies":{},"bird_essence":{},"bird_discovered":{},"bird_equipped":"","bird_equipped_slots":["",""],"bird_draws":0,"bird_rare_pity":0,"bird_legend_pity":0,"bird_pending":{},"bird_serial":0}

static func tier(id: String) -> int: return IDS.find(id)

static func copies(data: Dictionary,id: String) -> int:
	return clampi(int(data.get("bird_copies",{}).get(id,0)),0,100000)

static func level(data: Dictionary,id: String) -> int: return mini(3,copies(data,id))

static func discovered(data: Dictionary,id: String) -> bool:
	if id not in IDS:return false
	if bool(data.get("bird_discovered",{}).get(id,false)):return true
	if copies(data,id)<=0:return false
	var pending: Dictionary = data.get("bird_pending",{})
	return not (str(pending.get("id",""))==id and bool(pending.get("new",false)) and str(pending.get("source","draw"))=="draw" and int(pending.get("taps",0))<3)

static func available(data: Dictionary,id: String) -> bool:
	return copies(data,id)>0 and discovered(data,id)

static func equipped_slots(data: Dictionary) -> Array:
	var result = ["",""]
	var raw = data.get("bird_equipped_slots",[data.get("bird_equipped",""),""])
	if not raw is Array:return result
	if raw.all(func(value):return str(value).is_empty()) and str(data.get("bird_equipped","")).length()>0:raw = [data.bird_equipped,""]
	for i in range(mini(2,raw.size())):
		var id = str(raw[i])
		if available(data,id) and (i==0 or id!=result[0]):result[i] = id
	return result

static func fusion_eligible(data: Dictionary,id: String) -> bool:
	return tier(id)>=0 and tier(id)<IDS.size()-1 and available(data,id) and copies(data,id)>=BARS_PER_BIRD

static func fusion_result(first: String,second: String) -> String:
	if first==second or tier(first)<0 or tier(second)<0 or tier(first)>=IDS.size()-1 or tier(second)>=IDS.size()-1:return ""
	return IDS[maxi(tier(first),tier(second))+1]

static func can_fuse(data: Dictionary,first: String,second: String) -> bool:
	return not fusion_result(first,second).is_empty() and data.get("bird_pending",{}).is_empty() and fusion_eligible(data,first) and fusion_eligible(data,second)

static func fusion_pair(data: Dictionary,preferred: String = "") -> Array:
	var result = ["",""]
	if fusion_eligible(data,preferred):result[0] = preferred
	for id in IDS:
		if id in result or not fusion_eligible(data,id):continue
		if str(result[0]).is_empty():result[0] = id
		elif str(result[1]).is_empty():result[1] = id;break
	return result

static func unlock_receipt(data: Dictionary) -> void:
	var pending: Dictionary = data.get("bird_pending",{})
	var id = str(pending.get("id",""))
	if id not in IDS or int(pending.get("taps",0))<3 or copies(data,id)<=0:return
	if not data.has("bird_discovered") or not data.bird_discovered is Dictionary:data.bird_discovered = {}
	data.bird_discovered[id] = true
	var slots: Array = equipped_slots(data)
	if str(slots[0]).is_empty() and slots[1]!=id:slots[0] = id
	data.bird_equipped_slots = slots;data.bird_equipped = slots[0]

static func migrate(raw: Dictionary) -> Dictionary:
	var safe = defaults()
	for field in ["bird_copies","bird_essence"]:
		if raw.get(field) is Dictionary:
			for id in IDS:
				var value = raw[field].get(id,0)
				if value is int or value is float: safe[field][id] = clampi(int(value),0,100000)
	for key in ["bird_draws","bird_serial","bird_rare_pity","bird_legend_pity"]:
		var value = raw.get(key,0)
		if value is int or value is float: safe[key] = clampi(int(value),0,1000000)
	safe.bird_rare_pity = mini(9,safe.bird_rare_pity);safe.bird_legend_pity = mini(49,safe.bird_legend_pity)
	if raw.get("bird_discovered",{}) is Dictionary:
		for id in IDS:
			var value = raw.get("bird_discovered",{}).get(id,false)
			if value is bool and value:safe.bird_discovered[id] = true
	var receipt = raw.get("bird_pending",{})
	if receipt is Dictionary and receipt.get("id","") in IDS:
		var id = str(receipt.id)
		if copies(safe,id)>0:
			var essence = receipt.get("essence",0)
			if not (essence is int or essence is float): essence = 0
			safe.bird_pending = {"id":id,"serial":maxi(1,int(safe.bird_serial)),"level":level(safe,id),"new":bool(receipt.get("new",false)),"essence":clampi(int(essence),0,1),"taps":clampi(int(receipt.get("taps",0)),0,3),"source":"fusion" if receipt.get("source","")=="fusion" else "draw"}
			var stage = str(receipt.get("stage","reveal" if int(safe.bird_pending.taps)>=3 else "egg"))
			if stage not in ["crate","egg","fusion","reveal"]:stage = "egg"
			if safe.bird_pending.source=="fusion":
				safe.bird_pending.taps = 3;stage = "fusion" if stage=="fusion" else "reveal"
				var inputs = receipt.get("inputs",[])
				if inputs is Array and inputs.size()==2 and str(inputs[0]) in IDS and str(inputs[1]) in IDS and str(inputs[0])!=str(inputs[1]):
					safe.bird_pending.inputs = [str(inputs[0]),str(inputs[1])];safe.bird_pending.input = str(inputs[0])
				else:
					# Old fusions were already awarded: keep that reward and skip the
					# obsolete animation instead of consuming any new birds.
					safe.bird_pending.inputs = [];stage = "reveal"
			elif int(safe.bird_pending.taps)>=3:stage = "reveal"
			elif stage in ["reveal","fusion"]:stage = "egg"
			safe.bird_pending.stage = stage
	for id in IDS:
		if discovered(safe,id):safe.bird_discovered[id] = true
	var slots = raw.get("bird_equipped_slots",[raw.get("bird_equipped",""),""])
	if slots is Array and slots.all(func(id):return str(id).is_empty()) and str(raw.get("bird_equipped","")).length()>0:slots = [raw.bird_equipped,""]
	if slots is Array:
		for i in range(mini(2,slots.size())):
			var id = str(slots[i])
			if available(safe,id) and (i==0 or id!=safe.bird_equipped_slots[0]):safe.bird_equipped_slots[i] = id
	safe.bird_equipped = safe.bird_equipped_slots[0]
	return safe

static func add_copy(data: Dictionary,id: String,source: String) -> Dictionary:
	var old = copies(data,id)
	var known = discovered(data,id)
	data.bird_copies[id] = mini(100000,old+1)
	var essence = 1 if old>=3 else 0
	if essence: data.bird_essence[id] = mini(100000,int(data.bird_essence.get(id,0))+1)
	data.bird_serial = int(data.bird_serial)+1
	var receipt = {"id":id,"serial":data.bird_serial,"level":level(data,id),"new":not known,"essence":essence,"taps":3 if source=="fusion" else 0,"source":source,"stage":"fusion" if source=="fusion" else "crate"}
	data.bird_pending = receipt.duplicate()
	if source=="fusion":unlock_receipt(data)
	return receipt

static func roll(data: Dictionary,random: RandomNumberGenerator) -> Dictionary:
	# Pending means the item was already paid, awarded and saved: never reroll it.
	if not data.get("bird_pending",{}).is_empty(): return {}
	var price = PRICE
	if int(data.eyes)<price: return {}
	var result = 0
	if int(data.bird_legend_pity)>=49: result = 4
	elif int(data.bird_rare_pity)>=9:
		var n = random.randf()*15.0
		result = 2 if n<10 else 3 if n<14 else 4
	else:
		var n = random.randf()*100.0
		for i in range(5):
			n -= WEIGHTS[i]
			if n<0: result = i;break
	data.eyes = int(data.eyes)-price;data.bird_draws = int(data.bird_draws)+1
	data.bird_rare_pity = 0 if result>=2 else int(data.bird_rare_pity)+1
	data.bird_legend_pity = 0 if result==4 else int(data.bird_legend_pity)+1
	return add_copy(data,IDS[result],"draw")

static func fuse(data: Dictionary,first: String,second: String = "") -> Dictionary:
	if not can_fuse(data,first,second):return {}
	var result = fusion_result(first,second)
	if not data.get("bird_discovered") is Dictionary:data.bird_discovered = {}
	for id in [first,second]:
		data.bird_discovered[id] = true
		data.bird_copies[id] = copies(data,id)-BARS_PER_BIRD
		data.bird_essence[id] = maxi(0,copies(data,id)-BARS_PER_BIRD)
	var slots = equipped_slots(data)
	data.bird_equipped_slots = slots;data.bird_equipped = slots[0]
	var receipt = add_copy(data,result,"fusion")
	receipt.inputs = [first,second];receipt.input = first
	data.bird_pending.inputs = receipt.inputs.duplicate();data.bird_pending.input = first
	return receipt

static func equip(data: Dictionary,id: String,slot: int) -> bool:
	if slot not in [0,1] or not available(data,id): return false
	var slots: Array = equipped_slots(data)
	if slots[slot]==id: slots[slot] = ""
	else:
		if slots[1-slot]==id:return false
		slots[slot] = id
	data.bird_equipped_slots = slots;data.bird_equipped = slots[0]
	return true

static func description(index: int,lv: int) -> String:
	var n = clampi(lv,1,3)
	match index:
		0: return "Cospe 2 moedas a cada %d s. Pegue-as durante a corrida!" % [24-(n-1)*4]
		1: return "Sai da tela e traz um civil novo a cada %d s. Solta sobre a horda para capturá-lo." % [28-(n-1)*4]
		2: return "Carrega um laser que destrói 1 veículo ou obstáculo. Recarga: %d s, inclusive no primeiro tiro." % [60-(n-1)*10]
		3: return "Resgata um membro por partida e o protege por %.1f s. Funciona nos três cenários." % [1.0+(n-1)*.5]
		4: return "A cada %d Perfects, avança contra uma ameaça. Até três ataques por partida." % [6-n]
	return ""

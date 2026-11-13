extends RefCounted
## Collection rules are independent of animation, rendering and the run RNG.
const IDS = ["pipoco","fiapo","ferrugem","agourinho","barao"]
const RARITIES = ["CLÁSSICA","SUPER","HIPER","ULTRA","LENDÁRIA"]
const COLORS = [Color("9ce4aa"),Color("71ded5"),Color("79b8ff"),Color("c994ff"),Color("ffce73")]
const WEIGHTS = [60.0,25.0,10.0,4.0,1.0]
const NAMES = ["PIPOCO","FIAPO","FERRUGEM","AGOURINHO","BARÃO GOELA"]
const PERSONALITIES = ["Uma barriga enorme. Uma fome maior ainda.","Magrelo, medroso e sempre vendo perigo.","Metade corvo. Metade sucata. Inteiro mau humor.","Três olhos. Um segredo. Nenhum pio normal.","Sua excelência exige espaço para a barriga."]
const HINTS = ["Adora ver uma fileira inteira de moedas sumir.","O pescoço estica quando o perigo se aproxima.","Está sempre procurando algo para desmontar.","Não gosta de despedidas definitivas.","Só faz uma entrada triunfal depois de bons saltos."]
const PRICE = 30
const FUSION_PRICE = 0
const ESSENCE_NEEDED = 6

static func defaults() -> Dictionary:
	return {"bird_copies":{},"bird_essence":{},"bird_equipped":"","bird_equipped_slots":["",""],"bird_draws":0,"bird_rare_pity":0,"bird_legend_pity":0,"bird_pending":{},"bird_serial":0}

static func tier(id: String) -> int: return IDS.find(id)

static func copies(data: Dictionary,id: String) -> int:
	return clampi(int(data.get("bird_copies",{}).get(id,0)),0,100000)

static func level(data: Dictionary,id: String) -> int: return mini(3,copies(data,id))

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
	var slots = raw.get("bird_equipped_slots",[raw.get("bird_equipped",""),""])
	if slots is Array and slots.all(func(id):return str(id).is_empty()) and str(raw.get("bird_equipped","")).length()>0: slots = [raw.bird_equipped,""]
	if slots is Array:
		for i in range(mini(2,slots.size())):
			var id = str(slots[i])
			if id in IDS and copies(safe,id)>0 and (i==0 or id!=safe.bird_equipped_slots[0] or copies(safe,id)>3): safe.bird_equipped_slots[i] = id
	safe.bird_equipped = safe.bird_equipped_slots[0]
	var receipt = raw.get("bird_pending",{})
	if receipt is Dictionary and receipt.get("id","") in IDS:
		var id = str(receipt.id)
		if copies(safe,id)>0:
			var essence = receipt.get("essence",0)
			if not (essence is int or essence is float): essence = 0
			safe.bird_pending = {"id":id,"serial":maxi(1,int(safe.bird_serial)),"level":level(safe,id),"new":bool(receipt.get("new",false)),"essence":clampi(int(essence),0,1),"taps":clampi(int(receipt.get("taps",0)),0,3),"source":"fusion" if receipt.get("source","")=="fusion" else "draw"}
	return safe

static func add_copy(data: Dictionary,id: String,source: String) -> Dictionary:
	var old = copies(data,id)
	data.bird_copies[id] = mini(100000,old+1)
	var essence = 1 if old>=3 else 0
	if essence: data.bird_essence[id] = mini(100000,int(data.bird_essence.get(id,0))+1)
	if str(data.bird_equipped).is_empty(): data.bird_equipped = id;data.bird_equipped_slots[0] = id
	data.bird_serial = int(data.bird_serial)+1
	var receipt = {"id":id,"serial":data.bird_serial,"level":level(data,id),"new":old==0,"essence":essence,"taps":3 if source=="fusion" else 0,"source":source}
	data.bird_pending = receipt.duplicate()
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

static func fuse(data: Dictionary,id: String) -> Dictionary:
	var rarity = tier(id)
	if rarity<0 or rarity>=4 or not data.get("bird_pending",{}).is_empty(): return {}
	if copies(data,id)<6: return {}
	data.bird_copies[id] = copies(data,id)-6
	data.bird_essence[id] = maxi(0,copies(data,id)-3)
	var slots = data.get("bird_equipped_slots",[data.bird_equipped,""])
	for i in range(2):
		if slots[i]==id and copies(data,id)<(1 if i==0 or slots[0]!=id else 4): slots[i] = ""
	data.bird_equipped_slots = slots;data.bird_equipped = slots[0]
	return add_copy(data,IDS[rarity+1],"fusion")

static func equip(data: Dictionary,id: String,slot: int) -> bool:
	if slot not in [0,1] or id not in IDS or copies(data,id)<=0: return false
	var slots: Array = data.get("bird_equipped_slots",[data.bird_equipped,""]).duplicate()
	if slots[slot]==id: slots[slot] = ""
	else:
		if slots[1-slot]==id and copies(data,id)<4: return false
		slots[slot] = id
	data.bird_equipped_slots = slots;data.bird_equipped = slots[0]
	return true

static func description(index: int,lv: int) -> String:
	var n = clampi(lv,1,3)
	match index:
		0: return "Entrega +%d moeda%s quando você faz um Perfect. Complete a fileira!" % [n,"" if n==1 else "s"]
		1: return "Anuncia uma ameaça a cada %d s. Você ainda precisa desviar." % [22-(n-1)*4]
		2: return "Sabota uma ameaça a cada %d s. Naves e veículos ficam mais fracos." % [30-(n-1)*4]
		3: return "Resgata um membro por partida e o protege por %.1f s. Funciona nos três cenários." % [1.0+(n-1)*.5]
		4: return "A cada %d Perfects, avança contra uma ameaça. Até três ataques por partida." % [6-n]
	return ""

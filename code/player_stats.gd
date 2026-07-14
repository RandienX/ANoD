@tool
extends Node
## PlayerStats Autoload - Manages player currency and persistent stats for shop system
## This autoload centralizes currency management to avoid hardcoded values

signal currency_changed(new_amount: int)
signal stat_changed(stat_name: StringName, new_value: Variant)

enum CurrencyType {GOLD, SHIT, FAZTOKENS}

@export var gold: int = 100
@export var shit: int = 0
@export var tokens: int = 25

var stats: Dictionary[StringName, Variant] = {}
var party: Array = []
var stored_party: Array = []
var inventory: Dictionary[Item, int] = {}
var player_position: Vector2 = Vector2(272, -82)

func _ready() -> void:
	party.append(load("res://resources/party/freddy.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL))
	party[0].stats["hp"] = 100
	party[0].stats["mp"] = 25
	process_mode = Node.ProcessMode.PROCESS_MODE_ALWAYS
	add_item(load("res://resources/items/consumables/small_pizza.tres") as Item, 3)
	add_item(load("res://resources/items/consumables/small_soda.tres") as Item, 2)
	for p in party:
		p.equip_stats_change()

# === Save/Load Data Management ===
func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"gold": gold,
		"shit": shit,
		"tokens": tokens,
		"stats": stats,
		"player_position": var_to_str(player_position),
		"inventory": {},
		"party": [],
		"stored_party": []
	}
	
	# Serialize inventory (Item resources -> resource_path)
	for item in inventory.keys():
		if item and item.resource_path:
			data["inventory"][item.resource_path] = inventory[item]
	
	# Serialize party members with their properties using SaveManager's serialization
	for p in party:
		if p is Resource:
			var p_dict: Dictionary = {
			}
			# Serialize all storage properties
			for prop in p.get_property_list():
				if prop.usage & PROPERTY_USAGE_STORAGE:
					var prop_name: String = prop.name
					# Skip internal/resource management properties
					if prop_name in ["script", "resource_local_to_scene", "resource_name", "_resource_type",
					"metadata/_custom_type_script", "resource_scene_unique_id"]:
						continue
					if p.has_method("get") or prop_name in p:
						var prop_value = p.get(prop_name)
						# Use SaveManager's serialization for consistency
						p_dict[prop_name] = SaveManager.serialize_value(prop_value, prop.type)
			data["party"].append(p_dict)
			
	for p in stored_party:
		if p is Resource:
			var p_dict: Dictionary = {
			}
			# Serialize all storage properties
			for prop in p.get_property_list():
				if prop.usage & PROPERTY_USAGE_STORAGE:
					var prop_name: String = prop.name
					# Skip internal/resource management properties
					if prop_name in ["script", "resource_local_to_scene", "resource_name", "_resource_type",
					"metadata/_custom_type_script", "resource_scene_unique_id"]:
						continue
					if p.has_method("get") or prop_name in p:
						var prop_value = p.get(prop_name)
						# Use SaveManager's serialization for consistency
						p_dict[prop_name] = SaveManager.serialize_value(prop_value, prop.type)
			data["stored_party"].append(p_dict)
	return data

func load_save_data(data: Dictionary) -> void:
	# Load currency
	if data.has("gold"):
		gold = data["gold"]
	if data.has("shit"):
		shit = data["shit"]
	if data.has("tokens"):
		tokens = data["tokens"]
	
	# Load player position
	if data.has("player_position"):
		player_position = str_to_var(data["player_position"])
	
	# Load inventory
	if data.has("inventory"):
		inventory.clear()
		for path in data["inventory"].keys():
			var item: Item = load(path)
			if item:
				inventory[item] = int(data["inventory"][path])
	
	# Load party
	if data.has("party"):
		party.clear()
		party = await SaveManager._restore_party_array(data["party"])
	if data.has("stored_party"):
		stored_party.clear()
		stored_party = await SaveManager._restore_party_array(data["stored_party"])

# === Currency Management ===
func get_currency(type: CurrencyType = CurrencyType.GOLD) -> int:
	match type:
		CurrencyType.GOLD:
			return gold
		CurrencyType.SHIT:
			return shit
		CurrencyType.FAZTOKENS:
			return tokens
	return 0

func set_currency(amount: int, type: CurrencyType = CurrencyType.GOLD) -> void:
	match type:
		CurrencyType.GOLD:
			gold = max(0, amount)
		CurrencyType.SHIT:
			shit = max(0, amount)
		CurrencyType.FAZTOKENS:
			tokens = max(0, amount)
	currency_changed.emit(get_currency(type))

func add_currency(amount: int, type: CurrencyType = CurrencyType.GOLD) -> void:
	set_currency(get_currency(type) + amount, type)

func deduct_currency(amount: int, type: CurrencyType = CurrencyType.GOLD) -> bool:
	if get_currency(type) >= amount:
		set_currency(get_currency(type) - amount, type)
		return true
	return false

func has_currency(amount: int, type: CurrencyType = CurrencyType.GOLD) -> bool:
	return get_currency(type) >= amount

# === Stats Management ===
func get_stat(stat_name: StringName, default: Variant = null) -> Variant:
	return stats.get(stat_name, default)

func set_stat(stat_name: StringName, value: Variant) -> void:
	stats[stat_name] = value
	stat_changed.emit(stat_name, value)

# === Inventory Management ===
func add_item(item: Item, amount: int = 1):
	if not inventory.has(item):
		inventory[item] = 0
	inventory[item] += amount

func remove_item(item: Item, amount: int = 1):
	if inventory.has(item):
		inventory[item] -= amount
		if inventory[item] <= 0:
			inventory.erase(item)
		return true
	return false
	
func use_item(item: Item, target: Array) -> bool:
	if not item or target.size() <= 0:
		return false
	if item.type != 2:  # Not a consumable
		return false
	
	for t in target:
		
		# Apply revive effect
		if item.revive_amount > 0 and t.stats["hp"] <= 0:
			t.stats["hp"] = min(item.revive_amount, t.max_stats["hp"])
			Sfx.stream = load("res://assets/sound/sfx/heal.wav")
			Sfx.play()
			
		# Apply heal effects
		if item.heal_amount > 0 and t.stats["hp"] < t.max_stats["hp"] and t.stats["hp"] > 0:
			t.stats["hp"] = min(t.stats["hp"] + item.heal_amount, t.max_stats["hp"])
			Sfx.stream = load("res://assets/sound/sfx/heal.wav")
			Sfx.play()
	
		# Apply mana restore
		if item.mana_amount > 0 and t.stats["mp"] < t.max_stats["mp"]:
			t.stats["mp"] = min(t.stats["mp"] + item.mana_amount, t.max_stats["mp"])
							
		if item.consume_effects:
			for effect in item.consume_effects:
				var effect_data: BattleEffect = effect
				match effect_data.effect_type:
					effect_data.EffectType.BUFF_DEBUFF:
						for stat in effect_data.stat_modifiers:
							t.apply_modifier(effect_data.effect_id, stat, t)
					effect_data.EffectType.STATUS_APPLY:
						t.apply_status(effect_data.status_ref, 
											t.get_status_stacks(effect_data.status_ref.id), 
											t.get_status_duration(effect_data.status_ref.id),
											t)
	
	remove_item(item, 1)
	return true
	
func has_item(item: Item, amount: int = 1) -> bool:
	if inventory.has(item):
		return inventory[item] >= amount
	return false

func get_item_amount(item: Item) -> int:
	if inventory.has(item):
		return inventory[item]
	return 0

func clear_inventory():
	inventory.clear()

func get_inventory():
	return inventory

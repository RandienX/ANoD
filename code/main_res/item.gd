@tool
extends Resource
class_name Item

## Item configuration with comprehensive customization
enum ItemType {
	Weapon, 
	Armor, 
	Consumable, 
	Key, 
	Accessory
}

@export_group("Basic Info")
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var texture: Texture2D
@export var icon: Texture2D
@export var type: ItemType = ItemType.Weapon

@export_category("General")
@export var sell_price: Dictionary[PlayerStats.CurrencyType, int] = {
	PlayerStats.CurrencyType.GOLD: 10,
	PlayerStats.CurrencyType.SHIT: 10,
	PlayerStats.CurrencyType.FAZTOKENS: 10,
}
@export var max_stack: int = 99
@export var can_use_in_battle: bool = true
@export var can_use_outside_battle: bool = true
@export var item_attack: Skill
@export var path_to: String
@export var item_bonuses: Dictionary[String, int] = {
"hp": 0,
"mp": 0,
"atk": 0,
"def": 0,
"speed": 0,
"magic": 0,
"magic_def": 0,
"tp": 0
}

@export_category("Weapon & Armor")
@export_enum("One-Handed", "Two-Handed") var weapon_type: int = 0
@export var weapon_effects_given: Array[BattleEffect] = []
@export_enum("Head", "Chest", "Legs", "Shield", "Accessory") var armor_type: int = 0
@export var startup_effects_given: Array[BattleEffect] = []
@export var armor_value: int = 0

@export_category("Consumable")
@export var consume_effects: Array[BattleEffect] = []
@export var is_item_attack: bool = false
@export var heal_amount: int = 0
@export var mana_amount: int = 0
@export var revive_amount: int = 0

func get_bonus(stat_name: String) -> int:
	return item_bonuses.get(stat_name, 0)

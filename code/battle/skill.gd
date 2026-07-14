@tool
extends Resource
class_name Skill

## Skill/Ability configuration with comprehensive customization
enum Skill_Types {
	Physical,
	Magical
}

enum Damage_Types {
	Physical,
	Magical,
	Fire,
	Ice,
	Earth,
	Thunder,
	Water,
	Air,
	Psychic,
	Light,
	Dark,
	Poison
}

@export_group("Basic Info")
@export var skill_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_enum("SingleEnemy", "Self", "Party", "AllEnemies", "SingleAlly", "RandomEnemy") var target_type: int = 0
@export var skill_type: Skill_Types = Skill_Types.Physical

@export_group("Cost & Accuracy")
@export var mana_cost: int = 0
@export var hp_cost: int = 0
@export var tp_cost: int = 0
@export_range(0.01, 1.0) var accuracy: float = 1.0
@export var priority: int = 0                    # Higher = acts first

@export_group("Attack Properties")
@export var attack_multiplier: float = 1.0
@export var attack_bonus: int = 0
@export var damage_type: Damage_Types = Damage_Types.Physical

@export_group("Multiattack")
@export var hit_count: int = 1
@export var hit_damage_multiplier: float = 0.5

@export_group("Effects")
@export var on_use_effects: Array[BattleEffect] = []
@export var on_hit_effects: Array[BattleEffect] = []
@export var on_miss_effects: Array[BattleEffect] = []

@export_group("Item Usage")
@export var is_item_skill: bool = false

@export_group("Visual & Audio")
@export var vfx: VisualEffect = VisualEffect.new()
@export var sfx: AudioStreamMP3
@export var hit_sound: AudioStreamMP3 = preload("res://assets/sound/sfx/attack/Damage5.mp3")
@export var miss_sound: AudioStreamMP3 = preload("res://assets/sound/sfx/Miss.mp3")
@export var camera_shake: float = 0.0


func get_effective_accuracy(_user: Object) -> float:
	var acc = accuracy
	# Could apply buffs/debuffs here
	return acc

func get_total_damage(user: Object, _target: Object) -> int:
	var base_dmg = user.stats["atk"]
	var total = floor(base_dmg * attack_multiplier) + attack_bonus
	return max(1, total)

func can_use(user: Object) -> bool:
	if user.stats["mp"] < mana_cost:
		return false
	if user.stats["hp"] <= hp_cost:
		return false
	return true

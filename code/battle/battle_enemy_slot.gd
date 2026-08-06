@tool
class_name BattleEnemySlot
extends Resource

## A single enemy slot in a battle configuration

enum PosPresets {
	FAR_LEFT,
	LEFT,
	LITTLE_LEFT,
	TOP_LITTLE_LEFT,
	CENTRE,
	TOP_LITTLE_RIGHT,
	LITTLE_RIGHT,
	RIGHT,
	FAR_RIGHT,
}

@export_group("Enemy")
@export var enemy: Entity

@export_group("Spawn Settings")
@export var spawn_delay: float = 0.0             # Seconds before enemy appears
@export var spawn_on_phase: int = 0
@export var spawn_condition: Condition 

@export_group("Positioning")
@export var ui_position_preset: PosPresets
@export var ui_position: Vector2 = Vector2.ZERO
@export var z_index: int = 15
@export var connected_to_idx: int = -1            # If -1 then not connected
@export var is_reinforcement: bool = false

@export_group("Rewards (Override)")
@export var override_xp: bool = false
@export var xp_override: int = 0
@export var override_currency: bool = false
@export var currency_override: int = 0
@export var drop_items: Array[BattleItemDrop] = []

func duplicate_enemy() -> Entity:
	if not enemy:
		return null
	return enemy.duplicate_deep_custom()

func get_xp_reward() -> int:
	if override_xp:
		return xp_override
	return enemy.xp_reward if enemy else 0

func get_currency_reward() -> int:
	if override_currency:
		return currency_override
	return enemy.currency_reward if enemy else 0

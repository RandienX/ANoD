@tool
class_name Battle
extends Resource

## Data-driven battle configuration
## Similar structure to DialogueData for consistency

@export_group("Battle Configuration")
@export var battle_name: String = ""
@export_multiline var description: String = "temp"

@export_group("Enemies")
@export var enemies: Array[BattleEnemySlot]

@export_group("Party Members (Optional)")
@export var forced_party_members: Array[Entity]  # Empty = use current party

@export_group("Battle Settings")
@export var background_override: Texture2D
@export var music: AudioStreamMP3
@export var can_flee: bool = true
@export var can_use_items: bool = true
@export var xp_multiplier: float = 1.0
@export var currency_reward: int = 0

@export_group("Battle Phases")
@export var phases: Array[BattlePhase] = []
@export var current_phase_index: int = 0

@export_group("On Battle Start Effects")
@export var on_battle_start_effects: Array[Effect] = []

@export_group("On Battle End Effects")
@export var on_victory_effects: Array[Effect] = []
@export var on_defeat_effects: Array[Effect] = []

@export_group("On Turn Effects")
@export var turn_effects: Array[Effect] = []


func validate() -> Array[String]:
	var errors: Array[String] = []
	
	if enemies.is_empty():
		errors.append("Battle has no enemies configured")
	
	# Validate enemy slots
	for i in range(enemies.size()):
		var slot = enemies[i]
		if not slot:
			errors.append("Enemy slot %d is null" % i)
		elif not slot.enemy:
			errors.append("Enemy slot %d has no enemy resource" % i)
	
	# Validate phases
	for i in range(phases.size()):
		var phase = phases[i]
		if not phase:
			errors.append("Phase %d is null" % i)
	
	return errors


func get_enemies() -> Array[Entity]:
	var result: Array[Entity] = []
	for slot in enemies:
		if slot and slot.enemy:
			result.append(slot.enemy.duplicate_deep())
	return result


func get_total_enemy_count() -> int:
	return enemies.size()


func has_phase_trigger(trigger_type: String) -> bool:
	for phase in phases:
		if phase and phase.trigger_condition == trigger_type:
			return true
	return false

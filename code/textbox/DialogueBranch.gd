@tool
class_name DialogueBranch
extends Resource

## Conditional branch - evaluates condition and jumps to target if true

enum ConditionType {
	HAS_ITEM,           # Check if player has item
	HAS_STATUS,         # Check if player has status effect
	DONE_THING,    
	DONE_DIALOGUE,
	TALKED_TO_NPC,      
	KILLED_ENEMY,   
	BATTLE_WON,
	RANDOM_CHANCE,      # Random percent check
	QUEST_COMPLETE,     # Quest is finished
	QUEST_ACTIVE,       # Quest is in progress
	CUSTOM              # Custom script
}

@export_group("Condition")
@export var condition_type: ConditionType = 0

@export var param_string: String = ""      # item_id, status_id, var_name, quest_id
@export var param_value: float = 1.0       # amount, comparison value, percent
@export var custom_script: String = ""     # Path to custom condition script

@export_group("Flow")
@export var target_label: String = ""      # Jump here if condition is true
@export var comment: String = ""           # Designer note


func get_condition_type_name() -> String:
	return ConditionType.keys()[condition_type]

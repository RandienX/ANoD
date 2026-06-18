extends Resource
class_name DialogueCondition

enum ConditionType {
	HAS_ITEM,           # Check if player has item
	HAS_STATUS,         # Check if player has status effect
	HAS_PARTY_MEMBER,    # Check if player has party member
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

@warning_ignore("int_as_enum_without_cast")
@export var condition_type: ConditionType = 0

@export var param_string: String = ""      # item_id, status_id, var_name, quest_id
@export var param_value: float = 1.0       # amount, comparison value, percent
@export var custom_script: String = ""     # Path to custom condition script

func get_condition_type_name() -> String:
	return ConditionType.keys()[condition_type]

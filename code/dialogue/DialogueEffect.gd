@tool
class_name DialogueEffect
extends Resource

## Effect that runs when entering/exiting a dialogue node

enum EffectType {
	SET_VARIABLE,         # Set a game variable
	ADD_ITEM,             # Give item to player
	REMOVE_ITEM,          # Take item from player
	ADD_STATUS,           # Apply status effect
	REMOVE_STATUS,        # Remove status effect
	ADD_PARTY,            # Adds Party member
	STORE_PARTY,          # Stores party member data away from party
	READD_PARTY,          # Readds Party member from stored party data
	START_QUEST,          # Begin quest
	COMPLETE_QUEST,       # Finish quest
	REMOVE_QUEST,         # Remove quest
	TRIGGER_EVENT,        # Fire a signal/event
	PLAY_CUTSCENE,        # Play a set cutscene
	WAIT,                 # Pause dialogue briefly
	PLAY_SFX,             # Play an SFX
	AUTOSAVE,
	REMOVE_NPC,
	CUSTOM,               # Custom script
}

@export_group("Effect")
@warning_ignore("int_as_enum_without_cast")
@export var effect_type: EffectType = 0

@export var param_string: String = ""      # var_name, item_id, status_id, quest_id, event_name
@export var param_value: String = ""       # value, amount
@export var param_value2: String = ""       # value, amount (FOR SET_VARIABLE and TRIGGER_EVENT)
@export var wait_seconds: float = 1.0      # For WAIT type
@export var custom_script: String = ""     # Path to custom effect script

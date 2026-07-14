@tool
class_name DialogueNode
extends Resource

enum BeepType {
	DEFAULT,
	FREDDY,
	BONNIE,
	CHICA,
	FOXY,
	GOLDEN,
	NONE,
}

## A single dialogue entry with text, branches, and choices

@export_category("Node Identity")
@export_multiline var text: String = ""
@export var portrait: Texture2D
@export var label: String = ""
@export var next_label: String = ""  # Empty = end dialogue

@export_group("Settings")
@export var beep_type: BeepType
@export var voiceline: AudioStream
@export var text_speed: int = 30

@export_group("Conditional Branches")
@export var branches: Array[DialogueBranch] = []
@export var choices: Array[DialogueChoice] = []

@export_group("Effects")
@export var on_enter_effects: Array[Effect] = []
@export var on_exit_effects: Array[Effect] = []
@export var unskippable: bool = false

func has_branches() -> bool:
	return not branches.is_empty()

func has_choices() -> bool:
	return not choices.is_empty()
	
func is_end_node() -> bool:
	return next_label.is_empty() and branches.is_empty() and choices.is_empty()

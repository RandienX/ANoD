@tool
extends Resource
class_name DialogueChoice

## Player choice displayed as a button/option

@export_category("Display")
@export_multiline var text: String
@export var icon: Texture2D

@export_category("Availability")
@export var always_available: bool = true
@export var availability_branch: DialogueBranch  # If set, evaluated for availability
@export var target_label: String = ""


func is_available() -> bool:
	if always_available:
		return true
	
	if availability_branch:
		return availability_branch.evaluate()
	
	return false
	
func get_target_label() -> String:
	if not target_label.is_empty():
		return target_label
	
	if availability_branch and not availability_branch.target_label.is_empty():
		return availability_branch.target_label
		
	return ""

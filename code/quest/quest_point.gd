extends Resource
class_name QuestPoint

## QuestPoint - A step within a quest that contains conditions and logic gates
##
## A QuestPoint represents a single objective or milestone within a quest.
## It contains multiple conditions that are evaluated based on the logic gate.
## Progress moves linearly through points within a quest.

enum QuestState {
NO,        # Nothing happened, no progress
PROGRESS,  # Progress made on one or more conditions
DONE,      # All conditions completed (flash green/yellow)
FAIL,      # Quest failed (flash red, often from NOT condition)
YES        # Point complete, progressing to next stage
}

@export_group("Quest Point Definition")
@export var step_name: String = "Step"  # Name/description of this point
@export var conditions: Array[Condition] = []  # Conditions to evaluate

@export_group("Progress Tracking")
@export var is_complete: bool = false  # Cached completion state
@export var current_condition_index: int = 0  # For sequential condition tracking

@export_group("Optional")
@export var auto_advance: bool = true  # Auto-advance when complete
@export var metadata: Dictionary = {}  # Additional data

## Evaluate all conditions and return the current state using QuestConditionEvaluator
func evaluate() -> QuestState:
	if conditions.is_empty():
		return QuestState.YES

	for condition in conditions:
		if not condition:
			continue
			
		var available: bool = false
		
		condition.progress_current = condition.evaluate()
		available = condition.evaluate() >= condition.param_value
		
		if not available:
			return QuestState.NO
			
	return QuestState.YES

## Check if any condition has partial progress
func _has_any_progress() -> bool:
	for condition in conditions:
		var progress = condition.evaluate()
		if progress > 0 and progress <= condition.param_value:
			return true
	return false

## Get the current condition being tracked (for UI display)
func get_current_condition() -> Condition:
	if conditions.is_empty():
		return null
	if current_condition_index >= conditions.size():
		current_condition_index = 0
	return conditions[current_condition_index]

## Reset all conditions in this point
func reset() -> void:
	is_complete = false
	current_condition_index = 0
	for condition in conditions:
		condition.reset()

## Get completion percentage (0.0 to 1.0)
func get_completion_percentage() -> float:
	if conditions.is_empty():
		return 1.0
	var total_progress := 0.0

	for condition in conditions:
		var progress = condition.evaluate()
		total_progress += progress / condition.param_value

	return total_progress / conditions.size()

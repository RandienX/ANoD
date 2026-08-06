@tool
class_name DialogueBranch
extends Resource

## Conditional branch - evaluates condition and jumps to target if true
@export var conditions: Array[Condition]

@export var target_label: String = ""      # Jump here if condition is true
@export var comment: String = ""           # Designer note

func evaluate() -> bool:
	if conditions.is_empty():
		return true

	for condition in conditions:
		if not condition:
			continue
			
		var available: bool = false
		
		var int_av = condition.evaluate()
		if int_av >= condition.param_value:
			available = false if condition.invert else true
		
		if not available:
			return false
			
	return true

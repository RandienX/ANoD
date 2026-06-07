@tool
class_name DialogueBranch
extends Resource

## Conditional branch - evaluates condition and jumps to target if true
@export var conditions: Array[DialogueCondition]

@export var target_label: String = ""      # Jump here if condition is true
@export var comment: String = ""           # Designer note

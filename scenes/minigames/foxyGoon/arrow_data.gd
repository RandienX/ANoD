extends Resource
class_name ArrowData

@export var type: GoonArrow.Type
@export var spawn: GoonArrow.Spawn
@export_range(0.05, 10, 0.05) var after_time: float = 0.05
@export_range(0.5, 4.0, 0.05) var speed_mult: float = 1.0

@export var hold_time: float = 0

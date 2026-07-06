extends Resource
class_name ArrowSchematic

@export var arrow_data: Array[ArrowData]
@export_range(0.5, 4, 0.1) var speed_mult: float = 1

@export var flip_h: bool

@export var after_time: float = 0

func flip_horizontal():
	for arrow in arrow_data:
		match arrow.spawn:
			GoonArrow.Spawn.RIGHT:
				arrow.spawn = GoonArrow.Spawn.LEFT
			GoonArrow.Spawn.LEFT:
				arrow.spawn = GoonArrow.Spawn.RIGHT
			GoonArrow.Spawn.UP:
				arrow.spawn = GoonArrow.Spawn.DOWN
			GoonArrow.Spawn.DOWN:
				arrow.spawn = GoonArrow.Spawn.UP

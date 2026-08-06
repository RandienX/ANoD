extends Node2D
class_name GoonArrow

enum Type {
	NORMAL,
	BAD,
	INVERT,
	HOLD
}

enum Spawn {
	LEFT,
	UP,
	DOWN,
	RIGHT,
}

const spawn_settings: Dictionary[Spawn, Array] = { #[Position, rotation, color]
	Spawn.LEFT: [Vector2(280, 900), 270, Color(0.483, 1.0, 0.0, 1.0)],
	Spawn.UP: [Vector2(344, 900), 0, Color(1.0, 0.0, 0.0, 1.0)],
	Spawn.DOWN: [Vector2(408, 900), 180, Color(0.0, 1.0, 0.85, 1.0)],
	Spawn.RIGHT: [Vector2(474, 900), 90, Color(1.0, 0.833, 0.0, 1.0)],
}

const colors_mod: Dictionary[Type, Color] = {
	Type.NORMAL: Color(1, 1, 1, 1),
	Type.BAD: Color(0.2, 0.2, 0.2, 0.75),
	Type.INVERT: Color(1, 1, 0, 0.9),
	Type.HOLD: Color(0.8, 0.8, 0.8, 0.33),
}

var is_after_time: bool = false

@onready var main = get_tree().current_scene
@export var arrow_data: ArrowData

func _ready() -> void:
	if arrow_data.type == Type.HOLD and $Sprite2D.texture == load("res://assets/minigame/foxy_goon/foxy_arrow.png"):
		setup_hold_arrow()
	if arrow_data.type != Type.HOLD:
		rotation_degrees = spawn_settings[arrow_data.spawn][1]
	
	$Sprite2D.set_instance_shader_parameter("color", spawn_settings[arrow_data.spawn][2] * colors_mod[arrow_data.type])
	$Timer.wait_time = max(arrow_data.after_time, 0.001)
	$Timer.start()
	await $Timer.timeout
	global_position = spawn_settings[arrow_data.spawn][0]
	is_after_time = true

func setup_hold_arrow():
	arrow_data.type = Type.NORMAL
	for arrow in range(ceili(arrow_data.hold_time * arrow_data.speed_mult * main.settings_duplicate.speed * 18)-1):
		var arrow_hold = ArrowData.new()
		arrow_hold.type = Type.HOLD
		arrow_hold.spawn = arrow_data.spawn
		arrow_hold.speed_mult = arrow_data.speed_mult
		arrow_hold.after_time = arrow / (arrow_data.speed_mult * main.settings_duplicate.speed * 18) + arrow_data.after_time
		main.create_arrow(arrow_hold, true, false)
		
	var last = ceili(arrow_data.hold_time * arrow_data.speed_mult * main.settings_duplicate.speed * 18)-1
	var arrow_end = ArrowData.new()
	arrow_end.type = Type.HOLD
	arrow_end.spawn = arrow_data.spawn
	arrow_end.speed_mult = arrow_data.speed_mult
	arrow_end.after_time = last / (arrow_data.speed_mult * main.settings_duplicate.speed * 18) + arrow_data.after_time
	main.create_arrow(arrow_end, true, true)
	
func _physics_process(_delta: float) -> void:
	if is_after_time:
		var step = main.settings_duplicate.speed * 3 * arrow_data.speed_mult #5 seconds on 1.0 speed everything
		global_position.y -= step

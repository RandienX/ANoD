extends TextureRect

@export var input_action: StringName
@onready var main = get_tree().current_scene

@onready var last_hold: Area2D = $Perfect
var last_mult: float
var base_color

func _ready() -> void:
	base_color = get_instance_shader_parameter("color")

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(input_action):
		set_instance_shader_parameter("color", base_color / base_color)
		if $Perfect.get_overlapping_areas().size() == 0 and $Good.get_overlapping_areas().size() == 0 and $Meh.get_overlapping_areas().size() == 0:
			main._add_hp(-1)
			main._add_score(-50)
			main.recalculate_accuracy(main.accuracy - 0.08)
			last_hold = $Meh
			return
			
		for a in $Perfect.get_overlapping_areas():
			if a.name == "Arrow":
				_just_pressed(a.get_parent(), 1.5)
				last_hold = $Perfect
				last_mult = 1.5
				main.recalculate_accuracy(1)
				break
		for a in $Good.get_overlapping_areas():
			if a.name == "Arrow":
				_just_pressed(a.get_parent(), 1)
				last_hold = $Good
				last_mult = 1
				main.recalculate_accuracy(0.86)
				break
		for a in $Meh.get_overlapping_areas():
			if a.name == "Arrow":
				_just_pressed(a.get_parent(), 0.5)
				last_hold = $Meh
				last_mult = 0.5
				main.recalculate_accuracy(0.66)
				break
				
	if Input.is_action_pressed(input_action):
		_hold(last_hold, last_mult)
	else:
		var current_color: Color = get_instance_shader_parameter("color")
		if current_color != base_color:
			current_color = current_color.lerp(base_color, delta * 15.0)
			set_instance_shader_parameter("color", current_color)

func _just_pressed(arrow: GoonArrow, mult: float):
	if arrow.arrow_data.type != GoonArrow.Type.HOLD:
		main.destroy_arrow(arrow, mult)

func _hold(area: Area2D, mult: float):
	set_instance_shader_parameter("color", base_color / base_color)
	if area.get_overlapping_areas().size() == 0: return
	for a in area.get_overlapping_areas():
		if a.name == "Arrow":
			if a.get_parent().arrow_data.type == GoonArrow.Type.HOLD:
				main.destroy_arrow(a.get_parent(), mult)

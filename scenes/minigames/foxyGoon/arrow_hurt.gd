extends Area2D

@onready var main = get_tree().current_scene

func _on_area_entered(area: Area2D) -> void:
	if area.name == "Arrow":
		@warning_ignore("standalone_ternary")
		main.hurt_arrow(area.get_parent()) if area.get_parent().arrow_data.type != GoonArrow.Type.BAD else main.destroy_arrow(area.get_parent())

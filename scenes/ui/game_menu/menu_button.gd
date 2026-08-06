extends Button

@export var menu_path: String
@onready var display = $"../../display_category"
@export var id: int

func change_menu() -> void:
	$"../../../..".layer_down = 1
	Sfx.stream = load("res://assets/sound/sfx/select.wav")
	Sfx.play()
	
	for c in display.get_children():
		c.queue_free()
			
	if menu_path != "":
		display.add_child(load(menu_path).instantiate())
	elif id == 2:  # Quests button - use open_quests method
		var parent_menu = get_parent().get_parent().get_parent().get_parent()
		if parent_menu and parent_menu.has_method("open_quests"):
			parent_menu.open_quests()

func _on_mouse_entered():
	Sfx.stream = load("res://assets/sound/sfx/button_squeak.wav")
	Sfx.play()

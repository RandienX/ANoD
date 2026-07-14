extends Button

func _on_pressed() -> void:
	Sfx.stream = load("res://assets/sound/sfx/select.wav")
	Sfx.play()
	$"../../settings_anim".play("fade_in_settings")
	$"../../settings".visible = true
	await get_tree().create_timer(1).timeout
	$"../../save_box/Control".visible = false

var change_text = false

func _on_mouse_entered() -> void:
	change_text = true
	Sfx.stream = load("res://assets/sound/sfx/button_squeak.wav")
	Sfx.play()

func _on_mouse_exited() -> void:
	change_text = false
	
func _physics_process(_delta: float) -> void:
	if $".." == get_tree().root.get_node("menu/buttons"):
		if change_text: self.text = "> Gamechanging."
		else: self.text = "  Settings"
	elif $".." == get_tree().root.get_node("menu/settings"):
		if change_text: self.text = "> Back"
		else: self.text = "  Back"

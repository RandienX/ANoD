extends Button

func _on_pressed() -> void:
	$"../Sfx".stream = load("res://assets/sound/sfx/select.wav")
	$"../Sfx".play()
	
	$"../settings_anim".play("fade_in_button")
	await get_tree().create_timer(1).timeout
	if $"../settings".visible == true:
		get_tree().root.get_node("menu/settings").visible = false
	elif $"../save_box".visible == true:
		get_tree().root.get_node("menu/save_box").visible = false
		
	visible = false

var change_text = false

func _on_mouse_entered() -> void:
	change_text = true
	$"../Sfx".stream = load("res://assets/sound/sfx/button_squeak.wav")
	$"../Sfx".play()

func _on_mouse_exited() -> void:
	change_text = false
	
func _physics_process(_delta: float) -> void:
	if change_text: self.text = "> Back"
	else: self.text = "  Back"

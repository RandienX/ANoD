extends Button

func _on_pressed() -> void:
	Sfx.stream = load("res://assets/sound/sfx/select.wav")
	Sfx.play()
	await Sfx.finished
	get_tree().quit()

var change_text = false

func _on_mouse_entered() -> void:
	change_text = true
	Sfx.stream = load("res://assets/sound/sfx/button_squeak.wav")
	Sfx.play()

func _on_mouse_exited() -> void:
	change_text = false
	
func _physics_process(_delta: float) -> void:
	if change_text: self.text = "> Not ready for Freddy."
	else: self.text = "  Exit"

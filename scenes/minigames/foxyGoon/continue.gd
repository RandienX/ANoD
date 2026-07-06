extends Button

func _on_pressed() -> void:
	await $"../transition/black_flash".reappear()
	get_tree().change_scene_to_file("res://scenes/minigames/foxyGoon/foxy_goon_menu.tscn")
	Sfx2.stream = load("res://assets/sound/sfx/select.wav")
	Sfx2.play()

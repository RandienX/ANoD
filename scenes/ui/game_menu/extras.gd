extends Button

func change_menu() -> void:
	if name == "BackButton":
		var display = $"../../display_category"
		Sfx.stream = load("res://assets/sound/sfx/select.wav")
		Sfx.play()
		if display:
			for c in display.get_children():
				c.queue_free()
			$"../../../..".layer_down = 0
			$"../../../..".visible = false
			$"../../../../../../..".stop_move = false
			get_tree().paused = false
		
	elif name == "ExitButton":
		get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")

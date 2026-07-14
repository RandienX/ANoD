extends Control

func _on_back_pressed() -> void:
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
		

func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")

func _on_achievements_pressed() -> void:
	var display = $"../../display_category"
	if display:
		for c in display.get_children():
			c.queue_free()
	Sfx.stream = load("res://assets/sound/sfx/select.wav")
	Sfx.play()
	var achievements_scene = load("res://scenes/ui/game_menu/quests/achievements_ui.tscn")
	if achievements_scene:
		var achievements_ui = achievements_scene.instantiate()
		display.add_child(achievements_ui)

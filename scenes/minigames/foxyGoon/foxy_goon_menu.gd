extends Control

var toggled: bool = false
func _ready() -> void:
	if BackgroundMusic.stream != load("res://assets/minigame/foxy_goon/Saster - FGF Menu Theme.mp3"):
		BackgroundMusic.stream = load("res://assets/minigame/foxy_goon/Saster - FGF Menu Theme.mp3")
		BackgroundMusic.play()
	
	var data: Dictionary = Global.foxy_data
	for c in $GridContainer.get_children():
		if c.name != "later":
			if c.get_child(0).text not in data.keys():
				data.set(c.get_child(0).text, [-1, true])
			else:
				c.rank = data[c.get_child(0).text][0]
				c.unlocked = data[c.get_child(0).text][1]
		
func _on_level_select_pressed() -> void:
	if !toggled:
		var tween = create_tween().set_ease(Tween.EASE_IN)
		tween.tween_property($GridContainer, "modulate:a", 1.0, 0.5)
		toggled = true
	else:
		var tween = create_tween().set_ease(Tween.EASE_IN)
		tween.tween_property($GridContainer, "modulate:a", 0.0, 0.5)
		toggled = false
	
	Sfx2.stream = load("res://assets/sound/sfx/select.wav")
	Sfx2.play()

func _on_exit_pressed() -> void:
	Sfx2.stream = load("res://assets/sound/sfx/select.wav")
	Sfx2.play()
	get_tree().change_scene_to_file(Global.current_scene)

func _on_level_select_mouse_entered() -> void:
	Sfx2.stream = load("res://assets/sound/sfx/button_squeak.wav")
	Sfx2.play()
func _on_exit_mouse_entered() -> void:
	Sfx2.stream = load("res://assets/sound/sfx/button_squeak.wav")
	Sfx2.play()

func start_track(track: FoxyGoonSettings, track_name: String):
	Global.current_foxy_track = track
	Global.current_foxy_trackname = track_name

	get_tree().change_scene_to_file("res://scenes/minigames/foxyGoon/foxy_goon.tscn")
	

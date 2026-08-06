extends Control

@export var id: int
@onready var save_name = $texture/margin/vbox/text/savename.text

var save_data

func _ready() -> void:
	if get_tree().current_scene.name == "menu":
		await get_tree().current_scene.ready
	save_name = $texture/margin/vbox/text/savename.text
	if name == "autosave":
		$Button.visible = false
	display()
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("erase_savez"):
		display()

func _on_button_pressed() -> void:
	Sfx2.stream = load("res://assets/sound/sfx/select.wav")
	Sfx2.play()
	Save.save_game(id, save_name)
	display()

func _on_load_pressed() -> void:
	Sfx2.stream = load("res://assets/sound/sfx/select.wav")
	Sfx2.play()
	Save.load_game(id)

func display():
	save_data = Save.get_slot_info(id)
	if save_data:
		if save_data.exists:
			$texture/margin/vbox/text/savename.text = save_data.save_name
			$texture/margin/vbox/text/time.text = Save.format_time(save_data["time_played"])
			var scene_path = save_data["current_scene"]
			if ResourceLoader.exists(scene_path):
				var scene = load(scene_path)
				if scene:
					$texture/margin/vbox/roomname.text = scene.instantiate().room_name
				else:
					$texture/margin/vbox/roomname.text = "Unknown Room"
			else:
				$texture/margin/vbox/roomname.text = "Unknown Room"
			
			if save_data["global_data"]["player_stats"]:
				if save_data["global_data"]["player_stats"]["party"]:
					for p in save_data["global_data"]["player_stats"]["party"]:
						if p["name"] == "Freddy":
							$texture/margin/vbox/partymembers/Freddy.visible = true
						elif p["name"] == "Bonnie":
							$texture/margin/vbox/partymembers/Bonnie.visible = true
						elif p["name"] == "Chica":
							$texture/margin/vbox/partymembers/Chica.visible = true
						elif p["name"] == "Foxy":
							$texture/margin/vbox/partymembers/Foxy.visible = true
						elif p["name"] == "Golden Freddy":
							$texture/margin/vbox/partymembers/Golden.visible = true

func _on_button_mouse_entered() -> void:
	Sfx2.stream = load("res://assets/sound/sfx/button_squeak.wav")
	Sfx2.play()

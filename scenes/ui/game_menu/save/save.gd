extends Control

@export var id: int
@onready var save_name = $texture/margin/vbox/text/savename.text

var saving = true
var save_data

func _ready() -> void:
	if get_tree().current_scene.name == "menu":
		await get_tree().current_scene.ready

func _process(_delta: float) -> void:
	save_data = Save.get_slot_info(id)
	display()
	save_name = $texture/margin/vbox/text/savename.text
	if saving:
		$Button/NinePatchRect/SaveLoad.text = "Save"
	else:
		$Button/NinePatchRect/SaveLoad.text = "Load"
	if save_data:
		if save_data.exists:
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

func _on_button_pressed() -> void:
	Sfx2.stream = load("res://assets/sound/sfx/select.wav")
	Sfx2.play()
	if saving:
		Save.save_game(id, save_name)
		display()
	else:
		Save.load_game(id)

func display():
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
			

func _on_button_mouse_entered() -> void:
	Sfx2.stream = load("res://assets/sound/sfx/button_squeak.wav")
	Sfx2.play()

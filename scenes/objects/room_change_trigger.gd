extends Area2D
class_name ChangeRoomTrigger

@export var player_position: Vector2
@export var next_room_path: String 

func _on_body_entered(body: Node2D) -> void:
	if body.name == "player":
		await $"../..".save_data()
		await $"../../transition/black_flash".reappear()
		PlayerStats.player_position = player_position
		Global.loading = true
		get_tree().change_scene_to_file(next_room_path)
		Global.loading = false

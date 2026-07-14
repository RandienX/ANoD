extends TileMapLayer

func _ready() -> void:
	await get_tree().create_timer(0.05).timeout
	if "toilet_fight" in get_tree().current_scene.done_things.keys() and name == "objects":
		break_toilets()
	if "sink_off" in get_tree().current_scene.done_things.keys() and name == "objects":
		turn_off_sink()
	if "Pizzeria - Safe Room" in Global.scene_data.keys() and name == "walls":
		safe_room_door()
		
func break_toilets():
	set_cell(Vector2i(6,3), 1, Vector2i(1,10))
	set_cell(Vector2i(7,3), 1, Vector2i(1,10))
	set_cell(Vector2i(9,3), 1, Vector2i(1,10))
	set_cell(Vector2i(8,1), 1, Vector2i(1,10))
	erase_cell(Vector2i(4,1))
	erase_cell(Vector2i(6,1))
	erase_cell(Vector2i(10,1))

func turn_off_sink():
	set_cell(Vector2i(10, 4), 1, Vector2i(8, 2))

func safe_room_door():
	set_cell(Vector2i(0,0), 2, Vector2i(1,1))
	set_cell(Vector2i(2,0), 2, Vector2i(2,1))
	set_cell(Vector2i(0,-1), 2, Vector2i(1,0))
	set_cell(Vector2i(2,-1), 2, Vector2i(2,0))
	set_cell(Vector2i(1,0), 2, Vector2i(0,1))
	set_cell(Vector2i(1,-1), 2, Vector2i(1,2))
	

extends Node

static func apply(_effect):
	Global.get_tree().current_scene.get_node("TileMap/objects").set_cell(Vector2i(10, 4), 1, Vector2i(8, 2))

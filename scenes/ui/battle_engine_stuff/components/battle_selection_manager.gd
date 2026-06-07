extends Node
class_name SelectionManager

var root
var target_container

var current_index: int = 0
var selected_button

func setup(rott, target):
	root = rott
	target_container = target
	if target_container:
		update_selection()
	var attempts = 0
	while attempts < 5:
		root.selected_enemy = wrapi(root.selected_enemy + 1, 0, 5)
		var enemy_at_slot = root.get_enemy(root.selected_enemy)
		if enemy_at_slot != null and enemy_at_slot.hp > 0 and enemy_at_slot in root.initiative:
			update_flash()
			break
		attempts += 1
	hide_flash()

func change_selection(direction: int):
	var child_count = target_container.get_child_count()
	if child_count == 0:
		return

	if selected_button and is_instance_valid(selected_button):
		set_glow(selected_button, false)

	current_index = wrapi(current_index - direction, 0, child_count)
	update_selection()

func update_selection():
	var child_count = target_container.get_child_count()
	if child_count == 0:
		selected_button = null
		return

	current_index = clamp(current_index, 0, child_count - 1)
	
	var child = target_container.get_child(current_index)
	selected_button = child
	set_glow(selected_button, true)

func set_glow(btn: Button, is_glowing: bool):
	if is_glowing:
		btn.add_theme_color_override("font_color", Color.DARK_ORANGE)
	else:
		btn.remove_theme_color_override("font_color")

func activate_selected():
	if selected_button and is_instance_valid(selected_button):
		selected_button.emit_signal("pressed")
		
func move_enemy_input(input: int):
	if input == 0 or root.battle.enemies.is_empty(): return
	var attempts = 0
	while attempts < 5:
		root.selected_enemy = wrapi(root.selected_enemy + input, 0, 5)
		var enemy_at_slot = root.get_enemy(root.selected_enemy)
		if enemy_at_slot != null and enemy_at_slot.hp > 0 and enemy_at_slot in root.initiative:
			update_flash()
			break
		attempts += 1

func update_flash():

	var slots = root.get_node("Control/enemy_ui/enemies").get_children()
	var slot_index = root.selected_enemy
	slots[slot_index].material.set("shader_parameter/is_flashing", true)
	if root.get_enemy(slot_index) == null:
		var attempts = 0
		while attempts < 5:
			root.selected_enemy = wrapi(root.selected_enemy + 1, 0, 5)
			var enemy_at_slot = root.get_enemy(root.selected_enemy)
			if enemy_at_slot != null and enemy_at_slot.hp > 0 and enemy_at_slot in root.initiative:
				break
	for s in slots:
		if s != slots[slot_index]:
			s.material.set("shader_parameter/is_flashing", false)

func hide_flash():
	var slots = root.get_node("Control/enemy_ui/enemies").get_children()
	for s in slots:
		s.material.set("shader_parameter/is_flashing", false)

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
		if enemy_at_slot != null and enemy_at_slot.stats["hp"] > 0 and enemy_at_slot in root.initiative:
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
	Sfx2.stream = load("res://assets/sound/sfx/button_squeak.wav")
	Sfx2.play()
	set_glow(selected_button, true)

func set_glow(btn: Button, is_glowing: bool):
	if is_glowing:
		btn.add_theme_color_override("font_color", Color.DARK_ORANGE)
	else:
		btn.remove_theme_color_override("font_color")

func activate_selected():
	if selected_button and is_instance_valid(selected_button):
		Sfx2.stream = load("res://assets/sound/sfx/select.wav")
		Sfx2.play()
		selected_button.emit_signal("pressed")
		
func move_enemy_input(input: int):
	if input == 0 or root.battle.enemies.is_empty(): return
	Sfx2.stream = load("res://assets/sound/sfx/button_squeak.wav")
	Sfx2.play()
	var attempts = 0
	while attempts < len(root.enemies_by_slot):
		root.selected_enemy = wrapi(root.selected_enemy + input, 0, len(root.enemies_by_slot))
		var enemy_at_slot = root.get_enemy(root.selected_enemy)
		if enemy_at_slot != null and enemy_at_slot.stats["hp"] > 0 and enemy_at_slot in root.initiative:
			update_flash()
			break
		attempts += 1

func update_flash():
	var enemies_node = root.get_node_or_null("Control/enemy_ui/enemies")
	if not enemies_node: return
	var slots = enemies_node.get_children()
	if slots.is_empty(): return
	
	var slot_index = root.selected_enemy
	if slot_index < 0 or slot_index >= slots.size():
		slot_index = 0
		root.selected_enemy = 0
		
	if root.get_enemy(slot_index) == null:
		var attempts = 0
		while attempts < len(root.enemies_by_slot):
			root.selected_enemy = wrapi(root.selected_enemy + 1, 0, len(root.enemies_by_slot))
			var enemy_at_slot = root.get_enemy(root.selected_enemy)
			if enemy_at_slot != null and enemy_at_slot.stats["hp"] > 0 and enemy_at_slot in root.initiative:
				break
			attempts += 1
		slot_index = root.selected_enemy
		if slot_index >= slots.size():
			slot_index = 0
			
	var selected_slot = slots[slot_index]
	_apply_shader_param(selected_slot, "is_flashing", true)
	
	for s in slots:
		if s != selected_slot:
			_apply_shader_param(s, "is_flashing", false)

func hide_flash():
	if root:
		var enemies_node = root.get_node_or_null("Control/enemy_ui/enemies")
		if not enemies_node: return
		var slots = enemies_node.get_children()
		for s in slots:
			_apply_shader_param(s, "is_flashing", false)

func _apply_shader_param(node: Node, param: String, value: Variant):
	if node is CanvasItem:
		node.set_instance_shader_parameter(param, value)
	for child in node.get_children():
		if child is CanvasItem:
			child.set_instance_shader_parameter(param, value)

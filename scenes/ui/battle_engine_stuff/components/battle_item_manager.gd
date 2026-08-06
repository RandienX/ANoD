extends RefCounted
class_name ItemManager

var root: BattleEngine

var items_container: Control
var item_boxes: Array[ItemBox] = []
var current_item_index: int = 0
var item_scroll_offset: int = 0
var max_visible_items: int = 8
var available_items: Array[Resource] = []
var item_amounts: Array[int] = []
var item_box_scene: PackedScene

var item_target_type: int = 0  # 0 = enemy, 1 = party
var saved_party_plan_index: int = 0
var selected_party_member: int = 0
var item_ref: Item

const SkillClass = preload("res://code/battle/skill.gd")

func item_select_input(event):
	if event.is_action_pressed("left"):
		Sfx2.stream = load("res://assets/sound/sfx/button_squeak.wav")
		Sfx2.play()
		if item_target_type == 0:
			root.selection_manager.move_enemy_input(-1)
		else:
			var party_members = root.get_party_members_from_initiative()
			selected_party_member = wrapi(selected_party_member - 1, 0, party_members.size())
			root.move_who_moves_to_entity(party_members[selected_party_member]) # FIX: Use Entity reference
			root.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("right"):
		Sfx2.stream = load("res://assets/sound/sfx/button_squeak.wav")
		Sfx2.play()
		if item_target_type == 0:
			root.selection_manager.move_enemy_input(1)
		else:
			var party_members = root.get_party_members_from_initiative()
			selected_party_member = wrapi(selected_party_member + 1, 0, party_members.size())
			root.move_who_moves_to_entity(party_members[selected_party_member]) # FIX: Use Entity reference
			root.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use"):
		root.get_viewport().set_input_as_handled()
		Sfx2.stream = load("res://assets/sound/sfx/select.wav")
		Sfx2.play()
		await confirm_item_target()
	elif event.is_action_pressed("menu"):
		if item_target_type == 1:
			root.get_node("WhoMoves").visible = true
			root.move_who_moves_to_entity(root.current_attacker) # FIX: Use Entity reference
			close_items_menu()
		if root.get_viewport():
			root.get_viewport().set_input_as_handled()

func select_item():
	if current_item_index < 0 or current_item_index >= available_items.size():
		return
	if item_amounts[current_item_index] <= 0:
		root.get_node("Control/enemy_ui/CenterContainer/output").text = "No items left! "
		await root.get_tree().create_timer(0.5).timeout
		return

	var item = available_items[current_item_index]

	if item.is_item_attack and item.item_attack:
		item_target_type = 0
		
		var item_attack = item.item_attack.duplicate()
		if item_attack.target_type == 0: #SingleEnemy
			item_target_type = 0
			await root.get_tree().process_frame
			root.state = root.states.OnItemSelect
			root.selected_enemy = root.previous_enemy if root.previous_enemy >= 0 else 0
			return
		elif item_attack.target_type == 1: #Self 
			item_ref = item
			root.add_attack(root.current_attacker, [root.current_attacker], item_attack)
			root.action_history.append(root.current_attacker)
			PlayerStats.remove_item(item, 1)
			item_amounts[current_item_index] -= 1
			close_items_menu()
			root.advance_planning()
		elif item_attack.target_type == 2: #Party
			item_ref = item
			root.add_attack(root.current_attacker, root.party, item_attack)
			root.action_history.append(root.current_attacker)
			PlayerStats.remove_item(item, 1)
			item_amounts[current_item_index] -= 1
			close_items_menu()
			root.advance_planning()
		elif item_attack.target_type == 3: #AllEnemies
			item_ref = item
			root.add_attack(root.current_attacker, root.enemy_instances, item_attack)
			root.action_history.append(root.current_attacker)
			PlayerStats.remove_item(item, 1)
			item_amounts[current_item_index] -= 1
			close_items_menu()
			root.advance_planning()
		elif item_attack.target_type == 4: #SingleAlly
			item_target_type = 1
			saved_party_plan_index = root.current_party_plan_index
			var party_members = root.get_party_members_from_initiative()
			selected_party_member = 0
			for i in range(party_members.size()):
				if party_members[i] == root.current_attacker:
					selected_party_member = i
					break
			items_container.visible = false
			root.get_node("Control/gui/HBoxContainer2/party").visible = true
			root.get_node("WhoMoves").visible = true
			root.move_who_moves_to_entity(party_members[selected_party_member]) # FIX: Use Entity reference
			await root.get_tree().process_frame
			root.state = root.states.OnItemSelect 
			return
		elif item_attack.target_type == 5: #RandomEnemy
			item_ref = item
			root.add_attack(root.current_attacker, [root.enemy_instances[randi_range(0, root.enemy_instances.duplicate().size()-1)]], item_attack)
			root.action_history.append(root.current_attacker)
			PlayerStats.remove_item(item, 1)
			item_amounts[current_item_index] -= 1
			close_items_menu()
			root.advance_planning()
		Sfx2.stream = load("res://assets/sound/sfx/select.wav")
		Sfx2.play()
		return
	else:
		item_target_type = 1
		await root.get_tree().process_frame
		root.state = root.states.OnItemSelect
		
		var party_members = root.get_party_members_from_initiative()
		selected_party_member = 0
		for i in range(party_members.size()):
			if party_members[i] == root.current_attacker:
				selected_party_member = i
				break
		
		saved_party_plan_index = root.current_party_plan_index
		items_container.visible = false
		root.get_node("Control/gui/HBoxContainer2/party").visible = true
		root.get_node("WhoMoves").visible = true
		root.move_who_moves_to_entity(party_members[selected_party_member]) # FIX: Use Entity reference
		Sfx2.stream = load("res://assets/sound/sfx/select.wav")
		Sfx2.play()
		return
		
func setup_items_ui(battleroot):
	root = battleroot
	item_box_scene = preload("res://scenes/ui/battle_engine_stuff/item_box.tscn")
	
	if not root.has_node("Control/gui/HBoxContainer2/items_container"):
		items_container = Control.new()
		items_container.name = "items_container"
		items_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		items_container.visible = false
		items_container.z_index = 10
		
		var scroll = ScrollContainer.new()
		scroll.name = "ScrollContainer"
		scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		items_container.add_child(scroll)
		
		var grid = GridContainer.new()
		grid.name = "ItemGrid"
		grid.columns = 2  # MATCH SKILLS: 2 columns
		grid.add_theme_constant_override("h_separation", -40)
		grid.add_theme_constant_override("v_separation", -25)
		grid.custom_minimum_size = Vector2(648, 0) 
		scroll.add_child(grid)
		
		root.get_node("Control/gui/HBoxContainer2").add_child(items_container)
	
	items_container = root.get_node("Control/gui/HBoxContainer2/items_container")

func open_items_menu():
	root.get_viewport().set_input_as_handled()
	saved_party_plan_index = root.current_party_plan_index
	root.get_node("Control/gui/HBoxContainer2/party").visible = false
	root.get_node("WhoMoves").visible = false
	items_container.visible = true
	root.state = root.states.OnItems
	
	available_items.clear()
	item_amounts.clear()

	# Get items from Global inventory
	for item in PlayerStats.inventory.keys():
		if item and item.type == 2:
			var amount = PlayerStats.inventory[item]
			if amount > 0:
				available_items.append(item)
				item_amounts.append(amount)

	if available_items.is_empty():
		root.get_node("Control/enemy_ui/CenterContainer/output").text = "No items!"
		await root.get_tree().create_timer(0.5).timeout
		close_items_menu()
		return

	create_item_boxes()

	current_item_index = 0
	item_scroll_offset = 0
	update_item_selection()

func create_item_boxes():
	var grid = items_container.get_node("ScrollContainer/ItemGrid")
	for child in grid.get_children():
		child.queue_free()
	item_boxes.clear()
	
	for i in range(available_items.size()):
		var item = available_items[i]
		var amount = item_amounts[i]
		var box = item_box_scene.instantiate()
		box.offset_transform_enabled = true
		box.offset_transform_scale = Vector2(0.9, 0.9)
		grid.add_child(box)
		box.setup(item, i, amount)
		item_boxes.append(box)
	
	update_item_selection()

func update_item_selection():
	for i in range(item_boxes.size()):
		var box = item_boxes[i]
		var has_items = item_amounts[i] > 0
		
		if i == current_item_index and has_items:
			box.modulate = Color(1.0, 0.5, 0.0, 1.0) 
		else:
			box.modulate = Color(1, 1, 1) if has_items else Color(0.5, 0.5, 0.5)
	
	if current_item_index >= item_scroll_offset + max_visible_items:
		item_scroll_offset = current_item_index - max_visible_items + 1
	elif current_item_index < item_scroll_offset:
		item_scroll_offset = current_item_index
	
	var scroll = items_container.get_node("ScrollContainer")
	scroll.scroll_vertical = item_scroll_offset * 70

func navigate_items(direction: int):
	var new_index = current_item_index + direction
	
	if new_index < 0:
		if item_boxes.size() % 2 == 0:
			new_index = item_boxes.size() - 1 if new_index % item_boxes.size() == -1 else item_boxes.size() - 2
		else:
			new_index = item_boxes.size() - 2 if new_index % item_boxes.size() == -1 else item_boxes.size() - 1
		if abs(direction) == 1:
			new_index = item_boxes.size() - 1
	elif new_index >= item_boxes.size():
		if item_boxes.size() % 2 == 0:
			new_index = direction - 1 if new_index % item_boxes.size() != 0 else 0
		else:
			new_index = direction - 1 if new_index % item_boxes.size() == 0 else 0
	
	var attempts = 0
	while attempts < item_boxes.size():
		if item_amounts[new_index] > 0:
			break
		new_index += direction
		if new_index < 0:
			if item_boxes.size() % 2 == 0:
				new_index = item_boxes.size() - 1 if new_index % item_boxes.size() == -1 else item_boxes.size() - 2
			else:
				new_index = item_boxes.size() - 2 if new_index % item_boxes.size() == -1 else item_boxes.size() - 1
			if abs(direction) == 1:
				new_index = item_boxes.size() - 1
		elif new_index >= item_boxes.size():
			if item_boxes.size() % 2 == 0:
				new_index = direction - 1 if new_index % item_boxes.size() != 0 else 0
			else:
				new_index = direction - 1 if new_index % item_boxes.size() == 0 else 0
		attempts += 1
	
	if item_amounts[new_index] > 0:
		Sfx2.stream = load("res://assets/sound/sfx/button_squeak.wav")
		Sfx2.play()
		current_item_index = new_index
		update_item_selection()
	
func confirm_item_target():
	var item = available_items[current_item_index]
	root.state = root.states.Waiting
	
	if item_target_type == 0:
		if item.is_item_attack and item.item_attack:
			var target = root.get_enemy(root.selected_enemy)
			if target and target.stats["hp"] > 0:
				var item_attack = item.item_attack.duplicate()
				item_attack.skill_name = item.item_name
				item_ref = item
				if item_attack.target_type == 0: #SingleEnemy
					root.add_attack(root.current_attacker, [target], item_attack)
					root.action_history.append(root.current_attacker)
					close_items_menu()
					await root.advance_planning()
					PlayerStats.remove_item(item, 1)
					item_amounts[current_item_index] -= 1
					Sfx2.stream = load("res://assets/sound/sfx/select.wav")
					Sfx2.play()
			else:
				Sfx2.stream = load("res://assets/sound/sfx/error.wav")
				Sfx2.play()
				root.get_node("Control/enemy_ui/CenterContainer/output").text = "Invalid target! "
				await root.get_tree().create_timer(0.5).timeout
				close_items_menu()
	else:
		var party_in_initiative = root.get_party_members_from_initiative()
		selected_party_member = clamp(selected_party_member, 0, party_in_initiative.size() - 1)
		var target = party_in_initiative[selected_party_member]
		
		# FIX: Allow targeting dead members IF the item is a revive item
		var is_revive_item = item.get("revive_amount") != null and item.revive_amount > 0
		var is_valid_target = (target.stats["hp"] > 0) or (is_revive_item and target.stats["hp"] <= 0)
		
		if target and is_valid_target:
			var item_attack = item.item_attack.duplicate() if item.is_item_attack and item.item_attack else null
			if item_attack:
				item_attack.item_reference = item
				item_attack.skill_name = item.item_name
				root.add_attack(root.current_attacker, [target], item_attack)
				PlayerStats.remove_item(item, 1)
				item_amounts[current_item_index] -= 1
			else:
				var item_use_skill = SkillClass.new()
				item_use_skill.skill_name = item.item_name
				item_use_skill.is_item_skill = true
				item_use_skill.target_type = 1
				item_ref = item
				root.add_attack(root.current_attacker, [target], item_use_skill)
				root.action_history.append(root.current_attacker)
				PlayerStats.remove_item(item, 1)
				item_amounts[current_item_index] -= 1
			close_items_menu()
			Sfx2.stream = load("res://assets/sound/sfx/select.wav")
			Sfx2.play()
			await root.advance_planning()
		else:
			Sfx2.stream = load("res://assets/sound/sfx/error.wav")
			Sfx2.play()
			root.get_node("Control/enemy_ui/CenterContainer/output").text = "Invalid target! "
			await root.get_tree().create_timer(0.5).timeout
			close_items_menu()

func close_items_menu():
	items_container.visible = false
	root.get_node("Control/gui/HBoxContainer2/party").visible = true
	root.get_node("WhoMoves").visible = true
	root.move_who_moves_to_entity(root.current_attacker) # FIX: Use Entity reference
	root.state = root.states.OnAction
	
func get_current_item() -> Item:
	if current_item_index >= 0 and current_item_index < available_items.size():
		return available_items[current_item_index]
	return null

extends Node2D
class_name BattleEngine

@export var battle: Battle
var party: Array = PlayerStats.party
var initiative: Array[Entity]
var enemy_instances: Array[Entity] = []  
var enemies_by_slot: Array[Entity] = []  

enum states { OnAction, OnEnemy, OnSkills, OnSkillSelect, OnItems, OnItemSelect, Waiting, OnRun}
var state: states = states.OnAction

# Managers
var item_manager: ItemManager
var skill_manager: SkillManager
var effect_manager: EffectManager
var death_manager: DeathManager
var log_manager: LogManager
var attack_executor: AttackExecutor
var selection_manager: SelectionManager
var enemy_manager: EnemyManager
var condition_effect_manager: BattleConditionEffectManager

var planning_phase: bool = true
var action_history: Array[Entity] = []
var current_attacker: Entity
var current_party_plan_index: int = 0
var selected_enemy: int = 0  
var previous_enemy: int = 0
var initiative_who: int = -1
var ignore_first_target_input: bool = false

var time_passed = 0.0
var turn_number = 0

# === SETUP ===
var party_initiative_order: Array[Entity] = []

func _ready() -> void:
	battle = Global.battle_current.duplicate(true)
	Global.battle_ref = self
	$Control/EffekseerEmitter2D.speed = Settings.battle_speed
	$Control/EffekseerEmitter2D.autoplay = Settings.battle_animations
	setup_enemies()
	initiative = setup_initiative()
	
	# FIX: Create a snapshot of the party's initiative order for UI and revive targeting
	party_initiative_order.clear()
	for actor in initiative:
		if actor.role == Entity.Role.PARTY:
			party_initiative_order.append(actor)
			
	setup_party()
	setup_current_attacker()
	_setup_managers()
	_setup_battle_log_label()
	if battle.music:
		BackgroundMusic.stream = battle.music
		BackgroundMusic.play()
		BackgroundMusic.autoplay = true
	$Control/enemy_ui/bg.texture = battle.background_override if battle.background_override != null else Global.battle_bg
	start_round()
	await get_tree().create_timer(0.2).timeout
	move_who_moves_to_entity(current_attacker)

func _setup_managers():
	effect_manager = EffectManager.new()
	effect_manager.initialize(party, enemy_instances)
	effect_manager.status_applied.connect(_on_status_applied)
	
	item_manager = ItemManager.new()
	item_manager.setup_items_ui(self)
	
	skill_manager = SkillManager.new()
	skill_manager.setup_skills_ui(self)
	
	death_manager = DeathManager.new()
	death_manager.setup(self, battle)
	
	log_manager = LogManager.new()
	log_manager.setup(self, effect_manager)
	
	attack_executor = AttackExecutor.new()
	attack_executor.setup(self, death_manager, effect_manager, log_manager, battle)

	enemy_manager = EnemyManager.new()
	enemy_manager.setup(self, attack_executor, effect_manager, log_manager)

	selection_manager = SelectionManager.new()
	await get_tree().create_timer(0.1).timeout
	selection_manager.setup(self, $Control/gui/HBoxContainer2/actions)
	
	condition_effect_manager = BattleConditionEffectManager.new()
	condition_effect_manager.setup(self)
	
@warning_ignore("unused_parameter")
func _on_status_applied(entity: Entity, status_id: String, stacks: int) -> void:
	_update_all_battle_faces()

func _update_all_battle_faces() -> void:
	# Update party faces
	var party_container = $Control/gui/HBoxContainer2/party
	if party_container:
		for i in range(party_container.get_child_count()):
			var ui = party_container.get_child(i)
			if ui.has_method("update_effects_ui"):
				ui.update_effects_ui()
	# Update enemy faces
	var enemy_container = $Control/enemy_ui/enemies
	if enemy_container:
		for i in range(enemy_container.get_child_count()):
			var ui = enemy_container.get_child(i)
			if ui.has_method("update_effects_ui"):
				ui.update_effects_ui()
								
func setup_enemies():
	enemy_instances.clear()
	enemies_by_slot.clear()
	enemies_by_slot.resize(5)
	for i in range(5):
		enemies_by_slot[i] = null

	for e in battle.enemies:
		var path = "Control/enemy_ui/enemies/enemy" + str(e.position_index+1)
		var node = get_node_or_null(path)
		
		var enemy = e.enemy.duplicate_deep()
		enemies_by_slot[e.position_index] = enemy
		enemies_by_slot[e.position_index].stats = enemy.base_stats.duplicate()
		enemies_by_slot[e.position_index].max_stats = enemy.base_stats.duplicate()
		var prog = node.get_node_or_null("ProgressBar")
		if prog: prog.visible = true
		node.texture = enemy.portrait
		if e.enemy.battle_sprite:
			node.texture = e.enemy.battle_sprite
		node.enemy = enemy
		if e.ui_position != Vector2(0, 0):
			node.global_position = e.ui_position
		
		var effect_cont = node.get_node_or_null("EffectContainer")
		if not effect_cont:
			effect_cont = GridContainer.new()
			effect_cont.name = "EffectContainer"
			effect_cont.columns = 4
			effect_cont.add_theme_constant_override("h_separation", 4)
			effect_cont.add_theme_constant_override("v_separation", 4)
			effect_cont.custom_minimum_size = Vector2(128, 64)
			effect_cont.position = Vector2(0, 64)
			node.add_child(effect_cont)
		enemy_instances.append(enemy)
		

func setup_initiative() -> Array[Entity]:
	var speed: Dictionary[int, Entity] = {}
	for e in enemy_instances:
		if e and e.stats["hp"] > 0:
			var rng = randi_range(ceili(e.stats["speed"] * 0.75), floori(e.base_stats["speed"] * 1.25))
			while rng in speed: rng += 1
			speed[rng] = e
	for p in party:
		var spd = p.stats["speed"] if p.stats["speed"] else p.stats.get("speed", 10)
		var speed_mult = _get_status_multiplier(p, "speed", 0.15)
		var slow_mult = _get_status_multiplier(p, "slow", -0.15)
		var total_mult = speed_mult * slow_mult
		var rng = randi_range(ceili(spd * total_mult * 0.75), floori(spd * total_mult * 1.25))
		while rng in speed: rng += 1
		speed[rng] = p
	var keys = speed.keys()
	keys.sort()
	var rev: Array[Entity] = []
	for k in range(keys.size()-1, -1, -1):
		rev.append(speed[keys[k]])
	return rev
	
func _get_status_multiplier(entity: Entity, status_id: String, per_stack_value: float) -> float:
	"""Helper to get status multiplier without relying on effect_manager."""
	if not entity.has_status(status_id):
		return 1.0
	var stacks = entity.get_status_stacks(status_id)
	return 1.0 + (float(stacks) * per_stack_value)

func setup_party():
	for c in $Control/gui/HBoxContainer2/party.get_children():
		c.queue_free()
	
	for p in party_initiative_order:
		var ui = preload("res://scenes/ui/battle_engine_stuff/partyBattleFace.tscn").instantiate()
		ui.setup(p)
		ui.z_index = 22
		$Control/gui/HBoxContainer2/party.add_child(ui)
			
func setup_current_attacker():
	for o in initiative:
		if o.role == Entity.Role.PARTY:
			current_attacker = o
			break
			
func _setup_battle_log_label() -> void:
	var label: RichTextLabel = $Control/enemy_ui/CenterContainer/output
	if label is RichTextLabel:
		label.bbcode_enabled = true
		label.fit_content = true
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# === MAIN BATTLE LOOP ===
func _process(delta: float) -> void:
	if state == states.OnAction:
		selection_manager.hide_flash()
	elif state == states.OnEnemy:
		selection_manager.update_flash()
	elif state == states.OnSkillSelect:
		var skill = skill_manager.get_current_skill()
		if skill and skill.target_type == 0:
			selection_manager.update_flash()
		else:
			selection_manager.hide_flash()
	elif state == states.OnItemSelect:
		var item = item_manager.get_current_item()
		if item and item.is_item_attack and item.item_attack and item.item_attack.target_type == 0:
			selection_manager.update_flash()
	else:
		selection_manager.hide_flash()
		
	time_passed += delta

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo(): return
	if get_viewport() == null: return
	if death_manager.game_over_active:
		if death_manager.can_reload and (event.is_action_pressed("use") or event.is_action_pressed("menu") or event.is_action_pressed("lmb")):
			Global.reload_last_save()
		return

	if state == states.Waiting:
		if event.is_pressed():
			get_viewport().set_input_as_handled()
		return

	if planning_phase and (event.is_action_pressed("back") or event.is_action_pressed("menu")) and event.is_pressed():
		match state:
			states.OnSkills: skill_manager.close_skills_menu()
			states.OnSkillSelect: state = states.OnSkills
			states.OnItems: item_manager.close_items_menu()
			states.OnItemSelect: state = states.OnItems
			states.OnEnemy: state = states.OnAction
			_: undo_last_action()
		get_viewport().set_input_as_handled()
		
		Sfx2.stream = load("res://assets/sound/sfx/button_squeak.wav")
		Sfx2.play()
		return

	if not event.is_pressed() or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		return

	if state == states.OnSkills:
		if death_manager.game_over_active: return
		if event.is_action_pressed("down"):
			get_viewport().set_input_as_handled()
			skill_manager.navigate_skills(-2)
		elif event.is_action_pressed("up"):
			get_viewport().set_input_as_handled()
			skill_manager.navigate_skills(2)
		elif event.is_action_pressed("right"):
			get_viewport().set_input_as_handled()
			skill_manager.navigate_skills(1)
		elif event.is_action_pressed("left"):
			get_viewport().set_input_as_handled()
			skill_manager.navigate_skills(-1)
		elif event.is_action_pressed("use"):
			get_viewport().set_input_as_handled()
			skill_manager.select_skill()
	
	elif state == states.OnSkillSelect:
		if death_manager.game_over_active: return
		if event.is_action_pressed("left"):
			get_viewport().set_input_as_handled()
			selection_manager.move_enemy_input(-1)
		elif event.is_action_pressed("right"):
			get_viewport().set_input_as_handled()
			selection_manager.move_enemy_input(1)
		elif event.is_action_pressed("use"):
			get_viewport().set_input_as_handled()
			skill_manager.confirm_skill_target()
	
	elif state == states.OnItems:
		if death_manager.game_over_active: return
		if event.is_action_pressed("down"):
			get_viewport().set_input_as_handled()
			item_manager.navigate_items(2)
		elif event.is_action_pressed("up"):
			get_viewport().set_input_as_handled()
			item_manager.navigate_items(-2)
		elif event.is_action_pressed("right"):
			get_viewport().set_input_as_handled()
			item_manager.navigate_items(1)
		elif event.is_action_pressed("left"):
			get_viewport().set_input_as_handled()
			item_manager.navigate_items(-1)
		elif event.is_action_pressed("use"):
			get_viewport().set_input_as_handled()
			item_manager.select_item()
	
	elif state == states.OnItemSelect:
		if death_manager.game_over_active: return
		# FIX: Removed the ignore_first_target_input hack which was eating the confirmation press
		await item_manager.item_select_input(event)
	
	elif state == states.OnEnemy:
		if death_manager.game_over_active: return
		if event.is_action_pressed("left"):
			get_viewport().set_input_as_handled()
			selection_manager.move_enemy_input(-1)
		elif event.is_action_pressed("right"):
			get_viewport().set_input_as_handled()
			selection_manager.move_enemy_input(1)
		elif event.is_action_pressed("use"):
			get_viewport().set_input_as_handled()
			var target_enemy = get_enemy(selected_enemy)
			
			if target_enemy and target_enemy.stats["hp"] > 0:
				# Use the exact same helper to ensure consistency
				var atk_skill = _get_default_attack_skill()
				add_attack(current_attacker, [target_enemy], atk_skill)
				Sfx2.stream = load("res://assets/sound/sfx/select.wav")
				Sfx2.play()
					
				action_history.append(current_attacker)
				previous_enemy = selected_enemy
				selected_enemy = 0
				advance_planning()
	
	elif state == states.OnAction:
		if death_manager.game_over_active: return
		if event.is_action_pressed("down"):
			get_viewport().set_input_as_handled()
			selection_manager.change_selection(-1)
		elif event.is_action_pressed("up"):
			get_viewport().set_input_as_handled()
			selection_manager.change_selection(1)
		elif event.is_action_pressed("use"):
			get_viewport().set_input_as_handled()
			selection_manager.activate_selected()
			
	if get_viewport():
		get_viewport().set_input_as_handled()

func move_who_moves(index: int):
	var party_container = $Control/gui/HBoxContainer2/party
	var alive_ui_nodes: Array[Control] = []
	
	# Filter the UI container to only include alive/visible party members
	for child in party_container.get_children():
		if child is Control:
			var is_alive = child.visible
			
			# Double-check HP if the UI node exposes its entity reference
			if child.get("entity") != null:
				is_alive = child.get("entity").stats["hp"] > 0
			elif child.get("party_member") != null:
				is_alive = child.get("party_member").stats["hp"] > 0
				
			if is_alive:
				alive_ui_nodes.append(child)

	# Map the initiative index to the filtered alive UI nodes
	if index >= 0 and index < alive_ui_nodes.size():
		$WhoMoves.visible = true
		var target_node = alive_ui_nodes[index]
		var local_x = target_node.global_position.x - global_position.x
		$WhoMoves.position.x = local_x + (target_node.size.x / 2.0)
	else:
		$WhoMoves.visible = false
		
func move_who_moves_to_entity(entity: Entity):
	var party_container = $Control/gui/HBoxContainer2/party
	var ui_index = party_initiative_order.find(entity)
	
	if ui_index >= 0 and ui_index < party_container.get_child_count():
		$WhoMoves.visible = true
		var target_node = party_container.get_child(ui_index)
		var local_x = target_node.global_position.x - global_position.x
		$WhoMoves.position.x = local_x + (target_node.size.x / 2.0)
	else:
		$WhoMoves.visible = false
	
func get_party_members_from_initiative() -> Array[Entity]:
	return party_initiative_order

func update_party_ui():
	if death_manager.game_over_active: return
	var party_container = $Control/gui/HBoxContainer2/party
	if party_container:
		for i in range(party_container.get_child_count()):
			var ui = party_container.get_child(i)
			if ui.has_method("update_effects_ui"):
				ui.update_effects_ui()

func add_attack(attacker: Object, attacked: Array, attack: Skill):
	attack_executor.attack_array[attacker] = [attacked, attack]

func get_enemy(index: int) -> Entity:
	if index >= 0 and index < 5:
		return enemies_by_slot[index]
	return null

func get_enemy_index(enemy: Entity) -> int:
	for i in range(5):
		if enemies_by_slot[i] == enemy:
			return i
	return -1

func get_alive_enemies() -> Array[Entity]:
	var alive: Array[Entity] = []
	for e in enemy_instances:
		if e and e.stats["hp"] > 0:
			alive.append(e)
	return alive

func are_all_enemies_defeated() -> bool:
	for e in enemy_instances:
		if e and e.stats["hp"] > 0:
			return false
	return true

func undo_last_action():
	if action_history.is_empty(): return
	var last = action_history.pop_back()
	if attack_executor.attack_array.has(last):
		var atk = attack_executor.attack_array[last][1]
		if atk.is_item_skill:
			var used_item = item_manager.item_ref
			PlayerStats.add_item(used_item, 1)  
			if item_manager and item_manager.available_items.has(used_item):
				var idx = item_manager.available_items.find(used_item)
				if idx >= 0:
					item_manager.item_amounts[idx] += 1
		attack_executor.attack_array.erase(last)
		current_attacker = last
		state = states.OnAction
		current_party_plan_index = max(0, current_party_plan_index - 1)
		move_who_moves_to_entity(current_attacker) 

func advance_planning():
	if death_manager.game_over_active: return
	state = states.Waiting

	var start = (initiative_who + 1) % initiative.size() if initiative.size() > 0 else 0
	for i in range(initiative.size()):
		var idx = (start + i) % initiative.size()
		var actor = initiative[idx]
		if actor.role == Entity.Role.PARTY and not attack_executor.attack_array.has(actor) and actor.stats["hp"] > 0:
			initiative_who = idx
			current_attacker = actor
			state = states.OnAction
			current_party_plan_index += 1
			move_who_moves_to_entity(current_attacker)
			return
			
	death_manager.check_party_wipe()
	start_resolution_phase()

func start_resolution_phase():
	if death_manager.game_over_active: return
	planning_phase = false
	state = states.Waiting
	$WhoMoves.visible = false
	for actor in initiative:
		if actor.role == Entity.Role.ENEMY:
			enemy_manager.queue_enemy_attack(actor)
	initiative_who = -1
	await get_tree().create_timer(0.33 * Settings.battle_speed).timeout
	advance_initiative()

func advance_initiative():
	if death_manager.game_over_active: return
	if planning_phase:
		return
	initiative_who += 1
	if initiative_who >= initiative.size():
		initiative_who = -1
		await attack_executor.do_attacks()
		return
	var current = initiative[initiative_who]
	if current.has_status("sleep"):
		if attack_executor.attack_array.has(current):
			attack_executor.attack_array.erase(current)
		$Control/enemy_ui/CenterContainer/output.text = current.name + " is asleep!"
		await get_tree().create_timer(0.5 * Settings.battle_speed).timeout
		advance_initiative()
		return
	if not attack_executor.attack_array.has(current):
		advance_initiative()
		return
	if current.role == Entity.Role.PARTY:
		current_attacker = current
	advance_initiative()

var stop_effects: Array = []
func start_round():
	if death_manager.game_over_active: return
	turn_number += 1
	
	effect_manager.tick_all_statuses()
	attack_executor.attack_array.clear()
	action_history.clear()
	planning_phase = true
	initiative_who = -1
	current_party_plan_index = -1
	setup_party()
	if state != states.Waiting:
		state = states.OnAction
	$WhoMoves.visible = false
	
	if condition_effect_manager and battle:
		var context = {
			"turn_number": turn_number, 
			"time_passed": time_passed
		}
		for effect in battle.turn_effects:
			if effect:
				if effect.is_battle_effect and effect not in stop_effects:
					condition_effect_manager.execute_effect(effect, current_attacker, context)
					if effect.one_timer and effect.used_effect:
						stop_effects.append(effect)
				else:
					effect.execute()
	
	advance_planning()

# === BATTLE BUTTON LOGIC ===
func _get_default_attack_skill() -> Skill:
	if current_attacker.equipped["weapon_left"] != null and current_attacker.equipped["weapon_left"].item_attack != null:
		return current_attacker.equipped["weapon_left"].item_attack
	if current_attacker.equipped["weapon_right"] != null and current_attacker.equipped["weapon_right"].item_attack != null:
		return current_attacker.equipped["weapon_right"].item_attack
	return load("res://resources/attacks/attack.tres")

func _on_fight_button_pressed() -> void:
	if state != states.OnAction: return
	
	var atk_skill = _get_default_attack_skill()
	if not atk_skill: return

	# Lock state immediately to prevent spam/double inputs
	state = states.Waiting 
	
	match atk_skill.target_type:
		0: # Single Enemy - REQUIRES SELECTION
			state = states.OnEnemy
			selected_enemy = previous_enemy if previous_enemy >= 0 and previous_enemy < enemy_instances.size() else 0
			
		1: # Self
			add_attack(current_attacker, [current_attacker], atk_skill)
			action_history.append(current_attacker)
			advance_planning()
			
		2: # Party (All Allies)
			add_attack(current_attacker, party, atk_skill)
			action_history.append(current_attacker)
			advance_planning()
			
		3: # All Enemies
			add_attack(current_attacker, enemy_instances, atk_skill)
			action_history.append(current_attacker)
			advance_planning()
			
		5: # Random Enemy
			var alive_enemies = get_alive_enemies()
			if not alive_enemies.is_empty():
				add_attack(current_attacker, [alive_enemies[randi_range(0, alive_enemies.size()-1)]], atk_skill)
				action_history.append(current_attacker)
				advance_planning()
			else:
				state = states.OnAction # Revert if no enemies alive
				
		_: # Fallback for unhandled types (like Single Ally)
			state = states.OnAction

func _on_skills_button_pressed() -> void:
	get_viewport().set_input_as_handled()
	skill_manager.open_skills_menu()
	
func _on_defend_button_pressed() -> void:
	if state != states.OnAction: return
	var defend_skill = load("res://resources/attacks/defend.tres")
	add_attack(current_attacker, [current_attacker], defend_skill)
	action_history.append(current_attacker)
	advance_planning()

func _on_item_button_pressed() -> void:
	if not battle.can_use_items:
		$Control/enemy_ui/CenterContainer/output.text = "Items are disabled in this battle!"
		await get_tree().create_timer(0.5 * Settings.battle_speed).timeout
		return
	
	get_viewport().set_input_as_handled()
	item_manager.open_items_menu()

func _on_run_button_pressed() -> void:
	if not battle.can_flee:
		Sfx2.stream = load("res://assets/sound/sfx/error.mp3")
		await get_tree().create_timer(0.5 * Settings.battle_speed).timeout
		return
	if state == states.Waiting: return

	state = states.Waiting

	var counter = 0
	for e in enemy_instances:
		counter += e.stats["speed"] if e.stats["hp"] > 0 else 0
	var chance = 0
	for p in party: 
		chance += p.stats["speed"] if p.stats.has("speed") else p.stats.get("speed", 10)
	var diff = clampf(counter - chance + 10, 0, 30)

	if randi_range(1, 20) > diff:
		Global.loading = true
		get_tree().change_scene_to_file(Global.current_scene)
		Global.loading = false
	else:
		Sfx2.stream = load("res://assets/sound/sfx/error.mp3")
		await get_tree().create_timer(0.5 * Settings.battle_speed).timeout
		for e in enemy_instances:
			if e.stats["hp"] > 0:
				enemy_manager.queue_enemy_attack(e)
		await attack_executor.do_attacks()
		state = states.OnAction

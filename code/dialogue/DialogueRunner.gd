class_name DialogueRunner
extends Node

## Runtime dialogue executor
## Manages flow, evaluates conditions, emits signals for UI

signal dialogue_started(_data: Object)
signal node_entered(node: DialogueNode)
signal text_displayed(text: String)
signal choice_available(choice: DialogueChoice)
signal choice_selected(choice: DialogueChoice)
signal dialogue_ended(last_node: Object)

var data: Object #DialogueData
var evaluator: DialogueConditionEvaluator
var current_node: DialogueNode
var current_label: String
var is_running: bool = false


func start(dialogue_data: DialogueData, dialogue_evaluator: DialogueConditionEvaluator) -> void:
	data = dialogue_data
	evaluator = dialogue_evaluator
	
	if not data:
		push_error("DialogueRunner: No dialogue data provided")
		return
	
	# Validate before starting
	var errors = data.validate()
	if not errors.is_empty():
		for err in errors:
			push_warning("Dialogue validation: %s" % err)
	
	current_label = data.start_label
	if data.start_branches:
		for branch in data.start_branches:
			if evaluator.evaluate(branch) == true:
				current_label = branch.target_label
				break
	
	is_running = true
	
	dialogue_started.emit(data)
	_goto_label(current_label)

func _goto_label(label: String) -> void:
	var node = data.get_node_by_label(label)
	if not node:
		if label != "":
			push_error("DialogueRunner: Node not found: '%s'" % label)
		end_dialogue()
		return
	
	current_node = node
	current_label = label
	
	# Run enter effects
	await _run_effects(node.on_enter_effects)
	
	node_entered.emit(node)
	text_displayed.emit(node.text)
	
	# Emit choices
	if node.has_choices():
		for choice in node.choices:
			if choice.is_available(evaluator) == true:
				choice_available.emit(choice)

func advance() -> void:
	if not is_running or not current_node:
		return
	
	# Run exit effects
	await _run_effects(current_node.on_exit_effects)
	
	if current_node.unskippable == true:
		return
	
	# Check branches first (conditional jumps)
	if current_node.has_branches():
		for branch in current_node.branches:
			if evaluator.evaluate(branch) == true:
				_goto_label(branch.target_label)
				return
	
	# Then check if we have choices (wait for player)
	if current_node.has_choices():
		return  # Wait for choice selection
	
	print(current_label, current_node.next_label)
	# Otherwise go to next node
	if not current_node.next_label.is_empty():
		_goto_label(current_node.next_label)
	else:
		end_dialogue()

func select_choice(choice: DialogueChoice) -> void:
	if not is_running or not current_node:
		return
		
	choice_selected.emit(choice)
	
	var label = choice.get_target_label()
	if label.is_empty():
		push_error("DialogueRunner: Choice '%s' has no target label or availability branch target." % choice.text)
		end_dialogue()
		return
		
	_goto_label(label)

func end_dialogue() -> void:
	if not is_running:
		return
	
	is_running = false
	var last_node = current_node
	current_node = null
	current_label = ""
	
	dialogue_ended.emit(last_node)

func _run_effects(effects: Array[DialogueEffect]) -> void:
	for effect in effects:
		if not effect:
			continue
		
		match effect.effect_type:
			DialogueEffect.EffectType.SET_VARIABLE:
				_effect_set_variable(effect.param_string, str_to_var(effect.param_value))
			
			DialogueEffect.EffectType.ADD_ITEM:
				_effect_add_item(effect.param_string, int(effect.param_value))
			
			DialogueEffect.EffectType.REMOVE_ITEM:
				_effect_remove_item(effect.param_string, int(effect.param_value))
			
			DialogueEffect.EffectType.ADD_STATUS:
				_effect_add_status(effect.param_string)
			
			DialogueEffect.EffectType.REMOVE_STATUS:
				_effect_remove_status(effect.param_string)
				
			DialogueEffect.EffectType.ADD_PARTY:
				_effect_add_party(effect.param_string)
				
			DialogueEffect.EffectType.STORE_PARTY:
				_effect_store_party(effect.param_string)
				
			DialogueEffect.EffectType.READD_PARTY:
				_effect_readd_party(effect.param_string)
			
			DialogueEffect.EffectType.START_QUEST:
				_effect_start_quest(effect.param_string)
			
			DialogueEffect.EffectType.COMPLETE_QUEST:
				_effect_complete_quest(effect.param_string)
				
			DialogueEffect.EffectType.REMOVE_QUEST:
				pass #_effect_remove_quest(effect.param_string)
			
			DialogueEffect.EffectType.TRIGGER_EVENT:
				_effect_trigger_event(effect.param_string, effect.param_value, effect.param_value2)
				
			DialogueEffect.EffectType.PLAY_CUTSCENE:
				await _effect_play_cutscene(effect.param_string)
				
			DialogueEffect.EffectType.WAIT:
				Global.player_ref.force_stop_move = true
				await _effect_wait(effect.wait_seconds)
				if Global.player_ref:
					Global.player_ref.force_stop_move = false
			
			DialogueEffect.EffectType.PLAY_SFX:
				Global.player_ref.force_stop_move = true
				await _effect_play_sfx(effect.param_string, effect.param_value)
				if Global.player_ref:
					Global.player_ref.force_stop_move = false
			
			DialogueEffect.EffectType.AUTOSAVE:
				_effect_autosave()
			
			DialogueEffect.EffectType.REMOVE_NPC:
				_effect_remove_npc(effect.param_string)
			
			DialogueEffect.EffectType.CUSTOM:
				_effect_custom(effect)
	return

func _effect_set_variable(var_name: String, value) -> void:
	if Global.get(var_name) != null:
		Global[var_name] = value
	if load(Global.current_scene).get(var_name) != null:
		load(Global.current_scene)[var_name] = value
	if Global.battle_ref != null:
		if Global.battle_ref.get(var_name) != null:
			Global.battle_ref[var_name] = value
	for i in PlayerStats.party:
		if i.get(var_name) != null:
			i[var_name] = value

func _effect_add_item(item_res_path: String, amount: int = 1) -> void:
	if amount < 1:
		amount = 1
	var item = load(item_res_path)
	print(item.item_name, item_res_path)
	PlayerStats.add_item(item, amount)

func _effect_remove_item(item_res_path: String, amount: int = 1) -> void:
	if amount < 1:
		amount = 1
	var item = load(item_res_path)
	PlayerStats.remove_item(item, amount)

func _effect_add_status(_status_id: String) -> void:
	# Hook this to your status system
	pass

func _effect_remove_status(_status_id: String) -> void:
	# Hook this to your status system
	pass

func _effect_add_party(party_res: String) -> void:
	PlayerStats.party.append(load(party_res))
	Global.player_ref.create_party_sprites()

func _effect_store_party(party_name: String) -> void:
	for p in PlayerStats.party:
		if p.name == party_name:
			var index = PlayerStats.party.find(p)
			PlayerStats.stored_party.append(p)
			PlayerStats.party.remove_at(index)
			get_tree().current_scene.player.create_party_sprites()
			break
	
func _effect_readd_party(party_name: String) -> void:
	for p in PlayerStats.stored_party:
		if p.name == party_name:
			var index = PlayerStats.stored_party.find(p)
			PlayerStats.party.append(p)
			PlayerStats.stored_party.remove_at(index)
			get_tree().current_scene.player.create_party_sprites()
			break

func _effect_start_quest(quest_id: String) -> void:
	var quest = load(quest_id)
	QuestSystem.add_quest(quest)

func _effect_complete_quest(quest_id: String) -> void:
	var quest = load(quest_id)
	QuestSystem.complete_quest(quest)

func _effect_trigger_event(event_name: String, event_var, event_bonus_var) -> void:
	if event_name.to_lower() == "open shop" or event_name.to_lower() == "open_shop":
		Global.shop_current = load(event_var)
		get_tree().change_scene_to_file("res://scenes/ui/shop/shop.tscn")
	elif event_name.to_lower() == "start battle" or event_name.to_lower() == "start_battle":
		Global.player_ref.force_stop_move = true
		Global.get_tree().current_scene.create_battle(event_var)
	elif event_name.to_lower() == "change room" or event_name.to_lower() == "change_room":
		print("[DialogueRunner] Moving player to room {event_var} at position {event_bonus_var}")
		await $"../../..".save_data()
		print("e")
		await $"../../../transition/black_flash".reappear()
		print("e")
		PlayerStats.player_position = str_to_var("Vector2"+event_bonus_var)
		print("e")
		Global.loading = true
		get_tree().change_scene_to_file(event_var)
		Global.loading = false
	elif event_name.to_lower() == "done thing" or event_name.to_lower() == "done_thing":
		get_tree().current_scene.done_things.set(event_var, str_to_var(event_bonus_var))

func _effect_play_cutscene(cutscene_name: String) -> void:
	var cutscene_tree = get_tree().current_scene.get_node("Cutscenes")
	var cutscene = cutscene_tree.get_node(cutscene_name)
	cutscene.play(StringName(cutscene_name))
	return

func _effect_wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	return

func _effect_play_sfx(audio_path: String, audio_bus: String = "1") -> void:
	audio_bus = "1" if audio_bus == "" else audio_bus
	var audio = load(audio_path)
	var bus: AudioStreamPlayer = get_tree().current_scene.get_node("Sfx" + audio_bus)
	bus.stream = audio
	bus.play()
	await bus.finished
	return

func _effect_autosave():
	SaveManager.save_game(0, "Autosave")
	
func _effect_remove_npc(npc_name: String):
	if get_tree().current_scene.has_method("outbattle_root_check"):
		get_tree().current_scene.enemies_deactivated.append(npc_name)
		get_tree().current_scene.get_node("NavigationRegion2D").get_node(npc_name).queue_free()

func _effect_custom(effect: DialogueEffect) -> void:
	if effect.custom_script.is_empty():
		push_error("DialogueRunner: Custom effect has no script path")
		return
	
	var script = load(effect.custom_script)
	if not script:
		push_error("DialogueRunner: Failed to load custom effect script: %s" % effect.custom_script)
		return
	
	if script.has_static_method("apply"):
		script.apply(effect, self)
	else:
		push_error("DialogueRunner: Custom effect script missing static apply() function: %s" % effect.custom_script)

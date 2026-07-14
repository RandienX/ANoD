@tool
class_name Effect
extends Resource

## Effect that runs when entering/exiting a  node

enum EffectType {
	SET_VARIABLE,         # Set a game variable
	ADD_ITEM,             # Give item to player
	REMOVE_ITEM,          # Take item from player
	ADD_STATUS,           # Apply status effect
	REMOVE_STATUS,        # Remove status effect
	ADD_PARTY,            # Adds Party member
	STORE_PARTY,          # Stores party member data away from party
	READD_PARTY,          # Readds Party member from stored party data
	START_QUEST,          # Begin quest
	COMPLETE_QUEST,       # Finish quest
	REMOVE_QUEST,         # Remove quest
	TRIGGER_EVENT,        # Fire a signal/event
	PLAY_CUTSCENE,        # Play a set cutscene
	WAIT,                 # Pause  briefly
	PLAY_SFX,             # Play an SFX
	AUTOSAVE,
	REMOVE_NPC,
	START_DIALOGUE
}

enum InBattleEffectType {
	START_DIALOGUE,
	TRIGGER_PHASE,
	ADD_SKILL,
	ADD_STAT,
	ADD_STATUS,
	END_BATTLE_PREMATURELY,
	SPAWN_REINFORCEMENTS,
	RESET_ENEMY_HEALTH,
}

enum InBattleTargetType {
	ENEMY_SLOT,
	PARTY_MEMBER_NAME,
	SPECIFIC_ENEMY_NAME,
	RANDOM_ENEMY,
	ALL_ENEMIES,
	ALL_PARTY
}

@export var conditions: Array[Condition] = []
@export var effect_type: EffectType = EffectType.ADD_ITEM
@export_group("In Battle Effects")
@export var is_battle_effect: bool = false
@export var battle_effect_type: InBattleEffectType = InBattleEffectType.START_DIALOGUE
@export var battle_effect_target: InBattleTargetType = InBattleTargetType.ENEMY_SLOT
@export var battle_target_string: String = ""
@export var one_timer: bool = true
var used_effect: bool = false

@export_category("Settings")
@export var param_string: String = ""      # var_name, item_id, status_id, quest_id, event_name
@export var param_value: String = ""       # value, amount
@export var param_value2: String = ""       # value, amount (FOR SET_VARIABLE and TRIGGER_EVENT)
@export var wait_seconds: float = 1.0      # For WAIT type
@export var custom_script: String = ""     # Path to custom effect script

func evaluate_conditions():
	if conditions.is_empty():
		return true
	
	for condition in conditions:
		if not condition:
			continue
			
		var available: bool = false
		
		var int_av = condition.evaluate()
		if int_av >= condition.param_value:
			available = false if condition.invert else true
		
		if not available:
			return false
			
	return true

func execute():
	if !evaluate_conditions():
		return
	
	if custom_script != "":
		_effect_custom()
		return
	
	match effect_type:
		EffectType.SET_VARIABLE:
			_effect_set_variable(param_string, str_to_var(param_value))
		
		EffectType.ADD_ITEM:
			_effect_add_item(param_string, int(param_value))
		
		EffectType.REMOVE_ITEM:
			_effect_remove_item(param_string, int(param_value))
		
		EffectType.ADD_STATUS:
			_effect_add_status(param_string)
		
		EffectType.REMOVE_STATUS:
			_effect_remove_status(param_string)
			
		EffectType.ADD_PARTY:
			_effect_add_party(param_string)
			
		EffectType.STORE_PARTY:
			_effect_store_party(param_string)
			
		EffectType.READD_PARTY:
			_effect_readd_party(param_string)
		
		EffectType.START_QUEST:
			_effect_start_quest(param_string)
		
		EffectType.COMPLETE_QUEST:
			_effect_complete_quest(param_string)
			
		EffectType.REMOVE_QUEST:
			pass #_effect_remove_quest(param_string)
		
		EffectType.TRIGGER_EVENT:
			_effect_trigger_event(param_string, param_value, param_value2)
			
		EffectType.PLAY_CUTSCENE:
			_effect_play_cutscene(param_string)
			
		EffectType.WAIT:
			DialogueInitiator._dialogue_runner.current_node.unskippable = true
			await _effect_wait(wait_seconds)
			DialogueInitiator._dialogue_runner.current_node.unskippable = false
		
		EffectType.PLAY_SFX:
			_effect_play_sfx(param_string, param_value)
		
		EffectType.AUTOSAVE:
			_effect_autosave()
		
		EffectType.REMOVE_NPC:
			_effect_remove_npc(param_string)
			
		EffectType.START_DIALOGUE:
			_effect_start_dialogue(param_string)

func _effect_set_variable_target(var_name: String, value, target: Object) -> void:
	if target == null:
		_effect_set_variable(var_name, value)
		return
	if target.has_method("get") and target.has_method("set") and target.get(var_name) != null:
		target[var_name] = value

func _effect_add_status_target(target: Object, status_id: String) -> void:
	if target == null or status_id.is_empty():
		return
	if target.has_method("apply_status") and ResourceLoader.exists(status_id):
		var status_def = load(status_id)
		if status_def != null:
			target.apply_status(status_def)

func _effect_remove_status_target(target: Object, status_id: String) -> void:
	if target == null:
		return
	if target.has_method("remove_status"):
		target.remove_status(status_id)

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
	var party = load(party_res)
	party.stats["hp"] = party.base_stats["hp"]
	party.stats["mp"] = party.base_stats["mp"]
	party.max_stats["hp"] = party.base_stats["hp"]
	party.max_stats["mp"] = party.base_stats["mp"]
	PlayerStats.party.append(party)
	party.recalculate_level_stats()
	Global.player_ref.create_party_sprites()

func _effect_store_party(party_name: String) -> void:
	for p in PlayerStats.party:
		if p.name == party_name:
			var index = PlayerStats.party.find(p)
			PlayerStats.stored_party.append(p)
			PlayerStats.party.remove_at(index)
			Global.get_tree().current_scene.player.create_party_sprites()
			break
	
func _effect_readd_party(party_name: String) -> void:
	for p in PlayerStats.stored_party:
		if p.name == party_name:
			var index = PlayerStats.stored_party.find(p)
			PlayerStats.party.append(p)
			PlayerStats.stored_party.remove_at(index)
			Global.get_tree().current_scene.player.create_party_sprites()
			break

func _effect_start_quest(quest_id: String) -> void:
	var quest = load(quest_id)
	QuestSystem.add_quest(quest)

func _effect_complete_quest(quest_id: String) -> void:
	var quest = QuestSystem.active_quests
	for q in quest:
		if q.quest_id == load(quest_id).quest_id:
			QuestSystem.complete_quest(q)
			break

func _effect_trigger_event(event_name: String, event_var, event_bonus_var) -> void:
	if event_name.to_lower() == "open shop" or event_name.to_lower() == "open_shop":
		Global.shop_current = load(event_var)
		Global.get_tree().change_scene_to_file("res://scenes/ui/shop/shop.tscn")
	elif event_name.to_lower() == "start battle" or event_name.to_lower() == "start_battle":
		Global.get_tree().current_scene.create_battle(event_var)
	elif event_name.to_lower() == "change room" or event_name.to_lower() == "change_room":
		Global.get_tree().current_scene.save_data()
		Global.get_tree().current_scene.get_node("transition/black_flash").reappear()
		print("[Runner] Moving player to room %s at position %s" % [load(event_var).instantiate().room_name, event_bonus_var])
		if event_bonus_var != "":
			PlayerStats.player_position = str_to_var("Vector2"+event_bonus_var)
		Global.loading = true
		Global.get_tree().change_scene_to_file(event_var)
		Global.loading = false
	elif event_name.to_lower() == "done thing" or event_name.to_lower() == "done_thing":
		Global.get_tree().current_scene.done_things.set(event_var, str_to_var(event_bonus_var))
	elif event_name == "foxy_track":
		Global.is_track_story = true
		Global.current_foxy_track = load(event_var)
		Global.get_tree().change_scene_to_file("res://scenes/minigames/foxyGoon/foxy_goon.tscn")

func _effect_play_cutscene(cutscene_name: String) -> void:
	var cutscene_tree = Global.get_tree().current_scene.get_node("Cutscenes")
	var cutscene = cutscene_tree.get_node(cutscene_name)
	cutscene.play(StringName(cutscene_name))

func _effect_wait(seconds: float) -> void:
	await Global.get_tree().create_timer(seconds).timeout
	return

func _effect_play_sfx(audio_path: String, audio_bus: String = "1") -> void:
	audio_bus = "1" if audio_bus == "" else audio_bus
	var audio = load(audio_path)
	var bus: AudioStreamPlayer
	if audio_bus == "1":
		bus = Sfx
	else:
		bus = Sfx2
	bus.stream = audio
	bus.play()
	return

func _effect_autosave():
	SaveManager.save_game(0, "Autosave")
	
func _effect_remove_npc(npc_name: String):
	if Global.get_tree().current_scene.has_method("outbattle_root_check"):
		Global.get_tree().current_scene.enemies_deactivated.append(npc_name)
		Global.get_tree().current_scene.get_node("NavigationRegion2D").get_node(npc_name).queue_free()

func _effect_start_dialogue(dialogue_path: String):
	if dialogue_path != "":
		DialogueInitiator.start_dialogue(load(dialogue_path), false, true)

func _effect_custom() -> void:
	if custom_script.is_empty():
		push_error("Runner: Custom effect has no script path")
		return
	
	var script: GDScript = load(custom_script)
	if not script:
		push_error("Runner: Failed to load custom effect script: %s" % custom_script)
		return
	
	if script.has_script_method("apply"):
		script.apply(self)
	else:
		push_error("Runner: Custom effect script missing apply() function: %s" % custom_script)
		breakpoint

class_name DialogueConditionEvaluator
extends RefCounted

## Evaluates dialogue branch conditions
## Connect this to your game's data systems

# Signals for custom condition evaluation
@warning_ignore("unused_signal")
signal custom_condition_requested(branch: DialogueCondition, result_callback: Callable)

# Game state hooks - connect these to your actual game systems
var has_status_func: Callable = Callable()     # func(effect_id: String) -> bool
var get_variable_func: Callable = Callable()   # func(var_name: String) -> float
var is_quest_complete_func: Callable = Callable()   # func(quest_id: String) -> bool
var is_quest_active_func: Callable = Callable()     # func(quest_id: String) -> bool

func evaluate(branch: DialogueBranch) -> bool:
	if not branch:
		return false
	if branch.conditions.is_empty():
		return true

	for condition in branch.conditions:
		if not condition:
			continue
			
		var available: bool = false
		
		match condition.condition_type:
			DialogueCondition.ConditionType.HAS_ITEM:
				available = _eval_has_item(condition.param_string, int(condition.param_value))
			DialogueCondition.ConditionType.HAS_STATUS:
				available = _eval_has_status(condition.param_string)
			DialogueCondition.ConditionType.HAS_PARTY_MEMBER:
				available = _eval_has_party_member(condition.param_string)
			DialogueCondition.ConditionType.DONE_THING:
				available = _eval_done_thing(condition.param_string, condition.param_value)
			DialogueCondition.ConditionType.DONE_DIALOGUE:
				available = _eval_done_dialogue(condition.param_string)
			DialogueCondition.ConditionType.TALKED_TO_NPC:
				available = _eval_talked_to_npc(condition.param_string, condition.param_value)
			DialogueCondition.ConditionType.KILLED_ENEMY:
				available = _eval_killed_enemies(condition.param_string, condition.param_value)
			DialogueCondition.ConditionType.BATTLE_WON:
				available = _eval_battles_won(condition.param_string, condition.param_value)
			DialogueCondition.ConditionType.RANDOM_CHANCE:
				available = _eval_random(condition.param_value)
			DialogueCondition.ConditionType.QUEST_COMPLETE:
				available = _eval_quest_complete(condition.param_string)
			DialogueCondition.ConditionType.QUEST_ACTIVE:
				available = _eval_quest_active(condition.param_string)
			DialogueCondition.ConditionType.CUSTOM:
				available = _eval_custom(condition)
			_:
				push_warning("Unknown condition type: %s" % condition.condition_type)
				return false
		
		if not available:
			return false
			
	return true

func _eval_has_item(item_id: String, amount: int) -> bool:
	if PlayerStats.has_method("has_item"):
		return PlayerStats.has_item(load(item_id), amount)
	push_warning("Dialogue: has_item_func not set, cannot check for '%s'" % item_id)
	return false

func _eval_has_status(_effect_id: String) -> bool:
	return false

func _eval_has_party_member(party_member_name: String) -> bool:
	for p in PlayerStats.party:
		if p.name == party_member_name:
			return true
	return false

func _eval_done_thing(thing_name: String, value) -> bool:
	for scene in Global.scene_data.keys():
		if Global.scene_data[scene].keys().has("done_things"):
			if Global.scene_data[scene]["done_things"].keys().has(thing_name):
				if Global.scene_data[scene]["done_things"][thing_name]:
					return true
	return false

func _eval_done_dialogue(dialogue_name: String) -> bool:
	for scene in Global.scene_data.keys():
		if Global.scene_data[scene].keys().has("dialogue_completed"):
			if Global.scene_data[scene]["dialogue_completed"].has(dialogue_name):
				return true
	if Global.get_tree().current_scene.has_method("outbattle_root_check"):
		if dialogue_name in Global.get_tree().current_scene.completed_dialogues:
			return true
	return false

func _eval_talked_to_npc(_interaction_name: String, _value: float) -> bool:
	return false

func _eval_killed_enemies(enemy_name: String, value: float = 1) -> bool:
	if Global.enemies_killed.has(enemy_name):
		if Global.enemies_killed[enemy_name] >= value:
			return true
	return false
	
func _eval_battles_won(battle_name: String, value: float = 1) -> bool:
	if Global.battles_won.has(battle_name):
		if Global.battles_won[battle_name] >= value:
			return true
	return false
	
func _eval_random(percent: float) -> bool:
	return randf_range(0, 100) < percent

func _eval_quest_complete(quest_id: String) -> bool:
	if is_quest_complete_func.is_valid():
		return is_quest_complete_func.call(quest_id)
	push_warning("Dialogue: is_quest_complete_func not set, cannot check '%s'" % quest_id)
	return false

func _eval_quest_active(quest_id: String) -> bool:
	if QuestSystem.has_quest(quest_id):
		return true
	return false

func _eval_custom(condition: DialogueCondition) -> bool:
	if condition.custom_script.is_empty():
		push_error("Dialogue: Custom branch has no script path")
		return false
	
	# Load and execute custom script
	var script = load(condition.custom_script)
	if not script:
		push_error("Dialogue: Failed to load custom script: %s" % condition.custom_script)
		return false
	
	# Expect a static function: static func evaluate(branch: DialogueCondition, evaluator: DialogueConditionEvaluator) -> bool
	if script.has_static_method("evaluate"):
		return script.evaluate(condition, self)
	
	push_error("Dialogue: Custom script missing static evaluate() function: %s" % condition.custom_script)
	return false

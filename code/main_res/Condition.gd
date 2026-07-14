extends Resource
class_name Condition

enum ConditionType {
	HAS_ITEM,           # Check if player has item
	HAS_STATUS,         # Check if player has status effect
	HAS_PARTY_MEMBER,    # Check if player has party member
	DONE_THING,    
	DONE_DIALOGUE,
	TALKED_TO_NPC,      
	KILLED_ENEMY,   
	BATTLE_WON,
	RANDOM_CHANCE,      # RNG from 1 to 100
	QUEST_COMPLETE,     # Quest is finished
	QUEST_ACTIVE,       # Quest is in progress
	VISITED_LOCATION
}

enum BattleConditionType {
	STAT_BELOW,               # Check if target current stat is below a value
	STAT_BELOW_PERCENT,       # Check if target current stat is a percentage of max stats below set value
	ENTITY_ALIVE,             # Check if entity is alive
	ENTITY_EXISTS,            # Check if entity of this type exists
	ON_TURN,                  # Do on that turn number
	AFTER_TIME_PASSED,        # Do after this amound of time passed and another round started
	HAS_STATUS,               # Check if target has this status id
	ALL_ENEMIES_DEFEATED,     # Do on battle end when all enemies are defeated, then check again if all enemies are killed, after that end battle after dialogue etc is finished.
	SPECIFIC_ENEMY_DEFEATED,  # Check if target is defeated
	RANDOM_CHANCE,            # RNG from 1 to 100
}

enum Operator {
	GREATER_THAN,        # >
	LESS_THAN,           # <
	EQUALS,              # ==
	GREATER_EQUAL,       # >=
	LESS_EQUAL,          # <=
	HAS_STATUS,          # Has specific status
	NOT_HAS_STATUS,      # Does not have status
}

@export var condition_type: ConditionType = ConditionType.HAS_ITEM
@export_group("Battle Conditions")
@export var battle_condition_type: BattleConditionType = BattleConditionType.STAT_BELOW
@export_category("Settings")
@export var description: String = ""  # Optional custom description

@export var param_string: String = ""      # item_id, status_id, var_name, quest_id, stat name
@export var param_value: float = 1.0       # amount, comparison value, percent
@export var is_absolute: bool = true
@export var custom_script: String = ""     # Path to custom condition script

@export var quest_icon: Texture2D

var progress_current: float = 0.0  # Current progress
var _initial_value_count: Variant = 0  # Keep as Variant for future flexibility (int, float, etc.)

@export var invert: bool = false 

#func initialize_value():
	#if !is_absolute:
		#match ConditionType:
			#ConditionType.KILLED_ENEMY:

## Check if this condition is currently met
func is_complete() -> bool:
	return progress_current >= param_value

func get_condition_type_name() -> String:
	return ConditionType.keys()[condition_type]

func evaluate() -> int:
	if custom_script:
		return _eval_custom()
	
	match condition_type:
		ConditionType.HAS_ITEM:
			return _eval_has_item(param_string)
		ConditionType.HAS_STATUS:
			if _eval_has_status(param_string) and !invert:
				return 1
			elif !_eval_has_status(param_string) and invert:
				return 1
			else:
				return 0
		ConditionType.HAS_PARTY_MEMBER:
			if _eval_has_party_member(param_string) and !invert:
				return 1
			elif !_eval_has_party_member(param_string) and invert:
				return 1
			else:
				return 0
		ConditionType.DONE_THING:
			if _eval_done_thing(param_string, 1) and !invert:
				return 1
			elif !_eval_done_thing(param_string, 1) and invert:
				return 1
			else:
				return 0
		ConditionType.DONE_DIALOGUE:
			if _eval_done_dialogue(param_string) and !invert:
				return 1
			elif !_eval_done_dialogue(param_string) and invert:
				return 1
			else:
				return 0
		ConditionType.TALKED_TO_NPC:
			if _eval_talked_to_npc(param_string, param_value) and !invert:
				return 1
			elif !_eval_talked_to_npc(param_string, param_value) and invert:
				return 1
			else:
				return 0
		ConditionType.KILLED_ENEMY:
			return _eval_killed_enemies(param_string)
		ConditionType.BATTLE_WON:
			return _eval_battles_won(param_string)
		ConditionType.RANDOM_CHANCE:
			return randi_range(0, 100) >= param_value
		ConditionType.QUEST_COMPLETE:
			if _eval_quest_complete(param_string) and !invert:
				return 1
			elif !_eval_quest_complete(param_string) and invert:
				return 1
			else:
				return 0
		ConditionType.QUEST_ACTIVE:
			if _eval_quest_active(param_string) and !invert:
				return 1
			elif !_eval_quest_active(param_string) and invert:
				return 1
			else:
				return 0
		ConditionType.VISITED_LOCATION:
			if _eval_visited_location(param_string) and !invert:
				return 1
			elif !_eval_visited_location(param_string) and invert:
				return 1
			else:
				return 0
			
		# For absolute mode, don't set a baseline
		_:
			push_warning("Unknown condition type: %s" % condition_type)
			return false

func _eval_has_item(item_id: String) -> int:
	return PlayerStats.get_item_amount(load(item_id))

func _eval_has_status(_effect_id: String) -> bool:
	return false

func _eval_has_party_member(party_member_name: String) -> bool:
	for p in PlayerStats.party:
		if p.name == party_member_name:
			return true
	return false

func _eval_done_thing(thing_name: String, _value) -> bool:
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

func _eval_killed_enemies(enemy_name: String) -> int:
	if Global.enemies_killed.has(enemy_name):
		return Global.enemies_killed[enemy_name]
	return false
	
func _eval_battles_won(battle_name: String) -> int:
	if Global.battles_won.has(battle_name):
		return Global.battles_won[battle_name]
	return false
	
func _eval_random(percent: float) -> bool:
	return randf_range(0, 100) < percent

func _eval_quest_complete(quest_id: String) -> bool:
	if quest_id in QuestSystem.get_completed_quests():
		return true
	return false

func _eval_quest_active(quest_id: String) -> bool:
	if QuestSystem.has_quest(quest_id):
		return true
	return false

func _eval_visited_location(room_name: String) -> bool:
	if room_name in Global.scene_data.keys():
		return true
	return false

func _eval_custom() -> bool:
	if custom_script.is_empty():
		push_error("Dialogue: Custom branch has no script path")
		return false
	
	# Load and execute custom script
	var script = load(custom_script)
	if not script:
		push_error("Dialogue: Failed to load custom script: %s" % custom_script)
		return false
	
	# Expect a static function: static func evaluate(branch: DialogueCondition, evaluator: DialogueConditionEvaluator) -> bool
	if script.has_static_method("evaluate"):
		return script.evaluate(self)
	
	push_error("Dialogue: Custom script missing static evaluate() function: %s" % custom_script)
	return false
	
## Reset condition progress
func reset() -> void:
	progress_current = 0.0

## Add progress to this condition
func add_progress(amount: float = 1.0) -> void:
	progress_current = min(progress_current + amount, param_value)

## Initialize kill count baseline when quest starts (for KILLED_ENEMY conditions)
func initialize_kill_baseline() -> void:
	if condition_type == ConditionType.KILLED_ENEMY and not is_absolute:
		_initial_value_count = Global.enemies_killed.get(param_string, 0)
		progress_current = 0.0
	elif condition_type == ConditionType.KILLED_ENEMY and is_absolute:
		_initial_value_count = 0
		progress_current = 0.0

## Initialize battle won baseline when quest starts (for BATTLE_WON conditions)
func initialize_battle_baseline() -> void:
	if condition_type == ConditionType.BATTLE_WON and not is_absolute:
		var battle_state = Global.battles_won.get(param_string, 0)
		var initial_count = 1 if battle_state else 0
		if typeof(battle_state) == TYPE_INT or typeof(battle_state) == TYPE_FLOAT:
			initial_count = battle_state
			_initial_value_count = initial_count
			progress_current = 0.0
	elif condition_type == ConditionType.BATTLE_WON and is_absolute:
		_initial_value_count = 0
		progress_current = 0.0

## Get current progress for KILLED_ENEMY conditions based on global counter delta
func get_kill_progress() -> float:
	if condition_type != ConditionType.KILLED_ENEMY:
		return progress_current

	var current_total = Global.enemies_killed.get(param_string, 0)
	var kills_since_start = current_total - _initial_value_count
	return max(0.0, kills_since_start as float)

## -----------BATTLE EFFECT------------
@export_group("Battle Status Condition")

@export var enabled: bool = true
@export var check_stat: String = "hp"  # Stat to check (hp, mp, atk, etc.)
@export var operator: Operator = Operator.GREATER_THAN
@export var threshold_value: float = 0.0
@export var status_to_check: StatusDefinition = null  # For HAS_STATUS checks

func battle_effect_evaluate(entity: Entity) -> bool:
	if not enabled:
		return true
	
	var result: bool = false
	var actual_value: float = 0.0
	
	# Special handling for status checks
	if operator == Operator.HAS_STATUS or operator == Operator.NOT_HAS_STATUS:
		if status_to_check:
			result = entity.has_status(status_to_check.id)
			if operator == Operator.NOT_HAS_STATUS:
				result = not result
		else:
			result = false
	else:
		# Get stat value
		match check_stat:
			_:
				actual_value = float(entity.get_effective_stat(check_stat))
		
		# Compare against threshold
		match operator:
			Operator.GREATER_THAN:
				result = actual_value > threshold_value
			Operator.LESS_THAN:
				result = actual_value < threshold_value
			Operator.EQUALS:
				result = abs(actual_value - threshold_value) < 0.001
			Operator.GREATER_EQUAL:
				result = actual_value >= threshold_value
			Operator.LESS_EQUAL:
				result = actual_value <= threshold_value
	
	return not result if invert else result

func _get_icon() -> String:
	match operator:
		Operator.GREATER_THAN: return ">"
		Operator.LESS_THAN: return "<"
		Operator.EQUALS: return "=="
		Operator.GREATER_EQUAL: return ">="
		Operator.LESS_EQUAL: return "<="
		Operator.HAS_STATUS: return "HAS"
		Operator.NOT_HAS_STATUS: return "!HAS"
	return "?"

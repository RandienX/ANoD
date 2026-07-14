extends Resource
class_name Quest

## Quest - Main quest resource containing points and rewards
##
## The Quest resource is the primary processing object in the quest system.
## It contains a linear sequence of QuestPoints, each with conditions and logic gates.
## When completed, QuestEffects are executed as rewards.
##
## Structure:
## - Quest contains multiple QuestPoints (linear progression)
## - Each QuestPoint has multiple QuestPointConditions
## - Conditions use LogicGates (AND, OR, NOT) for evaluation
## - QuestEffects define rewards upon quest completion

@export_group("Quest Definition")
@export var quest_name: String = "New Quest"
@export var quest_id: String = ""  # Unique identifier NEEDS TO BE SAME AS FILE NAME
@export var description: String = ""
@export var category: String = ""  # Optional categorization

@export_group("Quest Structure")
@export var points: Array[QuestPoint] = []  # Linear progression of points (steps)
@export var effects: Array[Effect] = []  # Rewards on completion

@export_group("Progress Tracking")
@export var current_point_index: int = 0
@export var is_active: bool = false
@export var is_complete: bool = false
@export var is_failed: bool = false

@export_group("Optional")
@export var icon: Texture2D = null
@export var priority: int = 0  # For sorting (higher = more important)
@export var metadata: Dictionary = {}


func initialize() -> void:
	# Only reset state if not being initialized during load
	# This allows load_save_data to restore the actual saved state
	is_active = true
	is_complete = false
	is_failed = false
	current_point_index = 0

	# Reset all points and initialize kill baselines and battle baselines
	# Reset all points and initialize baselines only for the current point
	for point in points:
		point.reset()

	# Initialize baselines only for conditions in the current point
	_initialize_baselines_for_current_point()

	## Initialize this quest without resetting state (for loading from save)
func initialize_without_reset() -> void:
	_initialize_baselines_for_current_point()

	## Initialize baselines for conditions in the current point only
func _initialize_baselines_for_current_point() -> void:
	var current_point = get_current_point()
	if not current_point:
		return

	for condition in current_point.conditions:
		if condition.condition_type == Condition.ConditionType.KILLED_ENEMY:
			condition.initialize_kill_baseline(condition)
		elif condition.condition_type == Condition.ConditionType.BATTLE_WON:
			condition.initialize_battle_baseline(condition)
								
## Get the current active point
func get_current_point() -> QuestPoint:
	if points.is_empty():
		return null
	if current_point_index >= points.size():
		current_point_index = points.size() - 1
	return points[current_point_index]

## Evaluate current point and return its state
func evaluate() -> QuestPoint.QuestState:
	var point = get_current_point()
	if not point:
		return QuestPoint.QuestState.YES
		
	var state = point.evaluate()
		
	# Check if point is complete and advance
	if state == QuestPoint.QuestState.YES and point.auto_advance:
		_advance_to_next_point()

	return state

## Advance to next point
func _advance_to_next_point() -> bool:
	if current_point_index < points.size() - 1:
		current_point_index += 1
		_initialize_baselines_for_current_point()
		return true
	else:
		# All points complete - complete the quest
		complete_quest()
		return false

## Complete this quest and execute effects
func complete_quest() -> void:
	if is_complete:
		return
	
	is_complete = true
	is_active = false
	
	# Execute all reward effects
	for effect in effects:
		effect.execute()

## Fail this quest
func fail_quest() -> void:
	if is_failed or is_complete:
		return

	is_failed = true
	is_active = false

## Reset quest to initial state
func reset() -> void:
	is_active = false
	is_complete = false
	is_failed = false
	current_point_index = 0

	for point in points:
		point.reset()

## Get overall completion percentage (0.0 to 1.0)
func get_completion_percentage() -> float:
	if points.is_empty():
		return 1.0

	if is_complete:
		return 1.0

	if is_failed:
		return 0.0

	var total_progress := 0.0
	for i in range(points.size()):
		var point = points[i]
		total_progress += point.get_completion_percentage()

	return total_progress / points.size()

## Get current objective description
func get_current_objective() -> String:
	var point = get_current_point()
	if not point:
		return "Quest Complete!"

	return point.step_name

## Create save data for this quest
func get_save_data() -> Dictionary:
	return {
	"quest_id": quest_id,
	"quest_name": quest_name,
	"is_active": is_active,
	"is_complete": is_complete,
	"is_failed": is_failed,
	"current_point_index": current_point_index,
	"points_data": _serialize_points(),
	"metadata": metadata
	}

func _serialize_points() -> Array:
	var data := []
	for point in points:
		var point_data := {
		"step_name": point.step_name,
		"is_complete": point.is_complete,
		"auto_advance": point.auto_advance,
		"conditions_data": []
		}

		for condition in point.conditions:
			point_data["conditions_data"].append({
			"type": condition.condition_type,
			"target_key": condition.param_string,
			"progress_current": condition.progress_current,
			"progress_target": condition.param_value,
			"initial_value_count": condition._initial_value_count
			})

		data.append(point_data)

	return data

## Load quest from save data
func load_save_data(data: Dictionary) -> void:
	if data.has("is_active"):
		is_active = data["is_active"]
	if data.has("is_complete"):
		is_complete = data["is_complete"]
	if data.has("is_failed"):
		is_failed = data["is_failed"]
	if data.has("current_point_index"):
		current_point_index = data["current_point_index"]

	if data.has("points_data"):
		_deserialize_points(data["points_data"])
	# Restore metadata if present
	if data.has("metadata"):
		metadata = data["metadata"]

func _deserialize_points(points_data: Array) -> void:
	for i in range(min(points_data.size(), points.size())):
		var point_data = points_data[i]
		var point = points[i]

		if point_data.has("step_name"):
			point.step_name = point_data["step_name"]
		if point_data.has("is_complete"):
			point.is_complete = point_data["is_complete"]

		if point_data.has("logic_gate"):
			point.logic_gate = point_data["logic_gate"]

		if point_data.has("auto_advance"):
			point.auto_advance = point_data["auto_advance"]

func _deserialize_conditions(point: QuestPoint, conditions_data: Array) -> void:
	for i in range(min(conditions_data.size(), point.conditions.size())):
		var cond_data = conditions_data[i]
		var condition = point.conditions[i]
		if cond_data.has("type"):
			condition.type = cond_data["type"]
		if cond_data.has("target_key"):
			condition.target_key = cond_data["target_key"]
		if cond_data.has("progress_current"):
			condition.progress_current = cond_data["progress_current"]
		if cond_data.has("progress_target"):
			condition.progress_target = cond_data["progress_target"]
		if cond_data.has("initial_value_count"):
			condition._initial_value_count = cond_data["initial_value_count"]

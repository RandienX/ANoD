extends RefCounted
class_name QuestConditionHasPartyMember

## Custom quest condition script for checking if a specific party member is present
##
## Usage: Set target_key to the name of the party member you want to check for.
## The condition will be complete if any party member has a matching name.

static func evaluate(condition: QuestPointCondition, evaluator: QuestConditionEvaluator) -> bool:
		return get_progress(condition, evaluator) >= condition.progress_target

static func get_progress(condition: QuestPointCondition, evaluator: QuestConditionEvaluator) -> float:
	if condition.target_key == "":
		return 0.0

	var progress: float = 0.0

	# Check PlayerStats.party for a matching member
	# Party members are Entity resources with a 'name' property
	for p in PlayerStats.party:
		if p.name == condition.target_key:
			progress = 1.0
			break
	
	return min(progress, condition.progress_target)

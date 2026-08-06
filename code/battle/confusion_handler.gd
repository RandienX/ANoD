## Confusion effect behavior handler
## Intercepts action execution and applies confusion mechanics

extends Node

## Called when a confused entity is about to take their action
## Modifies their action based on confusion
static func handle_confused_action(entity: Entity, original_target: Entity, allies: Array, enemies: Array) -> Dictionary:
	"""
	Handle a confused entity's action.
	
	Returns a modified action dictionary with:
	- target: the actual target (may be different if confused redirected it)
	- should_execute: whether the action should execute at all
	- action_type: "attack", "nothing", "self"
	- message: flavor text for the log
	"""
	
	if not entity.has_status("confusion"):
		return {
			"target": original_target,
			"should_execute": true,
			"action_type": "normal",
			"message": ""
		}
	
	var confusion_roll = randi() % 100
	
	# Confusion behavior distribution:
	# 0-59: Attack ally/random
	# 60-74: Attack enemy/random  
	# 75-94: Do nothing (stand there confused)
	# 95-99: Attack self
	
	if confusion_roll < 60:
		# Attack ally
		if allies.is_empty():
			return {
				"target": entity,
				"should_execute": true,
				"action_type": "self",
				"message": "%s is confused and strikes themselves!" % entity.name
			}
		var confused_target = allies[randi() % allies.size()]
		return {
			"target": confused_target,
			"should_execute": true,
			"action_type": "attack",
			"message": "%s is confused and attacks their ally %s!" % [entity.name, confused_target.name]
		}
	
	elif confusion_roll < 75:
		# Attack random enemy
		if enemies.is_empty():
			return {
				"target": entity,
				"should_execute": true,
				"action_type": "self",
				"message": "%s is confused and strikes themselves!" % entity.name
			}
		var confused_target = enemies[randi() % enemies.size()]
		return {
			"target": confused_target,
			"should_execute": true,
			"action_type": "attack",
			"message": "%s shakes their head and swings wildly at %s!" % [entity.name, confused_target.name]
		}
	
	elif confusion_roll < 95:
		# Do nothing - just stand there
		return {
			"target": null,
			"should_execute": false,
			"action_type": "nothing",
			"message": "%s staggers around, too confused to act!" % entity.name
		}
	
	else:
		# Attack self
		return {
			"target": entity,
			"should_execute": true,
			"action_type": "self",
			"message": "%s is confused and strikes themselves!" % entity.name
		}


## Helper to check allies for a given entity
static func get_allies_for_entity(entity: Entity, all_party: Array, all_enemies: Array) -> Array:
	"""Get all allies (excluding self) for the given entity"""
	if entity.role == Entity.Role.PARTY:
		return all_party.filter(func(e): return e != entity and e != null)
	else:
		return all_enemies.filter(func(e): return e != entity and e != null)


## Helper to check enemies for a given entity
static func get_enemies_for_entity(entity: Entity, all_party: Array, all_enemies: Array) -> Array:
	"""Get all enemies for the given entity"""
	if entity.role == Entity.Role.PARTY:
		return all_enemies.filter(func(e): return e != null)
	else:
		return all_party.filter(func(e): return e != null)

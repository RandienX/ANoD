extends Node
class_name BattleConditionEffectManager

var root: BattleEngine

func setup(broot: BattleEngine) -> void:
	root = broot

# ==============================================================================
# TARGETING LOGIC
# ==============================================================================
func resolve_targets(target_type: int, target_string: String) -> Array[Entity]:
	var targets: Array[Entity] = []
	
	match target_type:
		Effect.InBattleTargetType.ENEMY_SLOT:
			var slot_idx = int(target_string)
			var enemy = root.get_enemy(slot_idx)
			if enemy:
				targets.append(enemy)
				
		Effect.InBattleTargetType.PARTY_MEMBER_NAME:
			for p in root.party:
				if p.name == target_string:
					targets.append(p)
					break
					
		Effect.InBattleTargetType.SPECIFIC_ENEMY_NAME:
			for e in root.enemy_instances:
				if e.name == target_string:
					targets.append(e)
					break
					
		Effect.InBattleTargetType.RANDOM_ENEMY:
			var alive = root.get_alive_enemies()
			if not alive.is_empty():
				targets.append(alive[randi() % alive.size()])
				
		Effect.InBattleTargetType.ALL_ENEMIES:
			targets.assign(root.get_alive_enemies())
			
		Effect.InBattleTargetType.ALL_PARTY:
			for p in root.party:
				targets.append(p)
					
	return targets

# ==============================================================================
# CONDITION EVALUATION
# ==============================================================================
func evaluate_condition(condition: Condition, targets, context: Dictionary) -> bool:
	var result = false

	match condition.battle_condition_type:
		Condition.BattleConditionType.STAT_BELOW:
			for t in targets:
				if t.stats.has(condition.param_string) and t.stats[condition.param_string] < condition.param_value:
					result = true
					break
					
		Condition.BattleConditionType.STAT_BELOW_PERCENT:
			for t in targets:
				if t.stats.has(condition.param_string) and t.max_stats.has(condition.param_string) and t.max_stats[condition.param_string] > 0:
					var percent = (float(t.stats[condition.param_string]) / float(t.max_stats[condition.param_string])) * 100.0
					if percent < condition.param_value:
						result = true
						break
						
		Condition.BattleConditionType.ENTITY_ALIVE:
			for t in targets:
				if t.stats["hp"] > 0:
					result = true
					break
					
		Condition.BattleConditionType.ENTITY_EXISTS:
			for t in targets:
				if t:
					result = true
					break
					
		Condition.BattleConditionType.ON_TURN:
			if context.get("turn_number", 0) == int(condition.param_value):
				result = true
				
		Condition.BattleConditionType.AFTER_TIME_PASSED:
			if context.get("time_passed", 0.0) >= condition.param_value:
				result = true
				
		Condition.BattleConditionType.HAS_STATUS:
			for t in targets:
				if t.has_status(condition.param_string):
					result = true
					break
					
		Condition.BattleConditionType.ALL_ENEMIES_DEFEATED:
			if root.are_all_enemies_defeated():
				result = true
				
		Condition.BattleConditionType.SPECIFIC_ENEMY_DEFEATED:
			for e in targets:
				print(e.stats["hp"])
				if e.stats["hp"] <= 0:
					print(e.name)
					result = true
					break
					
		Condition.BattleConditionType.RANDOM_CHANCE:
			if randf_range(0, 100) < condition.param_value:
				result = true

	return result != condition.invert

# ==============================================================================
# EFFECT EXECUTION
# ==============================================================================
func execute_effect(effect: Effect, _source: Entity, context: Dictionary) -> void:
	var targets = resolve_targets(effect.battle_effect_target, effect.battle_target_string)
	for cond in effect.conditions:
		if not evaluate_condition(cond, targets, context):
			return
	
	effect.used_effect = true
	match effect.battle_effect_type:
		Effect.InBattleEffectType.START_DIALOGUE:
			if effect.param_string != "" and ResourceLoader.exists(effect.param_string):
				print(targets[0].name)
				DialogueInitiator.start_dialogue(load(effect.param_string), false, true)
				root.state = root.states.Waiting
				
		Effect.InBattleEffectType.TRIGGER_PHASE:
			if root.battle:
				root.battle.current_phase_index = int(effect.param_value)
				
		Effect.InBattleEffectType.ADD_SKILL:
			if effect.param_string != "" and ResourceLoader.exists(effect.param_string):
				var skill_res = load(effect.param_string)
				for t in targets:
					if not t.skills.has(1):
						t.skills[1] = []
					if not t.skills[1].has(skill_res):
						t.skills[1].merge({0: skill_res})
						
		Effect.InBattleEffectType.ADD_STAT:
			var stat_name = effect.param_string
			var amount = int(effect.param_value)
			for t in targets:
				if t.stats.has(stat_name):
					t.stats[stat_name] += amount
					t.invalidate_stat_cache()
					
		Effect.InBattleEffectType.ADD_STATUS:
			var effect_data: BattleEffect = load(effect.param_string)
			effect_data.target_type = effect_data.TargetType.SELF
			for t in targets:
				root.effect_manager.execute_effect(effect_data, t)
					
		Effect.InBattleEffectType.END_BATTLE_PREMATURELY:
			root.death_manager.end_battle_victory()
			
		Effect.InBattleEffectType.SPAWN_REINFORCEMENTS:
			if effect.param_string != "" and ResourceLoader.exists(effect.param_string):
				var new_battle_slot = BattleEnemySlot.new()
				new_battle_slot.enemy = load(effect.param_string)
				new_battle_slot.position_index = effect.param_value
				new_battle_slot.ui_position = effect.param_value2
				if new_battle_slot and new_battle_slot.enemy:
					root.setup_enemies() 
					
		Effect.InBattleEffectType.RESET_ENEMY_HEALTH:
			for t in targets:
				var old_hp = t.stats["hp"]
				t.stats["hp"] = t.max_stats["hp"]
				if old_hp != t.stats["hp"]:
					t.hp_changed.emit(old_hp, t.stats["hp"])

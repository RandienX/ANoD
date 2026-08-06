extends RefCounted
class_name EnemyManager

var root
var attack_executor
var effect_manager
var log_manager

enum Behavior { ATTACKER, DEFENDER, SUPPORT, BALANCED, FLEXIBLE }

var intelligence_presets := {
	"dumb": [0.2, 0.1],
	"normal": [0.4, 0.3],
	"smart": [0.66, 0.5],
	"intelligent": [0.8, 0.9]
}
var _target_memory: Dictionary = {} 

func setup(broot, atk_exec, eff_mgr, log_mgr):
	root = broot
	attack_executor = atk_exec
	effect_manager = eff_mgr
	log_manager = log_mgr
	
func queue_enemy_attack(e: Entity) -> void:
	if not e or e.stats["hp"] <= 0:
		return

	var move = _choose_move(e)
	if not move:
		return

	if move.has("skill") and move.skill:
		attack_executor.attack_array[e] = [move.targets, move.skill]
	elif move.has("item") and move.item:
		if randf() < 0.2:
			var s = preload("res://code/battle/skill.gd").new()
			s.skill_name = move.item.item_name
			s.target_type = 1
			s.is_item_skill = false
			attack_executor.attack_array[e] = [[e], s]
			return
			
		var item_attack = move.item.item_attack.duplicate() if move.item.item_attack else null
		if item_attack:
			attack_executor.attack_array[e] = [move.targets, item_attack]
		else:
			var s = preload("res://code/battle/skill.gd").new()
			s.skill_name = move.item.item_name
			s.is_item_skill = true
			s.target_type = 1
			attack_executor.attack_array[e] = [move.targets, s]
	else:
		var alive = root.party.filter(func(p): return p and p.stats["hp"] > 0)
		if alive.is_empty(): return
		
		# Pick target with lowest memory count for default attack
		var best_t = alive[0]
		var min_mem = 999
		for t in alive:
			var c = _get_target_memory_count(e, t)
			if c < min_mem:
				min_mem = c
				best_t = t
		attack_executor.attack_array[e] = [[best_t], e.default_attack]

	# Record the targeted party member in memory
	if attack_executor.attack_array.has(e):
		var targets = attack_executor.attack_array[e][0]
		if targets and targets.size() > 0:
			var t = targets[0]
			if t and t.role == Entity.Role.PARTY:
				_record_target(e, t)

func _choose_move(e: Entity):
	var candidates: Array = []
	
	# Skills
	var all_skills: Array = []
	for level_skills in e.skills.values():
		all_skills.append_array(level_skills)
	for s in all_skills:
		if not s: continue
		candidates.append({"type":"skill", "skill":s})

	# Items from enemy inventory
	if e.enemy_inventory:
		for it in e.enemy_inventory:
			if it:
				candidates.append({"type":"item", "item":it})

	candidates.append({"type":"skill", "skill":e.default_attack})

	var scored: Array = []
	var behavior = _get_behavior_for(e)
	var intel = _get_intelligence_for(e)
	var alive_party = root.party.filter(func(p): return p and p.stats["hp"] > 0)

	for c in candidates:
		var score = 0.0
		var preferred_targets: Array = []

		if c.type == "skill":
			var sk = c.skill
			var rep_t = null
			if sk and sk.has_method("can_use") and not sk.can_use(e):
				continue
				
			if sk.target_type == 0:
				var best_t = null
				var best_val = -INF
				
				var lowest_hp_t = null
				var min_hp = INF
				for t in alive_party:
					if t.stats["hp"] < min_hp:
						min_hp = t.stats["hp"]
						lowest_hp_t = t
						
				for t in alive_party:
					var dmg = 0.0
					if sk and sk.has_method("get_total_damage"):
						dmg = float(sk.get_total_damage(e, t))
					else:
						dmg = _estimate_skill_damage(sk, e, t)
						
					var val = float(dmg) 
					
					if t == lowest_hp_t:
						val *= 0.6 
						
					val *= randf_range(1.0 - _get_intelligence_for(e)[1], 1.0 + _get_intelligence_for(e)[1])
					
					var mem_count = _get_target_memory_count(e, t)
					if mem_count >= 2:
						val *= 0.1
					elif mem_count == 1:
						val *= 0.8
						
					if val > best_val:
						best_val = val
						best_t = t
						
				preferred_targets = [best_t] if best_t else []
				score = best_val
				rep_t = best_t
			elif sk.target_type in [3,2]:
				var total = 0.0
				for t in alive_party:
					if sk and sk.has_method("get_total_damage"):
						total += float(sk.get_total_damage(e, t))
					else:
						total += _estimate_skill_damage(sk, e, t)
				score = total
				preferred_targets = alive_party.duplicate()
				rep_t = alive_party[0]
			elif sk.target_type == 1:
				score = 0.5
				preferred_targets = [e]
				rep_t = e
			else:
				score = 0.1

			if sk.mana_cost > e.stats["mp"]:
				score *= 0.01

			if rep_t and sk.on_hit_effects and sk.on_hit_effects.size() > 0:
				for ef in sk.on_hit_effects:
					if ef and ef.has_method("get_scaled_value"):
						score += float(ef.get_scaled_value(e, rep_t)) * 0.2
			if sk.on_use_effects and sk.on_use_effects.size() > 0:
				for ef in sk.on_use_effects:
					if ef and ef.has_method("get_scaled_value"):
						score += float(ef.get_scaled_value(e, e)) * 0.1

		elif c.type == "item":
			var it = c.item
			var heal = it.heal_amount
			var mana = it.mana_amount
			var revive = it.revive_amount
			var is_attack = it.is_item_attack
			if is_attack and it.item_attack:
				var atk_skill = it.item_attack
				if atk_skill.target_type == 0:
					var best = 0.0
					var best_t_idx = 0
					for idx_t in range(alive_party.size()):
						var t = alive_party[idx_t]
						var d = 0.0
						if atk_skill and atk_skill.has_method("get_total_damage"):
							d = float(atk_skill.get_total_damage(e, t))
						else:
							d = _estimate_skill_damage(atk_skill, e, t)
						if d > best:
							best = d
							best_t_idx = idx_t
					score = best
					preferred_targets = [alive_party[best_t_idx]]
				else:
					score = heal + 0.1
			else:
				if behavior == Behavior.SUPPORT or (behavior == Behavior.DEFENDER and e.prefer_defend):
					score = float(heal) + float(mana) * 0.5 + float(revive) * 5.0
					var allies = root.enemy_instances.filter(func(x): return x and x.stats["hp"] > 0)
					allies.sort_custom(Callable(self, "_sort_by_lowest_hp"))
					preferred_targets = [allies[0]] if not allies.is_empty() else [e]
					score = score * pow(preferred_targets[0].stats["hp"] / (preferred_targets[0].stats["hp"] + preferred_targets[0].max_stats["hp"]), 2)
				
				if behavior == Behavior.ATTACKER:
					score = sqrt(float(heal) * 0.33 + float(mana))
					preferred_targets = [e]
					score = score * pow(preferred_targets[0].stats["hp"] / (preferred_targets[0].stats["hp"] + preferred_targets[0].max_stats["hp"]), 4)
				
		var aggression = float(e.aggression)
		var prefer_defend = bool(e.prefer_defend)
		if behavior == Behavior.ATTACKER:
			if (c.type == "skill" and c.skill.target_type in [0,3,5]) or (c.type == "item" and c.item.item_attack):
				score *= 1.0 + aggression * 0.5
		elif behavior == Behavior.DEFENDER:
			if c.type == "item" and score > 0:
				score *= 1.3
			else:
				score *= 0.8
		elif behavior == Behavior.SUPPORT:
			if c.type == "item" and score > 0:
				score *= 1.6
			elif c.type == "skill" and c.skill.target_type in [1,2]:
				score *= 1.4
			else:
				score *= 0.6
		elif behavior == Behavior.BALANCED:
			score *= 1.0
		elif behavior == Behavior.FLEXIBLE:
			score *= 1.1

		if prefer_defend and c.type == "item":
			score *= 1.2

		score *= randf_range(1.0 - _get_intelligence_for(e)[1], 1.0 + _get_intelligence_for(e)[1])

		score = max(0.0, score)
		scored.append({"cand":c, "score":score, "targets":preferred_targets})

	var total_score = 0.0
	for s in scored:
		total_score += s.score
		
	if total_score <= 0.0:
		var alive = root.party.filter(func(p): return p and p.stats["hp"] > 0)
		if alive.is_empty():
			return {"skill":e.default_attack, "targets":[]}
			
		var best_t = alive[0]
		var min_mem = 999
		for t in alive:
			var c = _get_target_memory_count(e, t)
			if c < min_mem:
				min_mem = c
				best_t = t
		return {"skill":e.default_attack, "targets":[best_t]}

	scored.sort_custom(Callable(self, "_sort_by_score_desc"))

	var keep_frac = intel[0]
	var full_random_chance = clamp(1.0 - intel[0], 0.0, 1.0)
	var use_full_pool = randf() < full_random_chance
	var temperature = _get_temperature_for(intel[0])
	var pool: Array = []
	if use_full_pool:
		pool = scored
	else:
		var keep_count = max(1, int(ceil(scored.size() * keep_frac)))
		pool = scored.slice(0, keep_count)

	var sumw = 0.0
	for p in pool:
		var weight = pow(max(p.score, 0.01), 1.0 / temperature)
		p.weight = weight
		sumw += weight
	var pick = randf() * sumw
	var accum = 0.0
	for p in pool:
		accum += p.weight
		if pick <= accum:
			var chosen = p.cand
			var out: Dictionary = {}
			if chosen.type == "skill":
				out.skill = chosen.skill
				out.targets = p.targets if p.targets.size() > 0 else [root.party[randi_range(0, root.party.size()-1)]]
			elif chosen.type == "item":
				out.item = chosen.item
				out.targets = p.targets if p.targets.size() > 0 else [root.party[randi_range(0, root.party.size()-1)]]
			return out

	return null

func _get_memory_max_len(e: Entity) -> int:
	return 3 if _is_intelligent(e) else 5

func _record_target(e: Entity, target: Entity) -> void:
	if not target or target.role != Entity.Role.PARTY: return
	var key = _get_entity_key(e)
	if not _target_memory.has(key):
		_target_memory[key] = []
	var mem = _target_memory[key]
	mem.append(target)
	var max_len = _get_memory_max_len(e)
	while mem.size() > max_len:
		mem.pop_front()
	_target_memory[key] = mem

func _get_target_memory_count(e: Entity, target: Entity) -> int:
	var key = _get_entity_key(e)
	if not _target_memory.has(key): return 0
	var mem = _target_memory[key]
	var count = 0
	for t in mem:
		if t == target:
			count += 1
	return count

func _get_behavior_for(e: Entity) -> int:
	# Prefer explicit ai_behavior on Entity (enum AIBehavior)
	if Engine.is_editor_hint() == false:
		# runtime path: assume field exists
		if e and e.has_method("get"):
			# try to read exported ai_behavior
			if e and e.get("ai_behavior") != null:
				return int(e.ai_behavior)
	# Fallback: Balanced
	return Behavior.BALANCED

func _get_intelligence_for(e: Entity) -> Array:
	# Use exported ai_intelligence (AIIntelligencePreset) when available
	if e and e.has_method("get") and e.get("ai_intelligence") != null:
		match int(e.ai_intelligence):
			0: return intelligence_presets["dumb"]
			1: return intelligence_presets["normal"]
			2: return intelligence_presets["smart"]
			3: return intelligence_presets["intelligent"]
	# Default
	return intelligence_presets["normal"]

func _estimate_skill_damage(sk: Resource, attacker: Entity, target: Entity) -> float:
	# Simplified damage estimate for choice heuristics
	var atk_stat = attacker.stats["atk"]
	var def_stat = target.stats["def"]
	var mult = sk.attack_multiplier if sk.attack_multiplier != null else 1.0
	var hit_mult = sk.hit_damage_multiplier if sk.hit_damage_multiplier != null else 1.0
	var hits = max(1, sk.hit_count if sk.hit_count != null else 1)
	var base = float(atk_stat) * mult * hit_mult * hits
	var def_mult = 1.0 - (float(def_stat) / max(1.0, 100.0 + float(def_stat)))
	return max(0.0, base * def_mult)

func _sort_by_score_desc(a, b):
	return int(sign(b.score - a.score))

func _sort_by_lowest_hp(a, b):
	return int(sign(a.stats["hp"] - b.stats["hp"]))

func _get_entity_key(e: Entity) -> String:
	return str(e.get_instance_id())

func _is_intelligent(e: Entity) -> bool:
	if e and e.has_method("get") and e.get("ai_intelligence") != null:
		return int(e.ai_intelligence) >= 2
	return false

func _get_temperature_for(intel: float) -> float:
	return clamp(1.0 + (1.0 - intel) * 1.5, 0.5, 2.5)

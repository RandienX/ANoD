extends RefCounted
class_name EnemyManager

var root
var attack_executor
var effect_manager
var log_manager

enum Behavior { ATTACKER, DEFENDER, SUPPORT, BALANCED, FLEXIBLE }

var intelligence_presets := {
	"dumb": 0.2,
	"normal": 0.5,
	"smart": 0.75,
	"intelligent": 0.9
}

func setup(broot, atk_exec, eff_mgr, log_mgr):
	root = broot
	attack_executor = atk_exec
	effect_manager = eff_mgr
	log_manager = log_mgr

func queue_enemy_attack(e: Entity) -> void:
	if not e or e.hp <= 0:
		return

	var move = _choose_move(e)
	if not move:
		return

	if move.has("skill") and move.skill:
		attack_executor.attack_array[e] = [move.targets, move.skill]
	elif move.has("item") and move.item:
		# convert item to an item-skill if necessary
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
		# fallback default attack on a random alive party member
		var alive = root.party.filter(func(p): return p and p.hp > 0)
		if alive.empty(): return
		attack_executor.attack_array[e] = [[alive[randi_range(0, alive.size()-1)]], e.default_attack]

func _choose_move(e: Entity):
	# Build list of candidate moves (skills + item-attacks + default)
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

	# Always include default attack as low-priority candidate
	candidates.append({"type":"skill", "skill":e.default_attack})

	# Score each candidate based on behavior & intelligence
	var scored: Array = []
	var behavior = _get_behavior_for(e)
	var intel = _get_intelligence_for(e)

	var alive_party = root.party.filter(func(p): return p and p.hp > 0)

	for c in candidates:
		var score = 0.0
		var preferred_targets: Array = []

		if c.type == "skill":
			var sk = c.skill
			var rep_t = null
			# respect usage requirements (mana, hp, weapon, etc.)
			if sk and sk.has_method("can_use") and not sk.can_use(e):
				# barely consider unusable skills
				continue
			# estimate on-hit damage per target
			if sk.target_type == 0:
				# single target: pick best victim by damage percent
				var best_t = null
				var best_val = -INF
				for t in alive_party:
					var dmg = 0.0
					if sk and sk.has_method("get_total_damage"):
						dmg = float(sk.get_total_damage(e, t))
					else:
						dmg = _estimate_skill_damage(sk, e, t)
					var val = float(dmg) / max(1, t.hp)
					if val > best_val:
						best_val = val
						best_t = t
				preferred_targets = [best_t]
				score = best_val
				rep_t = best_t
			elif sk.target_type in [3,2]:
				# multi-target: use sum damage
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
				# self
				score = 0.5
				preferred_targets = [e]
				rep_t = e
			else:
				score = 0.1

			# penalize if too expensive / unusable for current mp or conditions
			if sk.mana_cost > e.mp:
				score *= 0.2

			# consider on-hit / on-use effects (buffs, heals, status)
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
			# Basic heuristics using Item fields
			var heal = it.heal_amount if it.has("heal_amount") else it.heal_amount
			var mana = it.mana_amount if it.has("mana_amount") else it.mana_amount
			var revive = it.revive_amount if it.has("revive_amount") else it.revive_amount
			var is_attack = it.is_item_attack if it.has("is_item_attack") else it.is_item_attack
			if is_attack and it.item_attack:
				var atk_skill = it.item_attack
				# evaluate as a skill
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
				# non-attack items: healing/utility value
				score = float(heal) + float(mana) * 0.5 + float(revive) * 5.0
				# SUPPORT/DEFENDER prefer healing allies
				if behavior == Behavior.SUPPORT or behavior == Behavior.DEFENDER or e.prefer_defend:
					var allies = root.enemy_instances.filter(func(x): return x and x.hp > 0)
					allies.sort_custom(Callable(self, "_sort_by_lowest_hp"))
					preferred_targets = [allies[0]] if not allies.empty() else [e]

		# Behavior adjustments and entity-specific modifiers
		var aggression = float(e.aggression)
		var prefer_defend = bool(e.prefer_defend)
		if behavior == Behavior.ATTACKER:
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

		# entity-specific prefer_defend tweak
		if prefer_defend and c.type == "item":
			score *= 1.2

		# clamp
		score = max(0.0, score)
		scored.append({"cand":c, "score":score, "targets":preferred_targets})

	# If all scores zero, fallback to default attack
	var total_score = 0.0
	for s in scored:
		total_score += s.score
	if total_score <= 0.0:
		return {"skill":e.default_attack, "targets":[root.party[randi_range(0, root.party.size()-1)]]}

	# Sort and apply intelligence filter (drop worst X%)
	scored.sort_custom(Callable(self, "_sort_by_score_desc"))
	var keep_frac = intel
	var keep_count = max(1, int(ceil(scored.size() * keep_frac)))
	var pool = scored.slice(0, keep_count)

	# Weighted random from pool
	var sumw = 0.0
	for p in pool:
		sumw += p.score
	var pick = randf() * sumw
	var accum = 0.0
	for p in pool:
		accum += p.score
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

func _get_intelligence_for(e: Entity) -> float:
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
	var atk_stat = attacker.get_base_stat(&"atk")
	var def_stat = target.get_base_stat(&"def")
	var mult = sk.attack_multiplier if sk.attack_multiplier != null else 1.0
	var hit_mult = sk.hit_damage_multiplier if sk.hit_damage_multiplier != null else 1.0
	var hits = max(1, sk.hit_count if sk.hit_count != null else 1)
	var base = float(atk_stat) * mult * hit_mult * hits
	var def_mult = 1.0 - (float(def_stat) / max(1.0, 100.0 + float(def_stat)))
	return max(0.0, base * def_mult)

func _sort_by_score_desc(a, b):
	return int(sign(b.score - a.score))

func _sort_by_lowest_hp(a, b):
	return int(sign(a.hp - b.hp))

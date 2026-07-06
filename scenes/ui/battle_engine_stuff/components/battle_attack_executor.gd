extends Node
class_name AttackExecutor

var root
var root_nodepath
var death_manager
var effect_manager
var log_manager
var battle

var attack_array: Dictionary = {}

func setup(broot, d_mgr, e_mgr, l_mgr, batt):
	root = broot
	root_nodepath = root.get_path()
	death_manager = d_mgr
	effect_manager = e_mgr
	log_manager = l_mgr
	battle = batt

func do_attacks() -> void:
	if death_manager.game_over_active: return
	for actor in root.initiative:
		if attack_array.has(actor) and root:
			root.current_attacker = actor
			await execute_single_attack(actor)
			await death_manager.check_enemy_death_and_xp()
	if root:
		root.start_round()

# ──────────────────────────────────────────────────────────────────────────────
# Main Entry Point
# ──────────────────────────────────────────────────────────────────────────────

func execute_single_attack(attacker: Object) -> void:
	if death_manager.game_over_active: 
		return
	var targets: Array = attack_array[attacker][0]
	var atk: Skill = attack_array[attacker][1]
		
	# Step 1: Filter alive targets
	var alive: Array = _get_alive_targets(targets)
	
	# Step 2: Handle Check skill (special case)
	if atk.skill_name == "Check":
		await _handle_check_skill(attacker, targets)
		return
	
	# Step 3: Ensure valid target for single-target attacks
	if alive.is_empty() and atk.target_type == 0:
		if not _assign_random_target(attacker, atk):
			return
		alive = _get_alive_targets(attack_array[attacker][0])
		if alive.is_empty():
			return
	
	# Step 4: Route to appropriate handler based on attack type
	await _route_attack_execution(attacker, targets, atk)

# ──────────────────────────────────────────────────────────────────────────────
# Attack Routing Logic
# ──────────────────────────────────────────────────────────────────────────────

func _route_attack_execution(attacker: Object, alive: Array, atk: Skill) -> void:
	"""Unified skill execution with comprehensive customization support."""
	if death_manager.game_over_active: 
		return
	
	var targets: Array = attack_array[attacker][0]
	# Step 1: Apply on_use effects
	_apply_on_use_effects(attacker, alive, atk)
	
	# Step 2: Check if this is an item-based skill
	if atk.is_item_skill:
		await _handle_item_usage(attacker, targets, atk)
	
	# Step 3: Handle non-damaging skills (buffs/debuffs without targeting enemies)
	if atk.target_type in [1, 2]:  # Self or Party
		await _handle_support_skill(attacker, alive, atk)
		return
	
	# Step 4: Execute attack logic (single or multi-hit)
	await _execute_attack_sequence(attacker, alive, atk)

# ──────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ──────────────────────────────────────────────────────────────────────────────

func _get_alive_targets(targets: Array) -> Array:
	var alive: Array = []
	for t in targets:
		if t is Entity:
			if t.stats["hp"] > 0:
				alive.append(t)
	return alive

func _handle_check_skill(_attacker: Entity, targets: Array) -> void:
	if death_manager.game_over_active: return
	if targets.size() > 0 and targets[0].role == Entity.Role.ENEMY:
		var target_enemy: Entity = targets[0] as Entity
		var dialogue = DialogueData.new()
		var dialogue_node = DialogueNode.new()
		dialogue_node.label = "start"
		dialogue_node.text = "%s   HP: %d/%d \n%s" % [target_enemy.name, target_enemy.stats["hp"], target_enemy.max_stats["hp"], target_enemy.description]
		dialogue.nodes = [dialogue_node as DialogueNode] as Array[DialogueNode]
		DialogueInitiator.start_dialogue(dialogue, false, true)
		root.state = root.states.Waiting
	await root.get_tree().create_timer(2.5).timeout

func _assign_random_target(attacker: Entity, _atk: Skill) -> bool:
	# For enemies, target party members; for party members, target enemies
	var valid_targets: Array = []
	if attacker.role == Entity.Role.ENEMY:
		valid_targets = root.party.filter(func(p): return p and p.stats["hp"] > 0)
	else:
		valid_targets = root.get_alive_enemies()
	
	if not valid_targets.is_empty():
		var new_target = [valid_targets[randi_range(0, valid_targets.size()-1)]]
		attack_array[attacker][0] = new_target
		return true
	return false

func _handle_item_usage(attacker: Entity, targets: Array, _atk: Skill) -> void:
	if death_manager.game_over_active: return
	var used_item = root.item_manager.item_ref
	var target = targets[0]
	if used_item:
		var item_log = ""
		item_log += "[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + used_item.item_name + "[/color] on [color=#FF5722]" + target.name + "[/color] "
		
		if used_item.revive_amount > 0 and target.stats["hp"] <= 0:
			target.stats["hp"] = used_item.revive_amount
			target.hp_changed.emit(0, target.stats["hp"])
			# Ensure they are added back to the active initiative if they were removed
			if not root.initiative.has(target):
				root.initiative.append(target)
				root.party_initiative_order.pop_at(root.party_initiative_order.find(target))
				root.party_initiative_order.append(target)
			
			item_log += " [color=#4CAF50]Revived with " + str(used_item.revive_amount) + " HP![/color] "
		
		# 2. HEAL (Target is alive)
		if used_item.heal_amount > 0 and target.stats["hp"] > 0:
			var actual_heal = target.heal_hp(used_item.heal_amount)
			item_log += " [color=#4CAF50](+ " + str(actual_heal) + " HP)[/color] "
		
		# 3. MANA
		if used_item.mana_amount > 0:
			target.stats["mp"] = min(target.max_stats["mp"], target.stats["mp"] + used_item.mana_amount)
			item_log += " [color=#2196F3](+ " + str(used_item.mana_amount) + " MP)[/color] "
			
			log_manager.add_to_battle_log(item_log)
		
		# 4. CONSUME EFFECTS (Buffs/Debuffs applied AFTER revival so they aren't skipped)
		if not used_item.consume_effects.is_empty():
			for effect in used_item.consume_effects:
				root.effect_manager.execute_effect(effect, attacker)
	
	else:
		log_manager.add_to_battle_log("[color=#F44336]Item use failed![/color]")
		
		await root.get_tree().create_timer(1.25 / Settings.battle_speed).timeout

# ──────────────────────────────────────────────────────────────────────────────
# New Unified Attack Execution System
# ──────────────────────────────────────────────────────────────────────────────

func _apply_on_use_effects(attacker: Object, targets: Array, atk: Skill) -> void:
	"""Apply effects that trigger on skill use (before attack lands) via BattleEffectManager."""
	if not atk.on_use_effects.is_empty():
		for effect in atk.on_use_effects:
			effect_manager.execute_effect(effect, attacker, {"selected_enemy": targets[0] if targets.size() > 0 else null})

func _handle_support_skill(attacker: Entity, _alive: Array, atk: Skill) -> void:
	if death_manager.game_over_active: return
	"""Handle buffs/debuffs and other non-damaging skills via BattleEffectManager."""
	var support_log = ""

	if atk.target_type == 1:  # Self
		# Execute on_use effects already handled, now apply on_hit effects for self-buffs
		for effect in atk.on_hit_effects:
			effect_manager.execute_effect(effect, attacker, {}, 0.0)
		support_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.skill_name + "[/color] on self"
	elif atk.target_type == 2:  # Party
		support_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.skill_name + "[/color] on party"
		for p in root.party:
			if p.stats["hp"] > 0:
				for effect in atk.on_hit_effects:
					effect_manager.execute_effect(effect, attacker, {}, 0.0)
	
	if atk.mana_cost > 0:
		support_log += " [color=#9C27B0](" + str(atk.mana_cost) + " MP)[/color]"
	
	if atk.sfx:
		Sfx.stream = atk.sfx
		Sfx.play()
	
	log_manager.add_to_battle_log(support_log)
	attacker.stats["mp"] = max(0, attacker.stats["mp"] - atk.mana_cost)
	
	if atk.sfx:
		await Sfx.finished

func _execute_attack_sequence(attacker: Entity, alive: Array, atk: Skill) -> void:
	if death_manager.game_over_active: return
	"""Unified attack execution handling both single and multi-hit attacks."""
	if alive.is_empty():
		return
		
	var attack_log = ""
	var play_animation_once = alive.size() > 1
	var animation_played = false
	
	if atk.mana_cost > 0:
		attacker.stats["mp"] = max(0, attacker.stats["mp"] - atk.mana_cost)
		
	if atk.sfx:
		Sfx.stream = atk.sfx
		Sfx.play()
	
	var hit_count = max(1, atk.hit_count)
	var total_dmg = 0
	var total_crits = 0
	var total_misses = 0
	var target: Entity
	var target_names: String = ""
	for e in range(len(alive)):
		target = alive[e]
		if e == 0:
			target_names += target.name
		else:
			target_names += ", " + target.name
			
	for i in range(hit_count):
		for e in range(len(alive)):
			target = alive[e]
			await root.get_tree().create_timer(0.15 / Settings.battle_speed).timeout
			# Step 1: Calculate accuracy and determine hit/miss
			var hit_result = _calculate_hit(attacker, target, atk)
			var dmg = hit_result.dmg
			var crit = hit_result.crit
			var hit = hit_result.hit
			var play_animation = true
			if play_animation_once:
				play_animation = not animation_played
			
			# Step 2: Check for instakill
			if target.has_status("instakill"):
				target.stats["hp"] = 0
				attack_log += "\n[color=#FF0000]Hit " + str(i+1) + ": ★★★ INSTAKILL ★★★[/color]"
				if target.role == Entity.Role.ENEMY:
					await death_manager.animate_enemy_death(target)
				log_manager.add_to_battle_log(attack_log)
				await root.get_tree().create_timer(0.5 / Settings.battle_speed).timeout
				return
			
			# Step 3: Process hit or miss
			if hit:
				await _process_hit(attacker, target, atk, dmg, crit, attack_log, play_animation)
				Sfx2.stream = atk.hit_sound
				Sfx2.play()
				if play_animation:
					animation_played = true
				total_dmg += dmg
				if crit:
					total_crits += 1
			else:
				_process_miss(attacker, target, atk, attack_log, i)
				Sfx2.stream = atk.miss_sound
				Sfx2.play()
				total_misses += 1
		
		if root:
			await root.get_tree().create_timer(1.0 / Settings.battle_speed).timeout
		
		# Step 4: Check for death (enemy)
		if target.stats["hp"] <= 0:
			if target.role == Entity.Role.ENEMY:
				await root.death_manager.animate_enemy_death(target)
						
	# Step 5: Log final results
	attack_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.skill_name + "[/color] on [color=#FF5722]" + target_names + "[/color]"
	attack_log += "\n[color=#03A9F4]Total: " + str(total_dmg) + " DMG | "
	attack_log += str(hit_count - total_misses) + "/" + str(hit_count) + " hits"
	if total_crits > 0:
		attack_log += " | " + str(total_crits) + " CRITs"
	if atk.mana_cost > 0:
		attack_log += " | " + str(atk.mana_cost) + " MP"
	attack_log += "[/color]"
	log_manager.add_to_battle_log(attack_log)
	
	# Step 6: Die
	_cleanup_deaths(attacker, alive)
		

@warning_ignore("unused_parameter")
func _process_hit(attacker: Entity, target: Entity, atk: Skill, dmg: int, _crit: bool, attack_log: String, play_animation: bool = true) -> void:
	if !root: return
	"""Process a successful hit: apply damage, effects, and wake from sleep via BattleEffectManager."""

	if play_animation and root.get_node("AnimationPlayer"):
		root.get_node("AnimationPlayer").play("move_around_screen")
		await root.get_node("AnimationPlayer").animation_finished
	target.stats["hp"] -= dmg

	# Apply on-hit effects via BattleEffectManager
	for effect in atk.on_hit_effects:
		effect_manager.execute_effect(effect, attacker, {"selected_enemy": target})

	# Check for sleep wake using new status API
	var sleep_stacks = target.get_status_stacks("sleep_debuff")
	if sleep_stacks > 0:
		if sleep_stacks < 1: sleep_stacks = 1
		if randf() < (1.0 - (0.1 * float(sleep_stacks))):
			target.remove_status("sleep_debuff")
			attack_log += "\n[color=#FFD700]" + target.name + " woke up![/color]"
	
	# Update enemy UI
	for i in range(5):
		var e = root.enemies_by_slot[i]
		if e and e.stats["hp"] > 0:
			var node = get_node_or_null("Control/enemy_ui/enemies/enemy"+str(i+1))
			if node:
				node.stats["hp"] = max(0, e.hp)

func _process_miss(attacker: Entity, target: Entity, atk: Skill, _attack_log: String, _hit_index: int) -> void:
	if death_manager.game_over_active: return
	"""Process a missed attack: apply on-miss effects via BattleEffectManager."""
	# Apply on-miss effects if any
	if not atk.on_miss_effects.is_empty():
		for effect in atk.on_miss_effects:
			effect_manager.execute_effect(effect, attacker, {"selected_enemy": target})

func _cleanup_deaths(_attacker: Entity, alive: Array) -> void:
	if death_manager.game_over_active: return
	for t in alive:
		if t.stats["hp"] <= 0:
			death_manager.death(t)
			await root.get_tree().create_timer(0.15 / Settings.battle_speed).timeout

# ──────────────────────────────────────────────────────────────────────────────
# Combat Calculation Helpers
# ──────────────────────────────────────────────────────────────────────────────

func _calculate_hit(attacker: Entity, target: Entity, atk: Skill) -> Dictionary:
	var crit = randi_range(1, 10 if attacker.role == Entity.Role.ENEMY else 8) == 1
	var atk_stat = attacker.get_effective_stat("atk")
	var base = atk_stat * atk.attack_multiplier * atk.hit_damage_multiplier
	
	base *= randf_range(0.86 if attacker.role == Entity.Role.ENEMY else 0.9, 1.16 if attacker.role == Entity.Role.ENEMY else 1.2)
	if crit:
		base *= 1.75
	base += atk.attack_bonus
	
	var def_stat = target.get_effective_stat("def")
	
	# Check for Defend status
	var defend_mult = 2.0 if target.has_status("defend") else 1.0
	var def_mult = clampf(def_stat, 0.01, 0.99)
	def_mult /= defend_mult
	def_mult = clampf(def_mult, 0.0, 1.0)
	
	var dmg = max(1, floor(base * def_mult))
	
	# Accuracy multipliers from statuses
	var focus_mult = _get_status_multiplier(attacker, "focus", 0.15)
	var blind_mult = _get_status_multiplier(target, "blind", -0.5)
	var hit = randf() <= (atk.accuracy * focus_mult * blind_mult)
	
	return {
			"dmg": dmg,
			"crit": crit,
			"hit": hit
	}

func _get_status_multiplier(entity: Entity, status_id: String, per_stack_value: float, flat: bool = false) -> float:
	"""Get multiplier from a status effect. If flat=true, returns additive value instead."""
	if not entity.has_status(status_id):
		return 1.0 if not flat else 0.0
	var stacks = entity.get_status_stacks(status_id)
	if flat:
		return per_stack_value * stacks
	else:
		return 1.0 + (float(stacks) * per_stack_value)

extends Node
class_name DeathManager

var root
var battle
var condition_manager

func setup(broot, rbattle, c_mgr):
	root = broot
	battle = rbattle
	condition_manager = c_mgr

# === DEATH & VICTORY LOGIC ===

var is_animating_death: bool = false

var game_over_active: bool = false
var game_over_overlay: ColorRect
var game_over_texture: TextureRect
var can_reload = false
	
func add_defeated_enemies():
	for slot in root.battle.enemies:
		if slot and slot.enemy:
			Global.enemies_killed.merge({slot.enemy.name: Global.enemies_killed[slot.enemy.name] + 1 if Global.enemies_killed.keys().has(slot.enemy.name) else 1}, true)
	Global.battles_won.merge({root.battle.battle_name: Global.battles_won[root.battle.battle_name] + 1 if Global.battles_won.keys().has(root.battle.battle_name) else 1}, true)
	
var victory = false
func check_enemy_death_and_xp():
	if root:
		if not root.are_all_enemies_defeated():
			return
	else:
		return
	
	if victory:
		return
	
	victory = true
	var total_xp = 0        
	var total_currency = 0
	
	await add_defeated_enemies()
	
	# Calculate XP and currency rewards from all enemy slots (using override values if set.
	for slot in root.battle.enemies:
		if slot and slot.enemy:
			total_xp += slot.get_xp_reward()
			total_currency += slot.get_currency_reward()
	
	Sfx.stream = load("res://assets/sound/sfx/battle_win.mp3")
	Sfx.play()
	if battle:
		total_currency += battle.currency_reward
	
	for actor in root.party:
		actor.xp += total_xp
		if root:
			root.get_node("Control/enemy_ui/CenterContainer/output").text = actor.name + " gained " + str(total_xp) + " XP! "
		while actor.xp >= actor.xp_to_level_up:
			actor.xp -= actor.xp_to_level_up
			actor.level += 1
			actor.recalculate_level_stats()
			actor.xp_to_level_up = ceil(actor.xp_to_level_up * actor.level_up_xp_multiplier)
			actor.stats["hp"] = actor.max_stats["hp"]
			actor.stats["mp"] = actor.max_stats["mp"]
			if root:
				root.get_node("Control/enemy_ui/CenterContainer/output").visible = true
				root.get_node("Control/enemy_ui/CenterContainer/output").text = actor.name + " leveled up to " + str(actor.level) + "! "
		await Global.get_tree().create_timer(1.0).timeout
				
	# Add currency reward to player
	if total_currency > 0:
		PlayerStats.add_currency(total_currency, PlayerStats.CurrencyType.GOLD)
		if root:
			root.get_node("Control/enemy_ui/CenterContainer/output").text += "Gained " + str(total_currency) + " gold!"
		
	end_battle_victory()

func end_battle_victory() -> void:
	if game_over_active:
		return
	game_over_active = true #not game_over but still stop functions
	Global.battle_bg = null
	Global.process_frame()
	Global.loading = true
	Global.get_tree().change_scene_to_file(Global.current_scene)
	Global.loading = false

func animate_enemy_death(e: Entity) -> void:
	if is_animating_death: return
	is_animating_death = true
	var slot = root.get_enemy_index(e)
	if slot < 0:
		is_animating_death = false
		return
		
	var enemies_node = root.get_node_or_null("Control/enemy_ui/enemies")
	if not enemies_node:
		is_animating_death = false
		return
		
	var slots = enemies_node.get_children()
	if slot >= slots.size():
		is_animating_death = false
		return
		
	var node = slots[slot]
	var orig = node.global_position
	
	for i in range(20):
		_set_shader(node, "flash_intensity", float(i)/20.0)
		await root.get_tree().create_timer(0.05).timeout
		
	var jitter = 3.0
	for i in range(30):
		node.global_position.y = orig.y + i*2
		node.global_position.x = orig.x + randf_range(-jitter, jitter)
		jitter *= 0.95
		await root.get_tree().create_timer(0.03).timeout
		
	for i in range(20):
		_set_shader(node, "opacity", 1.0 - float(i)/20.0)
		await root.get_tree().create_timer(0.05).timeout
		
	node.visible = false
	node.global_position = orig 
	
	_set_shader(node, "flash_intensity", 0.0)
	_set_shader(node, "opacity", 1.0)
	
	move_flash_to_next_enemy(slot)
	is_animating_death = false

func _set_shader(node: Node, param: String, value: Variant):
	if node is CanvasItem:
		node.set_instance_shader_parameter(param, value)
	for child in node.get_children():
		if child is CanvasItem:
			child.set_instance_shader_parameter(param, value)

func move_flash_to_next_enemy(slot: int):
	for i in range(1, 5):
		var next_slot = wrapi(slot + i, 0, 5)
		var enemy_at_slot = root.get_enemy(next_slot)
		if enemy_at_slot and enemy_at_slot.stats["hp"] > 0:
			root.selected_enemy = next_slot
			return
	root.selected_enemy = -1

func death(obj: Entity):
	for i in range(root.initiative.size()-1, -1, -1):
		if root.initiative[i] == obj:
			root.initiative.remove_at(i)
			if root.attack_executor.attack_array.has(obj): root.attack_executor.attack_array.erase(obj)
			if obj.role == Entity.Role.PARTY and root.planning_phase and root.action_history.has(obj):

				root.action_history.erase(obj)
				root.current_party_plan_index -= 1
	if obj.role == Entity.Role.PARTY:
		check_party_wipe()

var locked = false
var alive = true
func check_party_wipe() -> void:
	alive = false
	for p in root.party:
		if p.stats["hp"] > 0 and not locked:
			alive = true
			break
	if not alive and not locked:
		if len(battle.on_defeat_effects) != 0:
			for e in battle.on_defeat_effects:
				locked = true
				if e.is_battle_effect:
					var context = {
						"turn_number": root.turn_number, 
						"time_passed": root.time_passed
					}
					condition_manager.execute_effect(e, root.party[0], context)
				else:
					e.execute()
		else:
			trigger_game_over()

func trigger_game_over() -> void:
	game_over_active = true
	root.state = root.states.Waiting
	root.get_node("WhoMoves").visible = false
	
	var gitgud = preload("res://scenes/ui/game_over.tscn").instantiate()
	gitgud.z_index = 999
	root.add_child(gitgud)
	BackgroundMusic.playing = false
	Sfx.playing = false
	Sfx2.playing = false
	BackgroundMusic.stream = load("res://assets/sound/sfx/death.wav")
	BackgroundMusic.play()
	gitgud.get_node("AnimationPlayer").play("gitgud")
	
	await root.get_tree().create_timer(1.5).timeout
	can_reload = true

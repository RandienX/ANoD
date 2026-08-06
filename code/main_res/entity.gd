@tool
extends Resource
class_name Entity

## Unified Entity resource with robust stat tracking, status/modifier system,
## and outside-battle persistence support. Decoupled from battle resolution.

# ==================== ENUMS ====================

enum Role { PARTY, ENEMY }
enum AIBehavior { ATTACKER, DEFENDER, SUPPORT, BALANCED, FLEXIBLE }
enum AIIntelligencePreset { DUMB, NORMAL, SMART, INTELLIGENT }

# ==================== BASIC INFO ====================

@export_category("Basic Info")
@export var name: String = ""
@export_multiline var description: String = ""
@export var role: Role = Role.PARTY
@export var portrait: Texture2D
@export var portrait_rect := Rect2()
@export var sprite: SpriteFrames
@export var path_to: String = ""

# ==================== BASE STATS ====================

@export_category("Base Stats")
## Base stats at level 1
@export var base_stats: Dictionary[String, int] = {
	"hp": 100,
	"mp": 50,
	"tp": 100,
	"atk": 10,
	"def": 5,
	"speed": 10,
	"magic": 10,
	"magic_def": 5,
}

## Maximum possible stats (cap)
@export var max_stat_caps: Dictionary[String, int] = {
	"hp": 9999,
	"mp": 9999,
	"tp": 999,
	"atk": 999,
	"def": 999,
	"speed": 999,
	"magic": 999,
	"magic_def": 999
}

## Stat gains per level
@export var level_up_gains: Dictionary[String, float] = {
	"hp": 1.5,
	"mp": 1.5,
	"tp": 1.1,
	"atk": 1.2,
	"def": 1.1,
	"speed": 1.1,
	"magic": 1.2,
	"magic_def": 1.1
}

#==================== CURRENT STATE (LEVEL + EQUIPMENT) ====================
@export_group("Current State")
# The ACTUAL current stats for this level (Base + Level Gains + Equipment).
# This is what battle calculations and UI will read from.
@export var stats: Dictionary[String, int] = {}

# The max allowed values for this level (Base Caps + Level Gains).
# Does NOT include equipment or modifiers, as requested.
@export var max_stats: Dictionary[String, int] = {}
@export var level: int = 1
@export var xp: int = 0
@export var xp_to_level_up: int = 100
@export var level_up_xp_multiplier: float = 1.5
@export var cannot_use_skills: bool

# Combat state flags (runtime only, not serialized)
@export var skip_turn: bool = false
@export var extra_turn: bool = false
@export var is_defending: bool = false

# ==================== STAT MODIFIERS ====================

## Active stat modifiers: { modifier_id: StatModifierInstance }
## Not exported - managed at runtime
var _stat_modifiers: Dictionary = {}

## Cached effective stats for performance
var _effective_stat_cache: Dictionary[String, int] = {}
var _cache_dirty: bool = true

# ==================== STATUS SYSTEM ====================

## Active statuses: { status_id: StatusInstance }
## StatusInstance contains: definition, stacks, duration, applied_modifiers, etc.
var _statuses: Dictionary = {}

## Status registry for looking up definitions by ID
## Set this to a resource or autoload that holds all StatusDefinition resources
var status_registry: Dictionary = {}

# ==================== COMBAT DATA ====================

@export_group("Combat")
@export var damage_weakness: Array[Skill.Damage_Types] = []
@export var damage_resistance: Array[Skill.Damage_Types] = []

@export var skills: Dictionary[int, Array] = {}
@export var default_attack: Skill
@export var passive_effects: Array[BattleEffect] = []
@export var effects_on_spawn: Array[BattleEffect] = []
@export var effects_on_death: Array[BattleEffect] = []

# ==================== EQUIPMENT (Party Only) ====================

@export_group("Equipment")
@export var equipped: Dictionary = {
	"head": null,
	"body": null,
	"legs": null,
	"weapon_left": null,
	"weapon_right": null,
	"shield": null,
	"accessory_1": null,
	"accessory_2": null,
}

# ==================== AI BEHAVIOR ====================

@export_group("AI Behavior")
@export var ai_behavior: AIBehavior = AIBehavior.BALANCED
@export var ai_intelligence: AIIntelligencePreset = AIIntelligencePreset.NORMAL
@export var aggression: float = 0.5
@export var prefer_defend: bool = false
@export var smart_targeting: bool = true
@export var target_priority: int = 0

@export var enemy_inventory: Array[Item] = []

# ==================== REWARDS (Enemy Only) ====================

@export_group("Rewards")
@export var xp_reward: int = 10
@export var currency_reward: int = 0
@export var item_drops: Array[BattleItemDrop] = []

# ==================== BATTLE SETTINGS ====================

@export_group("Battle Settings")
@export var is_boss: bool = false
@export var can_flee: bool = false
@export var flee_threshold_hp_percent: int = 25

# ==================== SIGNALS ====================

@warning_ignore("unused_signal")
signal stat_modified(stat_key: StringName, new_value: int)
signal status_applied(status_id: String, stacks: int)
signal status_removed(status_id: String)
signal status_ticked(status_id: String, remaining_duration: int)
signal hp_changed(old_hp: int, new_hp: int)
signal mp_changed(old_mp: int, new_mp: int)
signal died()

# ==================== INITIALIZATION ====================

func _init():
	_initialize_stat_dicts()

func current_stat_load_fix(data: Dictionary):
	recalculate_level_stats()
	for v in range(len(data)):
		var key = data.keys()[v]
		var value = data[key]
		stats.set(key, value)
	
func _initialize_stat_dicts():
	"""Ensure all base dictionaries have matching keys, then calculate current level stats."""
	var default_stats = ["hp", "mp", "atk", "def", "speed", "magic"]
	for key in default_stats:
		if not base_stats.has(key): base_stats[key] = 10
		if not max_stat_caps.has(key): max_stat_caps[key] = 999
		if not level_up_gains.has(key): level_up_gains[key] = 1
			
	recalculate_level_stats()

func recalculate_level_stats():
	"""
	Recalculates 'max_stats' and base 'stats' based on the current level.
	Preserves current HP/MP so they aren't reset to full during load or equip changes.
	"""
	for stat in base_stats.keys():
		var base_val = base_stats[stat]
		var gain_val = level_up_gains.get(stat, 0)
		var level_multiplier = level - 1
		
		var current_level_val = base_val * max(1, pow(gain_val, (level_multiplier / 7.5)))
		
		# 1. Update max stats
		if level_multiplier > 0:
			max_stats[stat] = ceili(current_level_val)
			
			# 2. Update base stats, but SKIP hp/mp so we can preserve their current loaded values
			if stat != "hp" and stat != "mp":
				stats[stat] = ceili(current_level_val)
		else:
			max_stats[stat] = base_val
			if stat != "hp" and stat != "mp":
				stats[stat] = base_val
			

	# 3. Re-apply equipment bonuses (this will also handle HP/MP preservation)
	_apply_equipment_to_stats()
	
func get_effective_max(stat_key: String) -> int:
	"""Get the true maximum value including equipment bonuses (used for clamping HP/MP)."""
	var base_max = max_stats[stat_key]
	# If equipment gives HP/MP bonuses, add them to the max limit
	if equipment_bonus.has(stat_key):
		return base_max + equipment_bonus[stat_key]
	return base_max

func get_effective_stat(stat_key: String) -> int:
	"""Get the final stat value after applying all active battle modifiers."""
	if _cache_dirty:
		_recalculate_effective_stats()
	if _effective_stat_cache.has(stat_key):
		return _effective_stat_cache[stat_key]
	return stats[stat_key]

func _recalculate_effective_stats():
	"""Recalculate all effective stats from base + battle modifiers."""
	_effective_stat_cache.clear()
	for stat_key in stats.keys():
		var base_value: int = stats[stat_key]
		var modified_value: float = float(base_value)
		
		# Apply all active battle modifiers for this stat
		for mod_id in _stat_modifiers.keys():
			var modifier = _stat_modifiers[mod_id]
			if modifier.stat_key == stat_key:
				match modifier.stacking_rule:
					StatModifier.StackingRule.ADDITIVE:
						modified_value += modifier.applied_delta
					StatModifier.StackingRule.MULTIPLICATIVE:
						modified_value *= (1.0 + modifier.applied_delta / 100.0)
					_: # OVERRIDE
						if modifier.applied_delta > modified_value:
							modified_value = modifier.applied_delta
		
		var min_val = 0 if stat_key != "hp" else 1
		var max_val = get_effective_max(stat_key) # Use effective max for clamping
		modified_value = clamp(modified_value, min_val, max_val)
		
		_effective_stat_cache[stat_key] = int(round(modified_value))

	_cache_dirty = false

func invalidate_stat_cache():
	_cache_dirty = true

# ==================== STAT MODIFIER SYSTEM ====================

func apply_modifier(modifier_id: String, modifier: StatModifier, source: Entity = null) -> bool:
	"""
	Apply a stat modifier to this entity.
	Returns true if successfully applied, false if blocked by stacking rules.
	"""
	var existing = _stat_modifiers.get(modifier_id)
	
	if existing:
		# Handle stacking
		match modifier.stacking_rule:
			StatModifier.StackingRule.NONE:
				return false  # Cannot stack
			StatModifier.StackingRule.OVERRIDE:
				# Remove old, apply new
				remove_modifier(modifier_id)
			StatModifier.StackingRule.EXTEND:
				# Add duration, keep higher value
				existing.turns_remaining += modifier.duration_turns
				if modifier.value > existing.value:
					existing.value = modifier.value
				invalidate_stat_cache()
				return true
			StatModifier.StackingRule.REFRESH:
				# Reset duration
				existing.turns_remaining = modifier.duration_turns
				return true
			StatModifier.StackingRule.CAPPED:
				if existing.stack_count >= modifier.max_stacks:
					return false
				existing.stack_count += 1
				existing.applied_delta += modifier.calculate_final_value(source if source else self, self)
				existing.turns_remaining = max(existing.turns_remaining, modifier.duration_turns)
				invalidate_stat_cache()
				return true
	
	# Create new modifier instance
	var new_modifier = modifier.duplicate()
	new_modifier.applied_delta = new_modifier.calculate_final_value(
		source if source else self, 
		self
	)
	new_modifier.turns_remaining = new_modifier.duration_turns
	new_modifier.stack_count = 1
	
	_stat_modifiers[modifier_id] = new_modifier
	invalidate_stat_cache()
	
	return true

func remove_modifier(modifier_id: String) -> bool:
	"""Remove a stat modifier by ID. Returns true if found and removed."""
	if not _stat_modifiers.has(modifier_id):
		return false
	
	var _modifier = _stat_modifiers[modifier_id]
	# Note: applied_delta is already factored into effective stats,
	# and we'll recalculate on next access, so no explicit reversal needed
	_stat_modifiers.erase(modifier_id)
	invalidate_stat_cache()
	
	return true

func tick_modifiers() -> Array[String]:
	"""
	Decrement duration on all turn-based modifiers.
	Returns array of modifier IDs that expired.
	"""
	var expired: Array[String] = []
	
	for mod_id in _stat_modifiers.keys():
		var modifier = _stat_modifiers[mod_id]
		
		if modifier.duration_type == StatModifier.DurationType.TURNS:
			modifier.turns_remaining -= 1
			
			if modifier.turns_remaining <= 0:
				expired.append(mod_id)
	
	# Remove expired modifiers
	for mod_id in expired:
		remove_modifier(mod_id)
	
	return expired

func get_active_modifier_ids() -> Array[String]:
	"""Get list of all active modifier IDs."""
	return _stat_modifiers.keys()

func has_modifier(modifier_id: String) -> bool:
	"""Check if a specific modifier is active."""
	return _stat_modifiers.has(modifier_id)

# ==================== STATUS SYSTEM ====================

func apply_status(status_def: StatusDefinition, stacks: int = 1, duration: int = -1, source: Entity = null) -> bool:
	"""
	Apply a status effect to this entity.
	
	Args:
		status_def: The status definition resource
		stacks: Number of stacks to apply
		duration: Override duration (-1 uses status default)
		source: Entity that applied this status (for callbacks)
	
	Returns:
		true if status was applied, false if blocked (immunity, stacking rules, etc.)
	"""
	# Check immunity
	if not status_def.can_be_removed and has_status(status_def.id):
		return false  # Already have an unremovable version
	
	var existing = _statuses.get(status_def.id)
	
	if existing:
		# Handle stacking based on rule
		match status_def.stacking_rule:
			StatModifier.StackingRule.NONE:
				return false
			StatModifier.StackingRule.OVERRIDE:
				# Replace existing
				_remove_status_internal(status_def.id, source)
			StatModifier.StackingRule.EXTEND:
				existing.duration += duration if duration > 0 else status_def.duration_value
				existing.stacks = max(existing.stacks, stacks)
				_apply_status_modifiers(existing)
				return true
			StatModifier.StackingRule.REFRESH:
				existing.duration = duration if duration > 0 else status_def.duration_value
				return true
			StatModifier.StackingRule.CAPPED:
				if existing.stacks >= status_def.max_stacks:
					return false
				existing.stacks += stacks
				_apply_status_modifiers(existing)
				return true
	
	# Create new status instance
	var status_instance = {
		"definition": status_def,
		"stacks": stacks,
		"duration": duration if duration > 0 else status_def.duration_value,
		"applied_modifiers": [],  # Track which modifier IDs we created
		"source": source,
	}
	_statuses[status_def.id] = status_instance
	
	# Apply stat modifiers from status
	_apply_status_modifiers(status_instance)
	
	# Call on_apply callback if defined
	if status_def.on_apply_callback != "" and source:
		_call_status_callback(status_def.on_apply_callback, status_instance, source)
	
	status_applied.emit(status_def.id, stacks)
	
	return true

func _apply_status_modifiers(status_instance: Dictionary):
	"""Apply all stat modifiers from a status instance."""
	var def = status_instance.definition
	var mod_prefix = "status_" + def.id + "_"

	# Clear existing applied modifiers to prevent duplicates when re-applying
	for mod_id in status_instance.applied_modifiers:
		remove_modifier(mod_id)
		status_instance.applied_modifiers.clear()

	for i in range(def.stat_modifiers.size()):
		var base_mod = def.stat_modifiers[i]
		var mod_id = mod_prefix + str(i)
		if apply_modifier(mod_id, base_mod, status_instance.source):
			status_instance.applied_modifiers.append(mod_id)

func _remove_status_internal(status_id: String, source: Entity = null):
	"""Internal removal that cleans up modifiers and calls callbacks."""
	if not _statuses.has(status_id):
		return
	
	var status_instance = _statuses[status_id]
	var def = status_instance.definition
	
	# Remove all applied modifiers
	for mod_id in status_instance.applied_modifiers:
		remove_modifier(mod_id)
	
	# Call on_remove callback
	if def.on_remove_callback != "" and source:
		_call_status_callback(def.on_remove_callback, status_instance, source)
	
	_statuses.erase(status_id)
	status_removed.emit(status_id)

func remove_status(status_id: String, source: Entity = null) -> bool:
	"""
	Remove a status effect by ID.
	Returns true if found and removed, false if not present or cannot be removed.
	"""
	if not _statuses.has(status_id):
		return false
	
	var status_instance = _statuses[status_id]
	if not status_instance.definition.can_be_removed:
		return false  # Cannot remove this status
	
	_remove_status_internal(status_id, source)
	return true

func remove_all_statuses(can_remove_only: bool = true, source: Entity = null) -> int:
	"""
	Remove all status effects.
	Returns count of statuses removed.
	"""
	var removed_count = 0
	var to_remove: Array[String] = []
	
	for status_id in _statuses.keys():
		var instance = _statuses[status_id]
		if not can_remove_only or instance.definition.can_be_removed:
			to_remove.append(status_id)
	
	for status_id in to_remove:
		_remove_status_internal(status_id, source)
		removed_count += 1
	
	return removed_count

func has_status(status_id: String) -> bool:
	"""Check if entity has a specific status."""
	return _statuses.has(status_id)

func get_status_stacks(status_id: String) -> int:
	"""Get the number of stacks for a status."""
	if not _statuses.has(status_id):
		return 0
	return _statuses[status_id].stacks

func get_status_duration(status_id: String) -> int:
	"""Get remaining duration for a status."""
	if not _statuses.has(status_id):
		return 0
	return _statuses[status_id].duration

func tick_statuses() -> Array[String]:
	"""
	Tick all statuses, decrementing duration and calling tick callbacks.
	Returns array of status IDs that expired.
	"""
	var expired: Array[String] = []
	
	for status_id in _statuses.keys():
		var instance = _statuses[status_id]
		var def = instance.definition
		
		# Handle duration
		if def.duration_type == StatusDefinition.DurationType.TURNS:
			instance.duration -= 1
			
			if instance.duration <= 0:
				expired.append(status_id)
				continue
		
		# Call tick callback
		if def.tick_callback != "":
			_call_status_callback(def.tick_callback, instance, instance.source)
		
		# Check removal conditions
		for condition in def.removal_conditions:
			if condition.evaluate(self):
				expired.append(status_id)
				break
		
		status_ticked.emit(status_id, instance.duration)
	
	# Remove expired
	for status_id in expired:
		_remove_status_internal(status_id, _statuses[status_id].source)
	
	return expired

func _call_status_callback(callback_name: String, status_instance: Dictionary, source: Entity):
	"""Call a status callback method if it exists on source or self."""
	if has_method(callback_name):
		call(callback_name, status_instance, status_instance["definition"].callback_data)
		return

	# Only fall back to source if self doesn't have the method (shouldn't happen for burn)
	if source and source.has_method(callback_name):
		source.call(callback_name, status_instance)

func get_active_status_ids() -> Array[String]:
	"""Get list of all active status IDs."""
	return _statuses.keys()

func get_all_statuses() -> Dictionary:
	"""Get a copy of all status data for serialization."""
	var result = {}
	for status_id in _statuses.keys():
		var instance = _statuses[status_id]
		result[status_id] = {
			"stacks": instance.stacks,
			"duration": instance.duration,
			"definition_id": instance.definition.id,
		}
	return result

# ==================== HP/MP MANAGEMENT ====================

func modify_hp(amount: int, override_limit: bool = false) -> int:
	"""
	Modify HP by amount (can be negative).
	Returns actual amount applied (may be clamped).
	"""
	var old_hp = stats["hp"]
	var new_hp = stats["hp"] + amount
	
	if not override_limit:
		new_hp = clamp(new_hp, 0, max_stats["hp"])
	
	stats["hp"] = new_hp
	
	if old_hp != new_hp:
		hp_changed.emit(old_hp, new_hp)
		
		if stats["hp"] <= 0 and old_hp > 0:
			died.emit()
	
	return new_hp - old_hp

func modify_mp(amount: int) -> int:
	"""
	Modify MP by amount (can be negative).
	Returns actual amount applied (may be clamped).
	"""
	var old_mp = stats["mp"]
	var new_mp = stats["mp"] + amount
	new_mp = clamp(new_mp, 0, max_stats["mp"])
	
	stats["mp"] = new_mp
	
	if old_mp != new_mp:
		mp_changed.emit(old_mp, new_mp)
	
	return new_mp - old_mp

func heal_hp(amount: int) -> int:
	"""Heal HP (positive amount only). Returns actual healed amount."""
	return modify_hp(abs(amount))

func damage_hp(amount: int) -> int:
	"""Deal damage to HP (positive amount only). Returns actual damage dealt."""
	return modify_hp(-abs(amount))

func is_alive() -> bool:
	return stats["hp"] > 0

func is_dead() -> bool:
	return stats["hp"] <= 0

# ==================== UTILITY FUNCTIONS ====================

func is_party_member() -> bool: return role == Role.PARTY
func is_enemy() -> bool: return role == Role.ENEMY

# Tracks equipment bonuses separately so we can easily add/remove them
var equipment_bonus: Dictionary = {}

func equip_stats_change():
	"""
	Recalculates stats by resetting to pure level stats, then adding equipment.
	FIXES: The old stacking bug and save/load mutation bugs.
	"""
	recalculate_level_stats()
	invalidate_stat_cache()

func _apply_equipment_to_stats():
	"""Internal function to cleanly apply equipment to the 'stats' dictionary."""
	# Save current HP/MP to preserve them across recalculations
	var old_hp = stats.get("hp", 0)
	var old_mp = stats.get("mp", 0)
	
	equipment_bonus.clear()
	
	# 1. Reset 'stats' to pure level values (Base + Level Gains)
	for stat in base_stats.keys():
		stats[stat] = base_stats[stat] + (level_up_gains.get(stat, 0) * (level - 1))
		
	# 2. Iterate through all equipment and accumulate bonuses
	for slot in equipped.keys():
		var item = equipped[slot] as Item
		if not item: continue
		
		for stat_key in item.item_bonuses:
			var bonus_value: int = item.item_bonuses[stat_key]
			if bonus_value == 0: continue
			
			if not equipment_bonus.has(stat_key):
				equipment_bonus[stat_key] = 0
			equipment_bonus[stat_key] += bonus_value
			
			stats[stat_key] = stats.get(stat_key, 0) + bonus_value

	# 3. Restore HP/MP, clamped to the new effective max
	# This ensures loaded HP/MP are preserved, and dead entities stay dead (0 HP)
	if old_hp > 0:
		stats["hp"] = clamp(old_hp, 1, get_effective_max("hp"))
	else:
		stats["hp"] = 0
		
	if old_mp >= 0:
		stats["mp"] = clamp(old_mp, 0, get_effective_max("mp"))

func clear_equipment_bonuses():
	"""Remove equipment bonuses and revert stats to pure level values."""
	equipment_bonus.clear()
	for stat in base_stats.keys():
		stats[stat] = base_stats[stat] + (level_up_gains.get(stat, 0) * (level - 1))
	invalidate_stat_cache()
	
# ==================== EFFECT CALLBACKS ====================
func effect_damage_hp(status_instance: Dictionary, data: Dictionary):
	"""Called each turn when burn status ticks - deals burn damage"""
	var damage: float = abs(int(status_instance.definition.stat_modifiers[0].value))
	if damage > 0:
		if data["damage_type"]:
			if (data["damage_type"] as Skill.Damage_Types) in damage_weakness:
				damage_hp( roundi( float( max_stats["hp"] ) * (damage / 100) * 2))
			elif (data["damage_type"] as Skill.Damage_Types) in damage_resistance:
				damage_hp( roundi( float( max_stats["hp"] ) * (damage / 100) / 2))
			else:
				damage_hp( roundi( float( max_stats["hp"] ) * (damage / 100)))
